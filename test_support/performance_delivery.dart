import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';

/// Disk-backed loopback server on a separate isolate, outside measured SDK work.
final class PerformanceDelivery {
  PerformanceDelivery._(this.isolate, this.control, this.addresses, this.index);
  final Isolate isolate;
  final SendPort control;
  final List<Uri> addresses;
  final Map<String, Object?> index;
  static Future<PerformanceDelivery> start(
    String profile,
    Directory directory,
  ) async {
    final index =
        jsonDecode(
              await rootBundle.loadString(
                'assets/performance/$profile/index.json',
              ),
            )
            as Map<String, Object?>;
    for (final item in index['files']! as List<Object?>) {
      final file = item! as Map<String, Object?>;
      final data = await rootBundle.load(
        'assets/performance/$profile/${file['locale']}.json',
      );
      await File('${directory.path}/${file['digest']}').writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    final port = ReceivePort();
    final isolate = await Isolate.spawn(_serve, (
      port.sendPort,
      directory.path,
      index,
    ));
    final result = await port.first as List<Object?>;
    port.close();
    return PerformanceDelivery._(
      isolate,
      result[0]! as SendPort,
      (result[1]! as List<int>)
          .map((p) => Uri.parse('http://127.0.0.1:$p'))
          .toList(),
      index,
    );
  }

  Future<void> online(bool value) async {
    final reply = ReceivePort();
    control.send((value, reply.sendPort));
    await reply.first;
    reply.close();
  }

  void close() => isolate.kill(priority: Isolate.immediate);
}

Future<void> _serve((SendPort, String, Map<String, Object?>) input) async {
  final (reply, path, index) = input;
  var online = true;
  final control = ReceivePort();
  control.listen((message) {
    final (value, acknowledgement) = message as (bool, SendPort);
    online = value;
    acknowledgement.send(true);
  });
  final servers = <HttpServer>[];
  for (var i = 0; i < 2; i++) {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servers.add(server);
    server.listen((request) async {
      try {
        if (!online) {
          request.response.statusCode = 503;
        } else if (request.headers.value('authorization') !=
            'Bearer performance-fixture') {
          request.response.statusCode = 401;
        } else if (request.uri.path.contains('/files/')) {
          final hash = request.uri.pathSegments.last;
          if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
            request.response.statusCode = 404;
          } else {
            final file = File('$path/$hash');
            request.response.contentLength = await file.length();
            await request.response.addStream(file.openRead());
          }
        } else {
          request.response.write(
            index[request.uri.path.contains('/releases/')
                ? 'manifestJws'
                : 'catalogJws'],
          );
        }
        await request.response.close();
      } on SocketException {
        // The acceptance client may cancel an in-flight request.
      } on HttpException {
        // The acceptance client may close during a streamed response.
      }
    });
  }
  reply.send([control.sendPort, servers.map((s) => s.port).toList()]);
}
