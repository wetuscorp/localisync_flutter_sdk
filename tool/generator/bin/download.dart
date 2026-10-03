import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:localisync_sdk/core.dart';

/// Development-only adapter. The generated application has no dependency on this tool.
final class _Transport implements DeliveryTransport {
  final _http = HttpClient();
  @override
  Future<DeliveryResponse> get(
    Uri uri, {
    required String readKey,
    required int maxBytes,
    required Duration timeout,
    required Cancellation cancellation,
    String? etag,
  }) async {
    HttpClientRequest? request;
    final detach = cancellation.onCancel(() => request?.abort());
    Future<DeliveryResponse> fetch() async {
      cancellation.check();
      request = await _http.getUrl(uri);
      cancellation.check();
      request!.followRedirects = false;
      request!.headers.set(HttpHeaders.authorizationHeader, 'Bearer $readKey');
      if (etag != null)
        request!.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
      final response = await request!.close();
      final bytes = BytesBuilder(copy: false);
      if (response.contentLength > maxBytes)
        throw const LocalisyncException(
          FailureCode.protocol,
          'Artifact exceeds its byte limit.',
        );
      await for (final chunk in response) {
        cancellation.check();
        if (bytes.length + chunk.length > maxBytes)
          throw const LocalisyncException(
            FailureCode.protocol,
            'Artifact exceeds its byte limit.',
          );
        bytes.add(chunk);
      }
      return DeliveryResponse(
        response.statusCode,
        bytes.takeBytes(),
        etag: response.headers.value(HttpHeaders.etagHeader),
      );
    }

    try {
      return await fetch().timeout(timeout);
    } on TimeoutException {
      throw const LocalisyncException(
        FailureCode.timeout,
        'Download timed out.',
      );
    } finally {
      detach();
      request?.abort();
    }
  }

  @override
  void close() => _http.close(force: true);
}

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln(
      'Usage: LOCALISYNC_READ_KEY=… dart run localisync_generator:download sdk-config.json output.json locale [locale...]',
    );
    exitCode = 64;
    return;
  }
  final transport = _Transport();
  try {
    final input = await decodeDocument(
      await File(args[0]).readAsString(),
      maxBytes: 64 * 1024,
    );
    if (input is! Map<String, Object?>)
      throw const FormatException('Invalid SDK configuration.');
    String string(Object? value) {
      if (value is! String)
        throw const FormatException('Missing SDK configuration field.');
      return value;
    }

    final addresses = input['addresses'], keys = input['trustedKeys'];
    if (addresses is! List<Object?> || keys is! Map<String, Object?>)
      throw const FormatException('Missing public delivery configuration.');
    final locales = args.skip(2).toSet().toList();
    final config = LocalisyncConfig(
      projectId: string(input['projectId']),
      distributionId: string(input['distributionId']),
      channel: Channel.values.byName(string(input['channel'])),
      addresses: addresses.map((v) => Uri.parse(string(v))).toList(),
      readKey: Platform.environment['LOCALISYNC_READ_KEY'] ?? '',
      trustedKeys: keys.map((k, v) => MapEntry(k, string(v))),
      appVersion: string(input['appVersion']),
      locale: locales.first,
      bundled: TranslationBundle(
        fallbacks: {locales.first: null},
        entries: {locales.first: []},
      ),
      allowDevelopmentHttp: input['allowDevelopmentHttp'] == true,
    );
    final reader = DeliveryReader(config, transport), token = Cancellation();
    final timer = Timer(config.refreshTimeout, token.cancel);
    try {
      final catalog = await reader.catalog(token);
      if (catalog.document.select(config.appVersion) == null)
        throw const FormatException('No compatible publication exists.');
      CachedGeneration? combined;
      for (final locale in locales) {
        final release = await reader.release(
          catalog,
          locale,
          token,
          existing: combined,
        );
        combined = CachedGeneration(
          catalog: catalog.jws,
          manifest: release.cached.manifest,
          locale: locales.first,
          files: {...?combined?.files, ...release.cached.files},
        );
      }
      token.check();
      final output = File(args[1]), temp = File('${args[1]}.tmp.$pid');
      if (output.absolute.path == File(args[0]).absolute.path)
        throw const FormatException('Output cannot overwrite configuration.');
      await output.parent.create(recursive: true);
      try {
        await temp.writeAsString(jsonEncode(combined!.toJson()), flush: true);
        await temp.rename(output.path);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
      stdout.writeln(
        'Saved a verified release package with ${locales.length} requested locales.',
      );
    } finally {
      timer.cancel();
    }
  } on Object catch (error) {
    stderr.writeln(
      error is LocalisyncException
          ? error.message
          : error is FormatException
          ? error.message
          : 'Download failed. Check delivery availability and configuration.',
    );
    exitCode = 1;
  } finally {
    transport.close();
  }
}
