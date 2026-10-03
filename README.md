# Localisync Flutter SDK

Verified translation delivery, synchronous in-memory reads and durable offline cache.
The single runtime package is **localisync_sdk**. Requires Flutter 3.44 / Dart 3.12 or later.

Version 0.1.0 is a release candidate under validation. Registry publication and the
v0.1.0 tag are pending; do not treat repository availability as a published package.

## Getting started

Run `flutter pub get` in this checkout. The [basic example](examples/basic) uses typed
accessors; [gen_l10n](examples/gen_l10n) preserves existing AppLocalizations calls.
Follow the [quick start](https://docs.localisync.com/sdks/flutter/quick-start/).

After registry publication, normal installation is `flutter pub add localisync_sdk`.
Optional generation stays in `dev_dependencies`, pinned to the release tag:

```yaml
dev_dependencies:
  localisync_generator:
    git:
      url: https://github.com/wetuscorp/localisync_flutter_sdk.git
      ref: v0.1.0
      path: tool/generator
```

The generator is not published to pub.dev and is not required for runtime translation.
The tag above becomes usable only after release validation is complete.

## Validation

Run `python3 tool/verify.py --browser`, then `python3 tool/verify.py --downgrade`.
`python3 tool/documentation.py` generates API documentation and runs the package dry-run.
Install pinned browser tooling using `pnpm install --frozen-lockfile`.
`python3 tool/full_browser.py` exercises both compiled applications in JS/Wasm.
CI runs unit, browser and native integrations; a configured job is not test evidence.

Physical Android, minimum hardware/OS and production-network performance remain separate
acceptance gates. Physical iPhone large-content frame investigations must be resolved before
stable publication. See [maintenance](https://docs.localisync.com/sdks/flutter/maintenance/).

## Maintenance and contributions

Development is maintained in the product monorepo. This repository is a reviewed export;
`export-manifest.json` records its canonical source commit and SHA-256 file hashes.
Contributions are incorporated into the canonical source before the next export. Do not
force-push or overwrite published tags. CI has no publishing or production credentials.

SDK code is MIT licensed. [Third-party notices](packages/localisync_sdk/licenses) include
Unicode CLDR data. The SDK license does not license Localisync server or panel code.
