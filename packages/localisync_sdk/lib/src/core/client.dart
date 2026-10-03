import 'diagnostics.dart';
import 'dart:async';
import 'config.dart';
import 'content.dart';
import 'delivery.dart';
import 'failure.dart';
import 'ports.dart';
import 'protocol.dart';
import 'verification.dart';

export 'config.dart';

enum UpdatePhase {
  starting,
  idle,
  checking,
  downloading,
  pending,
  active,
  failed,
  disposed,
}

enum UpdateOutcome { updated, unchanged, pending, bundled, failed, cancelled }

final class UpdateResult {
  const UpdateResult(this.outcome, {this.failure, this.persisted = true});
  final UpdateOutcome outcome;
  final LocalisyncException? failure;
  final bool persisted;
}

final class LocalisyncStatus {
  const LocalisyncStatus({
    required this.phase,
    required this.locale,
    required this.contentVersion,
    this.releaseId,
    this.revision,
    this.failure,
    this.persisted = true,
  });
  final UpdatePhase phase;
  final String locale;
  final String? releaseId;
  final int? revision;
  final int contentVersion;
  final LocalisyncException? failure;
  final bool persisted;
}

final class _Prepared {
  _Prepared(DownloadedRelease download, this.bundle)
    : catalog = download.catalog,
      manifest = download.manifest,
      cached = download.cached;
  // Parsed input entries are no longer needed once their messages are compiled.
  final VerifiedCatalog catalog;
  final ReleaseManifest manifest;
  final CachedGeneration cached;
  final TranslationBundle bundle;
}

/// Instance-scoped translation client. Reads never await initialization or perform I/O.
final class LocalisyncClient {
  LocalisyncClient({
    required this.config,
    required DeliveryTransport transport,
    required DeliveryCache cache,
    DiagnosticSink? diagnostics,
    ContentPreparer preparer = const CooperativePreparer(),
    DeliveryVerification verification = const CooperativeVerification(),
  }) : _diagnostics = diagnostics,
       _transport = transport,
       _cache = cache,
       _preparer = preparer,
       _reader = DeliveryReader(config, transport, verification: verification),
       _locale = config.locale {
    _status = LocalisyncStatus(
      phase: UpdatePhase.starting,
      locale: _locale,
      contentVersion: 0,
    );
    _inflight = _boot().whenComplete(() => _inflight = null);
    ready = _inflight!;
  }
  final LocalisyncConfig config;
  final DiagnosticSink? _diagnostics;
  void _diagnose(FailureCode code, DiagnosticStage stage) {
    try {
      _diagnostics?.record(code, stage);
    } on Object {
      /* Diagnostic callbacks do not affect content. */
    }
  }

  final DeliveryTransport _transport;
  final DeliveryCache _cache;
  final ContentPreparer _preparer;
  final DeliveryReader _reader;
  final _events = StreamController<LocalisyncStatus>.broadcast(sync: true);
  late final Future<UpdateResult> ready;
  late LocalisyncStatus _status;
  String _locale;
  int _contentVersion = 0, _intent = 0;
  bool _disposed = false, _persisted = true;
  VerifiedCatalog? _floor;
  CacheState _stored = CacheState();
  _Prepared? _active, _pending;
  Cancellation? _cancellation;
  Future<UpdateResult>? _inflight;
  Stream<LocalisyncStatus> get changes => _events.stream;
  LocalisyncStatus get status => _status;
  String get locale => _locale;
  String? get releaseId => _active?.manifest.releaseId;
  List<String> get availableLocales => List.unmodifiable(
    _active?.manifest.requestedLocales ?? config.bundled.fallbacks.keys,
  );
  bool get hasPending => _pending != null;

  void _emit(
    UpdatePhase phase, {
    LocalisyncException? failure,
    DiagnosticStage stage = DiagnosticStage.refresh,
  }) {
    if (_disposed) return;
    _status = LocalisyncStatus(
      phase: phase,
      locale: _locale,
      contentVersion: _contentVersion,
      releaseId: releaseId,
      revision: _floor?.document.revision,
      failure: failure,
      persisted: _persisted,
    );
    if (failure != null)
      _diagnose(
        failure.code,
        failure.code == FailureCode.storage ? DiagnosticStage.cache : stage,
      );
    _events.add(_status);
  }

  void _check() {
    if (_disposed)
      throw const LocalisyncException(
        FailureCode.disposed,
        'The translation client has been disposed.',
      );
  }

  LocalisyncException _error(Object e) => e is LocalisyncException
      ? e
      : const LocalisyncException(
          FailureCode.network,
          'The update could not be completed.',
        );

