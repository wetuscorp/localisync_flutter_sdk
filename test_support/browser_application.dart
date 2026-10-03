import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:localisync_sdk/localisync_sdk.dart';
import 'package:localisync_sdk/src/platform/cache_web.dart';
import 'package:localisync_sdk/src/platform/transport_web.dart';
import 'package:web/web.dart' as web;
import 'platform_acceptance.dart';

/// Dedicated acceptance entrypoint; not imported by either example's normal main.
void runBrowserApplication(
  TranslationBundle bundled,
  Widget Function(LocalisyncClient) app,
) {
  WidgetsFlutterBinding.ensureInitialized();
  final semantics = SemanticsBinding.instance.ensureSemantics();
  final query = Uri.base.queryParameters;
  final client = LocalisyncClient(
    config: LocalisyncConfig(
      projectId: fixture['projectId']! as String,
      distributionId: fixture['distributionId']! as String,
      channel: Channel.preview,
      addresses: [
        Uri.parse(web.window.location.origin),
        Uri.parse(query['secondary']!),
      ],
      readKey: 'public-browser-fixture',
      trustedKeys: {'test-1': fixture['publicKey']! as String},
      appVersion: '1.0.0',
      bundled: bundled,
      locale: 'en',
      updatePolicy: UpdatePolicy.manual,
      activationPolicy: ActivationPolicy.manual,
      allowDevelopmentHttp: true,
      requestTimeout: const Duration(seconds: 1),
      refreshTimeout: const Duration(seconds: 8),
    ),
    transport: PlatformDeliveryTransport(),
    cache: IndexedDbDeliveryCache(
      databaseName: 'flutter-acceptance-${query['id']}',
    ),
  );
  String? draft() {
    String? result;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is EditableText) result = widget.controller.text;
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return result;
  }

  JSString status() => jsonEncode({
    'draft': draft(),
    'runtime': const bool.fromEnvironment('dart.tool.dart2wasm')
        ? 'wasm'
        : 'js',
    'locale': client.locale,
    'revision': client.status.revision,
    'phase': client.status.phase.name,
    'persisted': client.status.persisted,
    'pending': client.hasPending,
    'plain': client.translate('plain'),
    'greeting': client.translate('greeting', arguments: {'name': 'Developer'}),
    'rank': client.translate('rank', arguments: {'count': 22}),
  }).toJS;
  Future<JSString> command(String command) async {
    switch (command) {
      case 'ready':
        await client.ready;
      case 'refresh':
        await client.refresh();
      case 'activate':
        await client.activatePending();
      case 'en':
      case 'tr':
        await client.setLocale(command);
      case 'dispose':
        await client.dispose();
        semantics.dispose();
      default:
        throw ArgumentError('Unknown acceptance command.');
    }
    return status();
  }

  web.window.setProperty('localisyncStatus'.toJS, status.toJS);
  web.window.setProperty(
    'localisyncCommand'.toJS,
    ((JSString value) => command(value.toDart).toJS).toJS,
  );
  runApp(app(client));
}
