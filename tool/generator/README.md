# localisync_generator

Development-only typed baseline and AppLocalizations adapter generation.

Unpublished development tool for the Localisync Flutter SDK. MIT licensed; server and panel licensing is separate.
Minimum Dart 3.12 / Flutter 3.44 for Flutter integrations. Registry publication is a separate
release action; use the repository workspace for this local implementation.

## Integration

The workspace examples in `sdks/flutter/examples/basic` and `sdks/flutter/examples/gen_l10n`
show the two supported integration paths. Follow the Flutter guides in the Localisync
static documentation (`apps/docs/src/content/docs/sdks/flutter`). Public delivery setup is
available from **Distributions → SDK setup · Flutter** to current project members.

Translation lookup is synchronous and never performs network, disk access or message parsing.
Applications supply a compiled baseline, channel read key, strict application version and trusted
Ed25519 public keys. Automatic checks run once during startup. Explicit refresh and manual
activation are available. Runtime delivery never depends on a management login.

## Development

Run `flutter pub get` from the Flutter workspace root. Keep `localisync_generator` in development dependencies.
Run strict analysis, package tests and platform examples before changing the supported ranges.
Use `dart doc` for the exported API and `dart pub publish --dry-run` to inspect the package.
Do not publish until the platform and security acceptance record is complete.

Install from the public repository with `path: tool/generator` and an immutable release tag
in `dev_dependencies`. The runtime package is `localisync_sdk`; no core override is needed.
