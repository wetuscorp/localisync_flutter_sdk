import 'dart:isolate';
import 'package:localisync_sdk/core.dart';

final class IsolateVerification implements DeliveryVerification {
  const IsolateVerification();
  @override
  Future<Object?> signed(
    String jws,
    Map<String, String> trustedKeys,
    int maxPayloadBytes,
  ) => _signed((jws, trustedKeys, maxPayloadBytes));
  @override
  Future<LocaleFile> file(String source, ArtifactDescriptor descriptor) =>
      _file((source, descriptor));
}

Future<Object?> _signed((String, Map<String, String>, int) input) =>
    Isolate.run(
      () =>
          const CooperativeVerification().signed(input.$1, input.$2, input.$3),
    );
Future<LocaleFile> _file((String, ArtifactDescriptor) input) =>
    Isolate.run(() => const CooperativeVerification().file(input.$1, input.$2));
