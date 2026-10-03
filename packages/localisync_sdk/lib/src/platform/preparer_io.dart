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
      if (file.releaseId != manifest.releaseId ||
          file.entries.length != manifest.keyCount ||
          !manifest.files.containsKey(file.locale)) {
        invalid('Inconsistent locale artifact.');
      }
      if (definitions != null && file.entries.length != definitions.length) {
        _invalidInventory();
      }
      var checked = 0;
      for (final entry in file.entries.values) {
        if (definitions != null && !definitions.containsKey(entry.key)) {
          _invalidInventory();
        }
        final definition = (definitions ?? contracts)[entry.key];
        if (definition != null && !definition.sameContract(entry)) {
          throw const LocalisyncException(
            FailureCode.incompatible,
            'A message contract is incompatible with the application.',
          );
        }
        if (++checked % 64 == 0) await Future<void>.delayed(Duration.zero);
      }
      // Sending the whole release graph at once can pause the UI while copying
      // isolate input. Compile one locale at a time; only a complete bundle is
      // returned to the coordinator for atomic activation.
      // Contract comparison is bounded above. Do not send the previous locale's
      // complete entry graph through the isolate merely to compare its metadata.
      final prepared = await _prepareLocale(manifest, file);
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
) => Isolate.run(() => prepareBundle(manifest, {file.locale: file}));