  Future<UpdateResult> _boot() async {
    try {
      final cached = await _cache.read(config.cacheScope);
      if (_disposed) return const UpdateResult(UpdateOutcome.cancelled);
      if (cached != null) {
        _stored = cached;
        if (cached.catalog != null) {
          try {
            _floor = await _reader.verifyCatalog(cached.catalog!);
          } on LocalisyncException {
            /* Untrusted cache cannot establish a floor. */
          }
        }
        for (final generation in [cached.active, cached.previous]) {
          if (generation == null) continue;
          try {
            final downloaded = await _reader.cached(
                  generation,
                  locale: _locale,
                ),
                bundle = await _preparer.prepare(
                  downloaded.manifest,
                  downloaded.files,
                  config.contracts,
                );
            if (_disposed) return const UpdateResult(UpdateOutcome.cancelled);
            final recovered = downloaded.catalog;
            if (_floor == null ||
                recovered.document.revision > _floor!.document.revision) {
              _floor = recovered;
            } else if (recovered.document.revision ==
                    _floor!.document.revision &&
                recovered.digest != _floor!.digest) {
              continue;
            }
            _active = _Prepared(downloaded, bundle);
            _contentVersion++;
            _emit(UpdatePhase.active);
            break;
          } on LocalisyncException {
            /* Recover a previous complete generation or the bundled baseline. */
          }
        }
      }
    } catch (_) {
      _persisted = false;
      _emit(
        UpdatePhase.idle,
        failure: const LocalisyncException(
          FailureCode.storage,
          'The persistent cache could not be read.',
        ),
      );
    }
    if (_disposed) return const UpdateResult(UpdateOutcome.cancelled);
    if (config.updatePolicy == UpdatePolicy.onStart)
      return _refresh(stage: DiagnosticStage.start);
    _emit(UpdatePhase.idle);
    return UpdateResult(UpdateOutcome.unchanged, persisted: _persisted);
  }

