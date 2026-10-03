import 'package:localisync_sdk/core.dart';

Map<String, num> percentiles(List<double> values) {
  if (values.isEmpty) throw StateError('A measurement contained no samples.');
  final sorted = [...values]..sort();
  int at(double percentile) => (sorted.length * percentile).ceil() - 1;
  return {
    'samples': sorted.length,
    'p50': sorted[at(.5)],
    'p95': sorted[at(.95)],
    'p99': sorted[at(.99)],
  };
}

Map<String, num> lookup(String Function() read) {
  var checksum = 0;
  for (var i = 0; i < 5000; i++) checksum += read().length;
  final values = <double>[];
  for (var i = 0; i < 20000; i++) {
    final watch = Stopwatch()..start();
    checksum += read().length;
    watch.stop();
    values.add(watch.elapsedTicks * 1000000 / watch.frequency);
  }
  return {...percentiles(values), 'checksum': checksum};
}

final class Measurements {
  Measurements({this.onStage});
  final void Function(String)? onStage;
  double networkMs = 0, verificationMs = 0, preparationMs = 0;
  Future<T> time<T>(String stage, Future<T> Function() task) async {
    onStage?.call(stage);
    final watch = Stopwatch()..start();
    try {
      return await task();
    } finally {
      final ms = watch.elapsedMicroseconds / 1000;
      switch (stage) {
        case 'network':
          networkMs += ms;
        case 'verification':
          verificationMs += ms;
        case 'preparation':
          preparationMs += ms;
        default:
          throw StateError('Unknown measurement stage.');
      }
    }
  }
}

final class TimedTransport implements DeliveryTransport {
  TimedTransport(this.delegate, this.measurements);
  final DeliveryTransport delegate;
  final Measurements measurements;
  @override
  Future<DeliveryResponse> get(
    Uri uri, {
    required String readKey,
    required int maxBytes,
    required Duration timeout,
    required Cancellation cancellation,
    String? etag,
  }) => measurements.time(
    'network',
    () => delegate.get(
      uri,
      readKey: readKey,
      maxBytes: maxBytes,
      timeout: timeout,
      cancellation: cancellation,
      etag: etag,
    ),
  );
  @override
  void close() => delegate.close();
}

final class TimedVerification implements DeliveryVerification {
  TimedVerification(this.delegate, this.measurements);
  final DeliveryVerification delegate;
  final Measurements measurements;
  @override
  Future<Object?> signed(String jws, Map<String, String> keys, int max) =>
      measurements.time('verification', () => delegate.signed(jws, keys, max));
  @override
  Future<LocaleFile> file(String source, ArtifactDescriptor descriptor) =>
      measurements.time(
        'verification',
        () => delegate.file(source, descriptor),
      );
}

final class TimedPreparer implements ContentPreparer {
  TimedPreparer(this.delegate, this.measurements);
  final ContentPreparer delegate;
  final Measurements measurements;
  @override
  Future<TranslationBundle> prepare(
    ReleaseManifest manifest,
    Map<String, LocaleFile> files,
    Map<String, TranslationEntry> contracts,
  ) => measurements.time(
    'preparation',
    () => delegate.prepare(manifest, files, contracts),
  );
}
