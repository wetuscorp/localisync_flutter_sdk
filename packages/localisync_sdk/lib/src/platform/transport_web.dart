import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:localisync_sdk/core.dart';

/// Fetch explicitly omits cookies even on a same-origin deployment.
final class PlatformDeliveryTransport implements DeliveryTransport {
  final _controllers = <web.AbortController>{};
  bool _closed = false;
  @override
  Future<DeliveryResponse> get(
    Uri uri, {
    required String readKey,
    required int maxBytes,
    required Duration timeout,
    required Cancellation cancellation,
    String? etag,
  }) async {
    if (_closed)
      throw const LocalisyncException(
        FailureCode.cancelled,
        'The transport is closed.',
      );
    final controller = web.AbortController();
    _controllers.add(controller);
    var timedOut = false;
    final detach = cancellation.onCancel(() => controller.abort()),
        timer = Timer(timeout, () {
          timedOut = true;
          controller.abort();
        });
    web.ReadableStreamDefaultReader? reader;
    try {
      cancellation.check();
      final headers = web.Headers()..set('Authorization', 'Bearer $readKey');
      if (etag != null) headers.set('If-None-Match', etag);
      final response = await web.window
          .fetch(
            uri.toString().toJS,
            web.RequestInit(
              method: 'GET',
              headers: headers,
              credentials: 'omit',
              redirect: 'error',
              cache: 'no-store',
              signal: controller.signal,
            ),
          )
          .toDart;
      final declared = int.tryParse(
        response.headers.get('content-length') ?? '',
      );
      if (declared != null && declared > maxBytes)
        throw const LocalisyncException(
          FailureCode.protocol,
          'Response exceeds the permitted size.',
        );
      final buffer = BytesBuilder(copy: false);
      var count = 0;
      if (response.body != null) {
        reader = response.body!.getReader() as web.ReadableStreamDefaultReader;
        while (true) {
          final item = await reader.read().toDart;
          cancellation.check();
          if (item.done) break;
          final value = item.value;
          if (value == null || !value.isA<JSUint8Array>())
            throw const LocalisyncException(
              FailureCode.protocol,
              'Invalid response body.',
            );
          final bytes = (value as JSUint8Array).toDart;
          count += bytes.length;
          if (count > maxBytes)
            throw const LocalisyncException(
              FailureCode.protocol,
              'Response exceeds the permitted size.',
            );
          buffer.add(bytes);
        }
      }
      return DeliveryResponse(
        response.status,
        buffer.takeBytes(),
        etag: response.headers.get('etag'),
      );
    } on LocalisyncException {
      rethrow;
    } on Object {
      cancellation.check();
      throw LocalisyncException(
        timedOut ? FailureCode.timeout : FailureCode.network,
        timedOut
            ? 'The delivery request timed out.'
            : 'The delivery request failed.',
      );
    } finally {
      timer.cancel();
      detach();
      controller.abort();
      _controllers.remove(controller);
      if (reader != null) {
        try {
          await reader.cancel().toDart;
        } on Object {
          /* Already ended or aborted. */
        }
      }
    }
  }

  @override
  void close() {
    _closed = true;
    for (final controller in _controllers) {
      controller.abort();
    }
    _controllers.clear();
  }
}
