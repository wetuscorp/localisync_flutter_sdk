import 'diagnostics.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:localisync_sdk/core.dart';
import 'platform/factory_io.dart'
    if (dart.library.js_interop) 'platform/factory_web.dart'
    as platform;
import 'platform/transport_io.dart'
    if (dart.library.js_interop) 'platform/transport_web.dart';

/// Create a persistent platform client. Its bundled translations are immediately readable.
LocalisyncClient createLocalisyncClient(LocalisyncConfig config) {
  if (kReleaseMode && config.allowDevelopmentHttp)
    throw const LocalisyncException(
      FailureCode.configuration,
      'Development HTTP is unavailable in release builds.',
    );
  final reporter = config.diagnostics == null
      ? null
      : SdkDiagnosticReporter(config.diagnostics!, config.appVersion.value);
  final client = LocalisyncClient(
    config: config,
    diagnostics: reporter,
    transport: PlatformDeliveryTransport(),
    cache: platform.createCache(),
    preparer: platform.createPreparer(),
    verification: platform.createVerification(),
  );
  reporter?.attach(client);
  return client;
}

/// Rebuilds only widgets depending on this scope, without replacing navigator/form keys.
class LocalisyncScope extends StatefulWidget {
  const LocalisyncScope({super.key, required this.client, required this.child});
  final LocalisyncClient client;
  final Widget child;
  static LocalisyncClient of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_TranslationScope>();
    if (scope == null)
      throw StateError('Add LocalisyncScope above translation consumers.');
    return scope.client;
  }

  @override
  State<LocalisyncScope> createState() => _LocalisyncScopeState();
}

class _LocalisyncScopeState extends State<LocalisyncScope> {
  StreamSubscription<LocalisyncStatus>? _subscription;
  late int _version;
  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _version = widget.client.status.contentVersion;
    _subscription = widget.client.changes.listen((status) {
      if (mounted && status.contentVersion != _version)
        setState(() => _version = status.contentVersion);
    });
  }

  @override
  void didUpdateWidget(LocalisyncScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client) {
      unawaited(_subscription?.cancel());
      _listen();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _TranslationScope(
    client: widget.client,
    version: _version,
    child: widget.child,
  );
}

class _TranslationScope extends InheritedWidget {
  const _TranslationScope({
    required this.client,
    required this.version,
    required super.child,
  });
  final LocalisyncClient client;
  final int version;
  @override
  bool updateShouldNotify(_TranslationScope oldWidget) =>
      client != oldWidget.client || version != oldWidget.version;
}

extension LocalisyncContext on BuildContext {
  String translate(
    String key, {
    Map<String, Object> arguments = const {},
    String? defaultValue,
  }) => LocalisyncScope.of(
    this,
  ).translate(key, arguments: arguments, defaultValue: defaultValue);
}

/// Explicit Flutter boundary. Variants cannot be represented by dart:ui Locale.
Locale flutterLocale(String tag) {
  final pieces = tag.split('-');
  final language = pieces.removeAt(0);
  String? script, country;
  if (pieces.isNotEmpty && RegExp(r'^[A-Za-z]{4}$').hasMatch(pieces.first))
    script = pieces.removeAt(0);
  if (pieces.isNotEmpty &&
      RegExp(r'^(?:[A-Za-z]{2}|[0-9]{3})$').hasMatch(pieces.first))
    country = pieces.removeAt(0);
  if (pieces.isNotEmpty)
    throw const LocalisyncException(
      FailureCode.locale,
      'Map locale variants explicitly at the Flutter boundary.',
    );
  return Locale.fromSubtags(
    languageCode: language,
    scriptCode: script,
    countryCode: country,
  );
}
