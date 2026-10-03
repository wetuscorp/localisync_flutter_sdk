import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localisync_sdk/localisync_sdk.dart';
import 'support/delivery_fixture.dart';

final _fixture = jsonDecode(deliveryFixture) as Map<String, Object?>;

class FixtureTransport implements DeliveryTransport {
  @override
  Future<DeliveryResponse> get(
    Uri uri, {
    required String readKey,
    required int maxBytes,
    required Duration timeout,
    required Cancellation cancellation,
    String? etag,
  }) async {
    cancellation.check();
    final String body;
    if (uri.path.contains('/files/')) {
      body =
          (_fixture['files']! as Map<String, Object?>)[uri.pathSegments.last]!
              as String;
    } else {
      body =
          _fixture[uri.path.contains('/releases/')
                  ? 'manifestJws'
                  : 'catalogJws']!
              as String;
    }
    return DeliveryResponse(200, utf8.encode(body));
  }

  @override
  void close() {}
}

LocalisyncClient client() => LocalisyncClient(
  config: LocalisyncConfig(
    projectId: _fixture['projectId']! as String,
    distributionId: _fixture['distributionId']! as String,
    channel: Channel.preview,
    addresses: [
      Uri.parse('https://primary.invalid'),
      Uri.parse('https://secondary.invalid'),
    ],
    readKey: 'fixture-key',
    trustedKeys: {'test-1': _fixture['publicKey']! as String},
    appVersion: '1.0.0',
    locale: 'en',
    bundled: TranslationBundle(
      fallbacks: {'en': null},
      entries: {
        'en': [
          TranslationEntry(
            key: 'plain',
            format: MessageFormat.plain,
            parameters: {},
            value: 'Bundled text',
          ),
        ],
      },
    ),
    updatePolicy: UpdatePolicy.manual,
  ),
  transport: FixtureTransport(),
  cache: MemoryDeliveryCache(),
);

class Harness extends StatelessWidget {
  const Harness({super.key});
  @override
  Widget build(BuildContext context) {
    LocalisyncScope.of(context);
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              Text(context.translate('plain')),
              const TextField(key: Key('draft')),
              TextButton(
                onPressed: () {
                  unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          body: Column(
                            children: [
                              Text(context.translate('plain')),
                              const TextField(key: Key('route-draft')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'activation keeps form and navigator state, including a pushed route',
    (tester) async {
      final sdk = client();
      await tester.runAsync(() => sdk.ready);
      await tester.pumpWidget(
        LocalisyncScope(client: sdk, child: const Harness()),
      );
      await tester.enterText(find.byKey(const Key('draft')), 'Unsaved draft');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('route-draft')),
        'Route input',
      );
      await tester.runAsync(() => sdk.refresh());
      await tester.pumpAndSettle();
      expect(find.text('Published text'), findsOneWidget);
      expect(find.text('Route input'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved draft'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(sdk.dispose);
    },
  );
  test(
    'Flutter locale boundary preserves scripts and rejects unsupported variants',
    () {
      expect(flutterLocale('zh-Hant-TW').toLanguageTag(), 'zh-Hant-TW');
      expect(
        () => flutterLocale('sl-rozaj'),
        throwsA(isA<LocalisyncException>()),
      );
    },
  );
}
