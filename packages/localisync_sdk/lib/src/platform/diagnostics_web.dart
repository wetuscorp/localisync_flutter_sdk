import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:localisync_sdk/core.dart';

final class DiagnosticTransport {
  final _controllers = <web.AbortController>{};
  Future<int> send(
    DiagnosticsConfig config,
    String body,
    Cancellation cancellation,
  ) async {
    final controller = web.AbortController();
    _controllers.add(controller);
    final detach = cancellation.onCancel(() => controller.abort()),
        timer = Timer(const Duration(seconds: 5), () => controller.abort());
    try {
      final headers = web.Headers()
        ..set('Authorization', 'Bearer ${config.key}')
        ..set('Content-Type', 'application/json');
      final response = await web.window
          .fetch(
            config.endpoint.toString().toJS,
            web.RequestInit(
              method: 'POST',
              body: body.toJS,
              headers: headers,
              credentials: 'omit',
              redirect: 'error',
              cache: 'no-store',
              signal: controller.signal,
            ),
          )
          .toDart;
      return response.status;
    } finally {
      timer.cancel();
      detach();
      controller.abort();
      _controllers.remove(controller);
    }
  }

  void close() {
    for (final c in _controllers) {
      c.abort();
    }
    _controllers.clear();
  }
}
