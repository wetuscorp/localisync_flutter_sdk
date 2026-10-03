import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:localisync_sdk/core.dart';

final class DiagnosticTransport {
  final http.Client _client = http.Client();
  Future<int> send(
    DiagnosticsConfig config,
    String body,
    Cancellation cancellation,
  ) async {
    final aborted = Completer<void>();
    void abort() {
      if (!aborted.isCompleted) aborted.complete();
    }

    final detach = cancellation.onCancel(abort),
        timer = Timer(const Duration(seconds: 5), abort);
    try {
      final request = http.AbortableRequest(
        'POST',
        config.endpoint,
        abortTrigger: aborted.future,
      )..followRedirects = false;
      request.headers.addAll({
        'Authorization': 'Bearer ${config.key}',
        'Content-Type': 'application/json',
      });
      request.body = body;
      final response = await _client.send(request);
      await response.stream.listen((_) {}).cancel();
      return response.statusCode;
    } finally {
      timer.cancel();
      detach();
      abort();
    }
  }

  void close() => _client.close();
}
