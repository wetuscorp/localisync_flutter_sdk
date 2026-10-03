import 'dart:convert';
import 'config.dart';
import 'failure.dart';
import 'ports.dart';
import 'protocol.dart';
import 'verification.dart';

final class VerifiedCatalog {
  const VerifiedCatalog(this.document, this.jws, this.digest);
  final Catalog document;
  final String jws, digest;
}

final class DownloadedRelease {
  DownloadedRelease(
    this.catalog,
    this.manifest,
    this.cached,
    Map<String, LocaleFile> files,
  ) : files = Map.unmodifiable(files);
  final VerifiedCatalog catalog;
  final ReleaseManifest manifest;
  final CachedGeneration cached;
  final Map<String, LocaleFile> files;
}

/// Download and verification never publish content to readers.
final class DeliveryReader {
  DeliveryReader(
    this.config,
    this.transport, {
    this.verification = const CooperativeVerification(),
  });
  final LocalisyncConfig config;
  final DeliveryTransport transport;
  final DeliveryVerification verification;
  String get base =>
      '/delivery/v1/distributions/${config.distributionId}/channels/${config.channel.name}';
  Future<VerifiedCatalog> verifyCatalog(
    String jws, {
    VerifiedCatalog? floor,
  }) async {
    final c = Catalog.fromJson(
      await verification.signed(
        jws,
        config.trustedKeys,
        DeliveryLimits.catalog,
      ),
    );
    if (c.projectId != config.projectId ||
        c.distributionId != config.distributionId ||
        c.channel != config.channel)
      invalid('Incorrect catalog scope.');
    final digest = await sha256Hex(utf8.encode(jws));
    if (floor != null &&
        (c.revision < floor.document.revision ||
            (c.revision == floor.document.revision && digest != floor.digest)))
      throw const LocalisyncException(
        FailureCode.staleRevision,
        'The catalog is older than the last verified decision or conflicts with it.',
      );
    return VerifiedCatalog(c, jws, digest);
  }

  Future<T> _obtain<T>(
    String path,
    int max,
    Cancellation cancellation,
    Future<T> Function(DeliveryResponse) validate, {
    String? etag,
  }) async {
    LocalisyncException? failure;
    for (var round = 0; round < 2; round++) {
      for (final address in config.addresses) {
        cancellation.check();
        try {
          final response = await transport.get(
            address.resolve(path),
            readKey: config.readKey,
            maxBytes: max,
            timeout: config.requestTimeout,
            cancellation: cancellation,
            etag: etag,
          );
          cancellation.check();
          if (response.status == 401 || response.status == 403)
            throw const LocalisyncException(
              FailureCode.authorization,
              'The delivery credential was rejected.',
            );
          if (response.status != 200 && response.status != 304)
            throw const LocalisyncException(
              FailureCode.network,
              'The delivery node did not supply the requested content.',
            );
          return await validate(response);
        } on LocalisyncException catch (e) {
          if (e.code == FailureCode.cancelled) rethrow;
          failure = e;
        } on FormatException {
          failure = const LocalisyncException(
            FailureCode.protocol,
            'Invalid delivery encoding.',
          );
        } catch (_) {
          failure = const LocalisyncException(
            FailureCode.network,
            'The delivery node is unavailable.',
          );
        }
      }
      if (failure?.code == FailureCode.authorization ||
          failure?.code == FailureCode.integrity ||
          failure?.code == FailureCode.protocol ||
          failure?.code == FailureCode.staleRevision)
        break;
      if (round == 0)
        await Future<void>.delayed(
          Duration(milliseconds: 150 + DateTime.now().microsecond % 150),
        );
    }
    throw failure ??
        const LocalisyncException(
          FailureCode.network,
          'No delivery node supplied a verified response.',
        );
  }

  Future<VerifiedCatalog> catalog(
    Cancellation cancellation, {
    VerifiedCatalog? floor,
  }) => _obtain(
    base + '/manifest',
    (DeliveryLimits.catalog * 4 / 3).ceil() + 4096,
    cancellation,
    (r) async {
      if (r.status == 304) {
        if (floor == null) invalid('Unexpected not-modified response.');
        return floor;
      }
      return verifyCatalog(utf8.decode(r.body), floor: floor);
    },
    etag: floor == null ? null : '"${floor.digest}"',
  );

