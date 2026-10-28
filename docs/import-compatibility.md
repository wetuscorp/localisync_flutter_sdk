---
title: Imported content compatibility
description: Coordinate message validation changes with runtime and generator upgrades.
sidebar:
  order: 9
---

Advanced imports can retain literal tag text and contracts with parameters unused in one
language. These changes keep the signed delivery and cache wire formats unchanged, but
older validators can reject such messages. Do not treat the published `0.1.0` package as
compatible merely because the wire version is the same. Use `localisync_sdk 0.1.1` or later with the matching tagged generator; version 0.1.1
adds literal-tag and unused-declaration support.

Before enabling this content for a distribution:

1. Select a released runtime **and matching generator** whose release notes explicitly
   cover literal tags and unused declarations. Keep existing keys and parameter types.
2. Regenerate the bundled baseline and typed accessors. Unused declared parameters remain
   in the shared API; used arguments must still be declared with the correct type.
3. Test bundled offline startup, a signed update, persistent cache and a second offline
   launch in each supported application platform. Verify fallback and revision floors.
4. Deploy the compatible application before publishing content that needs the new rules.
   Keep a compatible runtime in the rollback path; do not lower signed revisions or clear
   verified caches to force an older validator to accept an update.

Tags are literal content, not a rich-text renderer. Applications must deliberately choose
how to display them; never evaluate imported content as executable markup. Advanced
number/date/time/currency formatters remain outside this import change.

See [file compatibility](/transfers/formats/) for native resource export. Those files are
separate from SDK releases; native iOS, Android and React Native need their own acceptance.
