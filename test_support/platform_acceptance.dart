import 'dart:convert';
import 'package:localisync_sdk/core.dart';
import '../packages/localisync_sdk/test/support/delivery_fixture.dart';

final fixture = jsonDecode(deliveryFixture) as Map<String, Object?>;

class AcceptanceTransport implements DeliveryTransport {
  bool offline = false;
  int requests = 0;
  @override
  Future<DeliveryResponse> get(
    Uri uri, {
    required String readKey,
    required int maxBytes,
    required Duration timeout,
    required Cancellation cancellation,
    String? etag,
  }) async {
    requests++;
    cancellation.check();
    if (offline)
      throw const LocalisyncException(
        FailureCode.network,
        'Offline test boundary.',
      );
    final value = uri.path.contains('/files/')
        ? (fixture['files']! as Map<String, Object?>)[uri.pathSegments.last]!
              as String
        : fixture[uri.path.contains('/releases/')
                  ? 'manifestJws'
                  : 'catalogJws']!
              as String;
    return DeliveryResponse(200, utf8.encode(value));
  }

  @override
  void close() {}
}

LocalisyncConfig acceptanceConfig(TranslationBundle bundled) =>
    LocalisyncConfig(
      projectId: fixture['projectId']! as String,
      distributionId: fixture['distributionId']! as String,
      channel: Channel.preview,
      addresses: [
        Uri.parse('https://primary.invalid'),
        Uri.parse('https://secondary.invalid'),
      ],
      readKey: 'public-fixture-key',
      trustedKeys: {'test-1': fixture['publicKey']! as String},
      appVersion: '1.0.0',
      bundled: bundled,
      locale: 'tr',
    );
