import 'dart:convert';
import 'failure.dart';
import 'json.dart';
import 'protocol.dart';

/// CPU boundary: platform adapters may perform signature, JSON and artifact verification
/// in an isolate. Scope and publication decisions remain in the delivery use case.
abstract interface class DeliveryVerification {
  Future<Object?> signed(
    String jws,
    Map<String, String> trustedKeys,
    int maxPayloadBytes,
  );
  Future<LocaleFile> file(String source, ArtifactDescriptor descriptor);
}

final class CooperativeVerification implements DeliveryVerification {
  const CooperativeVerification();
  @override
  Future<Object?> signed(
    String jws,
    Map<String, String> trustedKeys,
    int maxPayloadBytes,
  ) => SignatureVerifier(
    trustedKeys,
  ).verify(jws, maxPayloadBytes: maxPayloadBytes);
  @override
  Future<LocaleFile> file(String source, ArtifactDescriptor descriptor) async {
    final bytes = utf8.encode(source);
    if (bytes.length != descriptor.bytes ||
        await sha256Hex(bytes) != descriptor.digest) {
      throw const LocalisyncException(
        FailureCode.integrity,
        'A release artifact failed integrity verification.',
      );
    }
    return LocaleFile.fromJson(
      await decodeDocument(source, maxBytes: descriptor.bytes),
    );
  }
}
