# Localisync gen_l10n example

This runnable application uses real distribution configuration. It never creates a fake remote
session or claims successful delivery when configuration is missing.

From `sdks/flutter`, run `flutter pub get`. In this directory run
`flutter gen-l10n`, then `dart run localisync_generator:generate localisync.yaml`.

Obtain **SDK setup · Flutter** from your distribution. Add `appVersion`, `channel` and a
channel-scoped `readKey`. Store the resulting JSON string as `LOCALISYNC_CONFIG` in a local
Flutter define JSON file outside version control. The API never returns a saved read key.
Run `flutter run --dart-define-from-file=/absolute/path/to/defines.json`.

For Web, add the application's exact origin in distribution settings. To build self-hosted
Web resources use `flutter build web --no-web-resources-cdn` (and `--wasm` for Wasm).
Release builds require HTTPS. Development loopback endpoints require explicit development
configuration and debug mode. Android emulators address the host as `10.0.2.2`.

The first frame uses bundled ARB content; verified remote content can update the same widget
tree. Enter a draft, open the second route and refresh to check state preservation. Change locale
without checking for a new publication. An unavailable server leaves existing content usable.

Application signing, trusted production certificates and OS/browser deployment prerequisites
remain the application's responsibility. See the repository verification record for actual
platform checks; platform runner files alone are not evidence that a device test passed.
