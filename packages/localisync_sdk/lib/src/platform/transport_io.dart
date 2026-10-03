import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:localisync_sdk/core.dart';

final class PlatformDeliveryTransport implements DeliveryTransport {
  PlatformDeliveryTransport({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  Future<DeliveryResponse> get(
    Uri uri, {
    required String readKey,
    required int maxBytes,
    required Duration timeout,
    required Cancellation cancellation,
    String? etag,
  }) async {
    final aborted = Completer<void>();
    void abort() {
      if (!aborted.isCompleted) aborted.complete();
    }

    final detach = cancellation.onCancel(abort), timer = Timer(timeout, abort);
    try {
      cancellation.check();
      final request = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: aborted.future,
      )..followRedirects = false;
      request.headers['Authorization'] = 'Bearer $readKey';
      if (etag != null) request.headers['If-None-Match'] = etag;
      final response = await _client.send(request);
      if ((response.contentLength ?? 0) > maxBytes)
        throw const LocalisyncException(
          FailureCode.protocol,
          'Response exceeds the permitted size.',
        );
      final buffer = BytesBuilder(copy: false);
      var count = 0;
      await for (final chunk in response.stream) {
        cancellation.check();
        count += chunk.length;
        if (count > maxBytes)
          throw const LocalisyncException(
            FailureCode.protocol,
            'Response exceeds the permitted size.',
          );
        buffer.add(chunk);
      }
      return DeliveryResponse(
        response.statusCode,
        buffer.takeBytes(),
        etag: response.headers['etag'],
      );
    } on http.RequestAbortedException {
      cancellation.check();
      throw const LocalisyncException(
        FailureCode.timeout,
        'The delivery request timed out.',
      );
    } on http.ClientException {
      throw const LocalisyncException(
        FailureCode.network,
        'The delivery request failed.',
      );
    } finally {
      abort();
      timer.cancel();
      detach();
    }
  }

  @override
  void close() => _client.close();
}
