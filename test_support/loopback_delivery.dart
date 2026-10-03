import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:localisync_sdk/core.dart';
import 'platform_acceptance.dart';

enum DeliveryFault { none, offline, signature, hash, truncated, delayed, stale }

/// Real socket boundary for device acceptance. Never imported by an SDK entrypoint.
final class LoopbackDelivery {
  LoopbackDelivery._(this.servers);
  final List<HttpServer> servers;
  final faults = [DeliveryFault.none, DeliveryFault.none];
  int requests = 0;
  bool _closed = false;
  String catalog = fixture['catalogJws']! as String;
  static Future<LoopbackDelivery> start() async {
    final servers = <HttpServer>[];
    try {
      for (var i = 0; i < 2; i++) {
        servers.add(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
      }
      final result = LoopbackDelivery._(servers);
      for (var i = 0; i < servers.length; i++) {
        final index = i;
        servers[i].listen(
          (request) => unawaited(result._serve(request, index)),
        );
      }
      return result;
    } on Object {
      for (final server in servers) await server.close(force: true);
      rethrow;
    }
  }

  Future<void> _serve(HttpRequest request, int index) async {
    requests++;
    try {
      final fault = faults[index];
      if (fault == DeliveryFault.delayed) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      if (_closed) return;
      if (fault == DeliveryFault.offline) {
        request.response.statusCode = 503;
      } else if (request.headers.value('authorization') !=
          'Bearer device-fixture') {
        request.response.statusCode = 401;
      } else {
        final path = request.uri.path;
        String? body;
        if (path.contains('/files/')) {
          body =
              (fixture['files']!
                      as Map<String, Object?>)[request.uri.pathSegments.last]
                  as String?;
          if (fault == DeliveryFault.hash) body = '${body ?? ''} ';
        } else if (path.contains('/releases/')) {
          body = fixture['manifestJws']! as String;
        } else {
          body = fault == DeliveryFault.stale
              ? fixture['catalogJws']! as String
              : catalog;
          if (fault == DeliveryFault.signature)
            body = 'invalid.signature.value';
        }
        if (body == null) {
          request.response.statusCode = 404;
        } else {
          final bytes = utf8.encode(body);
          if (fault == DeliveryFault.truncated) {
            request.response.contentLength = bytes.length + 100;
            request.response.add(bytes.take(bytes.length ~/ 2).toList());
          } else {
            request.response.add(bytes);
          }
        }
      }
      await request.response.close();
    } on SocketException {
      // Expected when the timeout test cancels its client socket.
    } on HttpException {
      // The intentionally truncated response cannot satisfy Content-Length.
    }
  }

  LocalisyncConfig config(
    TranslationBundle bundled, {
    ActivationPolicy activation = ActivationPolicy.immediate,
  }) => LocalisyncConfig(
    projectId: fixture['projectId']! as String,
    distributionId: fixture['distributionId']! as String,
    channel: Channel.preview,
    addresses: servers
        .map((server) => Uri.parse('http://127.0.0.1:${server.port}'))
        .toList(),
    readKey: 'device-fixture',
    trustedKeys: {'test-1': fixture['publicKey']! as String},
    appVersion: '1.0.0',
    bundled: bundled,
    locale: 'en',
    updatePolicy: UpdatePolicy.manual,
    activationPolicy: activation,
    allowDevelopmentHttp: true,
    requestTimeout: const Duration(milliseconds: 300),
    refreshTimeout: const Duration(seconds: 5),
  );

  Future<void> close() async {
    _closed = true;
    for (final server in servers) await server.close(force: true);
  }
}