  Future<ReleaseManifest> _manifest(VerifiedCatalog catalog, String jws) async {
    final publication = catalog.document.select(config.appVersion);
    if (publication == null)
      throw const LocalisyncException(
        FailureCode.incompatible,
        'No publication matches the application version.',
      );
    if (await sha256Hex(utf8.encode(jws)) != publication.manifestDigest)
      throw const LocalisyncException(
        FailureCode.integrity,
        'The release manifest hash does not match.',
      );
    final m = ReleaseManifest.fromJson(
      await verification.signed(jws, config.trustedKeys, DeliveryLimits.bytes),
    );
    if (m.projectId != config.projectId ||
        m.releaseId != publication.releaseId ||
        !m.compatibility.sameAs(publication.compatibility))
      invalid('Incorrect release scope or compatibility.');
    return m;
  }

  Future<LocaleFile> _file(
    String source,
    ArtifactDescriptor descriptor,
    ReleaseManifest manifest,
  ) async {
    final file = await verification.file(source, descriptor);
    if (file.locale != descriptor.locale ||
        file.releaseId != manifest.releaseId ||
        file.entries.length != manifest.keyCount)
      invalid('Mixed or incomplete release artifacts.');
    return file;
  }

  Future<DownloadedRelease> cached(
    CachedGeneration data, {
    String? locale,
  }) async {
    final catalog = await verifyCatalog(data.catalog),
        manifest = await _manifest(catalog, data.manifest),
        selected = locale ?? data.locale;
    if (!manifest.requestedLocales.contains(selected))
      throw const LocalisyncException(
        FailureCode.locale,
        'The selected locale is not published.',
      );
    final files = <String, LocaleFile>{};
    for (final lang in manifest.chain(selected)) {
      final descriptor = manifest.files[lang]!,
          source = data.files[descriptor.digest];
      if (source == null) invalid('Cached release is incomplete.');
      files[lang] = await _file(source, descriptor, manifest);
    }
    return DownloadedRelease(catalog, manifest, data, files);
  }

  Future<DownloadedRelease> release(
    VerifiedCatalog catalog,
    String locale,
    Cancellation cancellation, {
    CachedGeneration? existing,
  }) async {
    final publication = catalog.document.select(config.appVersion);
    if (publication == null)
      throw const LocalisyncException(
        FailureCode.incompatible,
        'No publication matches the application version.',
      );
    final path = '$base/releases/${publication.releaseId}';
    String? manifestText;
    ReleaseManifest? manifest;
    if (existing != null) {
      try {
        manifest = await _manifest(catalog, existing.manifest);
        manifestText = existing.manifest;
      } on LocalisyncException {
        /* Another release or a corrupt cache is fetched anew. */
      }
    }
    if (manifest == null) {
      final result = await _obtain<(String, ReleaseManifest)>(
        path + '/manifest',
        DeliveryLimits.bytes,
        cancellation,
        (r) async {
          if (r.status != 200)
            invalid('Unexpected immutable artifact response.');
          final source = utf8.decode(r.body);
          return (source, await _manifest(catalog, source));
        },
      );
      manifestText = result.$1;
      manifest = result.$2;
    }
    if (!manifest.requestedLocales.contains(locale))
      throw const LocalisyncException(
        FailureCode.locale,
        'The selected locale is not published.',
      );
    final raw = <String, String>{}, files = <String, LocaleFile>{};
    for (final lang in manifest.chain(locale)) {
      cancellation.check();
      final descriptor = manifest.files[lang]!;
      final stored = existing?.files[descriptor.digest];
      LocaleFile? file;
      String? source;
      if (stored != null) {
        try {
          file = await _file(stored, descriptor, manifest);
          source = stored;
        } on LocalisyncException {
          /* Verify every reused artifact. */
        }
      }
      if (file == null) {
        final stableManifest = manifest;
        final result = await _obtain<(String, LocaleFile)>(
          '$path/files/${descriptor.digest}',
          descriptor.bytes,
          cancellation,
          (r) async {
            if (r.status != 200)
              invalid('Unexpected immutable artifact response.');
            final content = utf8.decode(r.body);
            return (content, await _file(content, descriptor, stableManifest));
          },
        );
        source = result.$1;
        file = result.$2;
      }
      raw[descriptor.digest] = source!;
      files[lang] = file;
    }
    return DownloadedRelease(
      catalog,
      manifest,
      CachedGeneration(
        catalog: catalog.jws,
        manifest: manifestText!,
        locale: locale,
        files: raw,
      ),
      files,
    );
  }
}
