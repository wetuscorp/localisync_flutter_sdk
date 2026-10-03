# localisync_sdk

Verified Localisync translation delivery for Flutter: immediate bundled translations,
durable offline cache and synchronous in-memory Plain text/ICU resolution.

Requires Flutter 3.44 / Dart 3.12 or later. MIT licensed.

## Installation

Version 0.1.0 is undergoing release validation; registry publication is pending.
After publication, install with:

```sh
flutter pub add localisync_sdk
```

During validation, use this repository's workspace or a local path to this package.
There is no separate core dependency. `localisync_sdk.dart` provides Flutter integration;
`core.dart` exposes platform-independent protocol and content types without importing Flutter.

## Integration

Obtain public delivery configuration from **Distributions → SDK setup · Flutter**.
Supply an application-owned baseline, locale, strict application version, scoped read key
and trusted Ed25519 public keys. Never embed signing or management credentials.

```dart
import 'package:flutter/widgets.dart';
import 'package:localisync_sdk/localisync_sdk.dart';

void startTranslations(LocalisyncConfig config, Widget app) {
  final client = createLocalisyncClient(config);
  runApp(LocalisyncScope(client: client, child: app));
}
```

Do not await `client.ready` before displaying the first screen. Consumers call
`context.translate('welcome')` or generated typed accessors. Dispose the client when its
owner is destroyed. Automatic checks run once at startup; `refresh()` explicitly checks again.
Manual activation is available. Invalid updates preserve the last usable content.

[Quick start](https://docs.localisync.com/sdks/flutter/quick-start/) ·
[Two integration examples](https://github.com/wetuscorp/localisync_flutter_sdk/tree/main/examples) ·
[Offline/security](https://docs.localisync.com/sdks/flutter/offline-security/)

The optional code generator is an unpublished Git development dependency under
`tool/generator` in the public repository. Pin it to the corresponding release tag.
Analyzer and YAML parsing do not ship in the runtime dependency graph.

Diagnostics are disabled by default. Explicit configuration uses a separate write-only
credential and bounded SDK error counters. Application errors, translation text, keys and
parameter values are never reported; reporting failure preserves active translations.

Targets include Android, iOS, Web, macOS, Windows and Linux. Supported targets and actual
validation evidence are distinct; see [platforms](https://docs.localisync.com/sdks/flutter/platforms/).

## Development

From the repository workspace run `flutter pub get` and `python3 tool/verify.py`.
`python3 tool/documentation.py` generates API docs and validates the package without publishing.
Preserve dependency and Unicode notices in `licenses/`.
