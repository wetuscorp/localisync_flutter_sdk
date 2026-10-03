import 'dart:isolate';
import 'package:localisync_sdk/core.dart';

final class PlatformContentPreparer implements ContentPreparer {
  const PlatformContentPreparer();
  @override
  Future<TranslationBundle> prepare(
    ReleaseManifest manifest,
    Map<String, LocaleFile> files,
    Map<String, TranslationEntry> contracts,
  ) async {
    final messages = <String, Map<String, CompiledMessage>>{};
    Map<String, TranslationEntry>? definitions;
    for (final file in files.values) {
      if (definitions != null) {
        if (file.entries.length != definitions.length) _invalidInventory();
        var checked = 0;
        for (final key in file.entries.keys) {
          if (!definitions.containsKey(key)) _invalidInventory();
          if (++checked % 256 == 0) await Future<void>.delayed(Duration.zero);
        }
      }
      // Sending the whole release graph at once can pause the UI while copying
      // isolate input. Compile one locale at a time; only a complete bundle is
      // returned to the coordinator for atomic activation.
      final prepared = await _prepareLocale(
        manifest,
        file,
        definitions ?? contracts,
      );
      messages[file.locale] = prepared.messages[file.locale]!;
      definitions ??= file.entries;
    }
    return TranslationBundle.prepared(
      fallbacks: manifest.languages,
      messages: messages,
    );
  }
}

Never _invalidInventory() => invalid('Mismatched artifact key inventory.');

// A top-level boundary prevents the closure from retaining the caller's entire
// release map while serializing the requested locale.
Future<TranslationBundle> _prepareLocale(
  ReleaseManifest manifest,
  LocaleFile file,
  Map<String, TranslationEntry> contracts,
) => Isolate.run(
  () => prepareBundle(manifest, {file.locale: file}, contracts: contracts),
);
