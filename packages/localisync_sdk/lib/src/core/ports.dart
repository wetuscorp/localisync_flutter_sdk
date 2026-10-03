import 'dart:typed_data';
import 'content.dart';
import 'failure.dart';
import 'json.dart';
import 'protocol.dart';

final class DeliveryResponse {
  DeliveryResponse(this.status, List<int> body, {this.etag})
    : body = Uint8List.fromList(body);
  final int status;
  final Uint8List body;
  final String? etag;
}

abstract interface class DeliveryTransport {
  Future<DeliveryResponse> get(
    Uri uri, {
    required String readKey,
    required int maxBytes,
    required Duration timeout,
    required Cancellation cancellation,
    String? etag,
  });
  void close();
}

/// Stored strings are untrusted until reverified with the application's trust anchors.
final class CachedGeneration {
  CachedGeneration({
    required this.catalog,
    required this.manifest,
    required this.locale,
    required Map<String, String> files,
  }) : files = Map.unmodifiable(files);
  factory CachedGeneration.fromJson(Object? value) {
    final d = object(value, {'catalog', 'manifest', 'locale', 'files'}),
        f = d['files'];
    if (f is! Map<String, Object?>) invalid('Invalid cached artifacts.');
    return CachedGeneration(
      catalog: text(d['catalog'], max: 2 * DeliveryLimits.catalog),
      manifest: text(d['manifest'], max: DeliveryLimits.bytes),
      locale: localeTag(d['locale']),
      files: f.map(
        (k, v) => MapEntry(hash(k), text(v, max: DeliveryLimits.bytes, min: 0)),
      ),
    );
  }
  final String catalog, manifest, locale;
  final Map<String, String> files;
  Map<String, Object?> toJson() => {
    'catalog': catalog,
    'manifest': manifest,
    'locale': locale,
    'files': files,
  };
}

final class CacheState {
  CacheState({this.catalog, this.active, this.previous});
  factory CacheState.fromJson(Object? value) {
    final d = object(value, {'version', 'catalog', 'active', 'previous'});
    if (d['version'] != 1) invalid('Unsupported cache schema.');
    return CacheState(
      catalog: d['catalog'] == null
          ? null
          : text(d['catalog'], max: 2 * DeliveryLimits.catalog),
      active: d['active'] == null
          ? null
          : CachedGeneration.fromJson(d['active']),
      previous: d['previous'] == null
          ? null
          : CachedGeneration.fromJson(d['previous']),
    );
  }
  final String? catalog;
  final CachedGeneration? active, previous;
  Map<String, Object?> toJson() => {
    'version': 1,
    'catalog': catalog,
    'active': active?.toJson(),
    'previous': previous?.toJson(),
  };
}

abstract interface class DeliveryCache {
  Future<CacheState?> read(String scope);

  /// Must compare the verified catalog revision under a cross-client lock/transaction.
  /// Return false when another writer installed a newer/different catalog.
  Future<bool> write(
    String scope,
    CacheState state, {
    required int revision,
    required String catalogDigest,
    required int maxBytes,
    Cancellation? cancellation,
  });
  Future<void> close();
}

abstract interface class ContentPreparer {
  Future<TranslationBundle> prepare(
    ReleaseManifest manifest,
    Map<String, LocaleFile> files,
    Map<String, TranslationEntry> contracts,
  );
}

final class CooperativePreparer implements ContentPreparer {
  const CooperativePreparer();
  @override
  Future<TranslationBundle> prepare(
    ReleaseManifest manifest,
    Map<String, LocaleFile> files,
    Map<String, TranslationEntry> contracts,
  ) => prepareBundle(manifest, files, contracts: contracts);
}

/// Explicit opt-in for applications without durable storage. Default platform setup
/// always supplies a persistent adapter instead.
final class MemoryDeliveryCache implements DeliveryCache {
  final _entries =
      <String, ({CacheState state, int revision, String digest})>{};
  @override
  Future<CacheState?> read(String scope) async => _entries[scope]?.state;
  @override
  Future<bool> write(
    String scope,
    CacheState state, {
    required int revision,
    required String catalogDigest,
    required int maxBytes,
    Cancellation? cancellation,
  }) async {
    cancellation?.check();
    final old = _entries[scope];
    if (old != null &&
        (old.revision > revision ||
            (old.revision == revision && old.digest != catalogDigest)))
      return false;
    _entries[scope] = (state: state, revision: revision, digest: catalogDigest);
    return true;
  }

  @override
  Future<void> close() async {}
}