  Future<UpdateResult> refresh() {
    _check();
    final pending = _inflight;
    if (pending != null) return pending;
    final operation = _refresh();
    _inflight = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_inflight, operation)) _inflight = null;
      }),
    );
    return operation;
  }

  Future<UpdateResult> _withDeadline(
    Future<UpdateResult> Function(Cancellation) run, {
    DiagnosticStage stage = DiagnosticStage.refresh,
  }) async {
    final token = Cancellation();
    _cancellation = token;
    final timer = Timer(config.refreshTimeout, token.cancel);
    try {
      return await run(token).timeout(
        config.refreshTimeout,
        onTimeout: () {
          token.cancel();
          throw const LocalisyncException(
            FailureCode.timeout,
            'The update exceeded its time limit.',
          );
        },
      );
    } on Object catch (e) {
      final failure = _error(e);
      if (!_disposed) _emit(UpdatePhase.failed, failure: failure, stage: stage);
      return UpdateResult(
        failure.code == FailureCode.cancelled
            ? UpdateOutcome.cancelled
            : UpdateOutcome.failed,
        failure: failure,
        persisted: _persisted,
      );
    } finally {
      timer.cancel();
      if (identical(_cancellation, token)) _cancellation = null;
    }
  }

  Future<UpdateResult> _refresh({
    DiagnosticStage stage = DiagnosticStage.refresh,
  }) => _withDeadline((token) async {
    _emit(UpdatePhase.checking);
    final catalog = await _reader.catalog(token, floor: _floor);
    token.check();
    _floor = catalog;
    _pending = null;
    await _persist(
      CacheState(
        catalog: catalog.jws,
        active: _stored.active,
        previous: _stored.previous,
      ),
      token,
    );
    token.check();
    if (catalog.document.select(config.appVersion) == null) {
      await _persist(CacheState(catalog: catalog.jws), token);
      token.check();
      _active = null;
      _pending = null;
      _contentVersion++;
      _emit(UpdatePhase.active);
      return UpdateResult(UpdateOutcome.bundled, persisted: _persisted);
    }
    _emit(UpdatePhase.downloading);
    final downloaded = await _reader.release(
      catalog,
      _locale,
      token,
      existing: _active?.cached ?? _stored.active,
    );
    final bundle = await _preparer.prepare(
      downloaded.manifest,
      downloaded.files,
      config.contracts,
    );
    token.check();
    final candidate = _Prepared(downloaded, bundle);
    if (_active?.manifest.releaseId == downloaded.manifest.releaseId) {
      await _persist(
        CacheState(
          catalog: catalog.jws,
          active: downloaded.cached,
          previous: _stored.previous,
        ),
        token,
      );
      token.check();
      _active = candidate;
      _emit(UpdatePhase.active);
      return UpdateResult(UpdateOutcome.unchanged, persisted: _persisted);
    }
    if (config.activationPolicy == ActivationPolicy.manual) {
      _pending = candidate;
      _emit(UpdatePhase.pending);
      return UpdateResult(UpdateOutcome.pending, persisted: _persisted);
    }
    await _activate(candidate, token);
    return UpdateResult(UpdateOutcome.updated, persisted: _persisted);
  }, stage: stage);
  Future<void> _persist(CacheState next, Cancellation token) async {
    token.check();
    final floor = _floor;
    if (floor == null) return;
    try {
      final accepted = await _cache.write(
        config.cacheScope,
        next,
        revision: floor.document.revision,
        catalogDigest: floor.digest,
        maxBytes: config.cacheBytes,
        cancellation: token,
      );
      token.check();
      if (!accepted)
        throw const LocalisyncException(
          FailureCode.staleRevision,
          'Another client has installed a newer catalog.',
        );
      _persisted = true;
      _stored = next;
    } on LocalisyncException catch (e) {
      if (e.code == FailureCode.staleRevision ||
          e.code == FailureCode.cancelled)
        rethrow;
      _persisted = false;
    } catch (_) {
      token.check();
      _persisted = false;
    }
  }

  Future<void> _activate(_Prepared candidate, Cancellation token) async {
    token.check();
    await _persist(
      CacheState(
        catalog: _floor?.jws,
        active: candidate.cached,
        previous: _stored.active,
      ),
      token,
    );
    token.check();
    if (_disposed)
      throw const LocalisyncException(
        FailureCode.cancelled,
        'The operation was cancelled.',
      );
    _active = candidate;
    _pending = null;
    _contentVersion++;
    _emit(UpdatePhase.active);
  }

  Future<UpdateResult> activatePending() async {
    _check();
    while (true) {
      final running = _inflight;
      if (running == null) break;
      await running;
      _check();
    }
    final candidate = _pending;
    if (candidate == null) return const UpdateResult(UpdateOutcome.unchanged);
    final operation = _withDeadline((token) async {
      await _activate(candidate, token);
      return UpdateResult(UpdateOutcome.updated, persisted: _persisted);
    }, stage: DiagnosticStage.activate);
    _inflight = operation;
    try {
      return await operation;
    } finally {
      if (identical(_inflight, operation)) _inflight = null;
    }
  }

  Future<UpdateResult> setLocale(String locale) async {
    _check();
    final intent = ++_intent;
    _cancellation?.cancel();
    final running = _inflight;
    if (running != null) await running;
    _check();
    if (intent != _intent) return const UpdateResult(UpdateOutcome.cancelled);
    if (locale == _locale) return const UpdateResult(UpdateOutcome.unchanged);
    final operation = _withDeadline((token) async {
      final active = _active;
      if (active == null) {
        if (!config.bundled.fallbacks.containsKey(locale))
          throw const LocalisyncException(
            FailureCode.locale,
            'The locale is not available in the bundled content.',
          );
        _locale = locale;
        _pending = null;
        _contentVersion++;
        _emit(UpdatePhase.active);
        return const UpdateResult(UpdateOutcome.updated);
      }
      _emit(UpdatePhase.downloading);
      final downloaded = await _reader.release(
        active.catalog,
        locale,
        token,
        existing: active.cached,
      );
      final bundle = await _preparer.prepare(
        downloaded.manifest,
        downloaded.files,
        config.contracts,
      );
      token.check();
      if (intent != _intent)
        throw const LocalisyncException(
          FailureCode.cancelled,
          'A later locale selection replaced this request.',
        );
      await _persist(
        CacheState(
          catalog: _floor?.jws,
          active: downloaded.cached,
          previous: _stored.active,
        ),
        token,
      );
      token.check();
      _locale = locale;
      _active = _Prepared(downloaded, bundle);
      _pending = null;
      _contentVersion++;
      _emit(UpdatePhase.active);
      return UpdateResult(UpdateOutcome.updated, persisted: _persisted);
    }, stage: DiagnosticStage.locale);
    _inflight = operation;
    try {
      return await operation;
    } finally {
      if (identical(_inflight, operation)) _inflight = null;
    }
  }

  TranslationResult resolve(
    String key, {
    Map<String, Object> arguments = const {},
    String? locale,
    String? defaultValue,
  }) {
    _check();
    final requested = locale ?? _locale;
    LocalisyncException? failure;
    for (final source in [ContentSource.remote, ContentSource.bundled]) {
      final bundle = source == ContentSource.remote
          ? _active?.bundle
          : config.bundled;
      final found = bundle?.find(requested, key);
      if (found == null) continue;
      try {
        return TranslationResult(
          text: found.$1.format(arguments),
          source: source,
          requestedLocale: requested,
          resolvedLocale: found.$2,
          releaseId: source == ContentSource.remote ? releaseId : null,
        );
      } on LocalisyncException catch (e) {
        failure = e;
        _diagnose(e.code, DiagnosticStage.translate);
      }
    }
    return TranslationResult(
      text: defaultValue ?? key,
      source: defaultValue == null
          ? ContentSource.key
          : ContentSource.defaultValue,
      requestedLocale: requested,
      resolvedLocale: null,
      failure: failure,
    );
  }

  String translate(
    String key, {
    Map<String, Object> arguments = const {},
    String? locale,
    String? defaultValue,
  }) => resolve(
    key,
    arguments: arguments,
    locale: locale,
    defaultValue: defaultValue,
  ).text;
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancellation?.cancel();
    try {
      _diagnostics?.close();
    } on Object {
      /* Isolated reporting adapter. */
    }
    _transport.close();
    _status = LocalisyncStatus(
      phase: UpdatePhase.disposed,
      locale: _locale,
      contentVersion: _contentVersion,
    );
    await _events.close();
    await _cache.close();
  }
}
