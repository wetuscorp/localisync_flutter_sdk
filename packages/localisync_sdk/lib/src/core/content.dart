import 'failure.dart';
import 'icu.dart';
import 'protocol.dart';

/// Immutable application-owned fallback. No network, asset read or mutable global locale.
final class TranslationBundle {
  TranslationBundle({
    required Map<String, String?> fallbacks,
    required Map<String, List<TranslationEntry>> entries,
  }) : fallbacks = Map.unmodifiable(fallbacks),
       messages = Map.unmodifiable(
         entries.map((locale, values) {
           final items = <String, CompiledMessage>{};
           final compiler = MessageCompiler(locale);
           final seen = <String>{};
           for (final entry in values) {
             if (!seen.add(entry.key)) invalid('Duplicate bundled key.');
             if (entry.value != null)
               items[entry.key] = compiler.compile(entry);
           }
           return MapEntry(
             locale,
             Map<String, CompiledMessage>.unmodifiable(items),
           );
         }),
       ) {
    if (fallbacks.isEmpty || entries.keys.any((l) => !fallbacks.containsKey(l)))
      invalid('Invalid bundled language inventory.');
    validateFallbacks(fallbacks);
  }
  TranslationBundle.prepared({
    required Map<String, String?> fallbacks,
    required Map<String, Map<String, CompiledMessage>> messages,
  }) : fallbacks = Map.unmodifiable(fallbacks),
       messages = Map.unmodifiable(
         messages.map(
           (k, v) => MapEntry(k, Map<String, CompiledMessage>.unmodifiable(v)),
         ),
       ) {
    validateFallbacks(fallbacks);
    if (messages.keys.any((locale) => !fallbacks.containsKey(locale))) {
      invalid('Prepared content contains an unknown locale.');
    }
  }
  final Map<String, String?> fallbacks;
  final Map<String, Map<String, CompiledMessage>> messages;
  (CompiledMessage, String)? find(String locale, String key) {
    if (!fallbacks.containsKey(locale)) return null;
    String? tag = locale;
    while (tag != null) {
      final message = messages[tag]?[key];
      if (message != null) return (message, tag);
      tag = fallbacks[tag];
    }
    return null;
  }
}

enum ContentSource { bundled, remote, defaultValue, key }

final class TranslationResult {
  const TranslationResult({
    required this.text,
    required this.source,
    required this.requestedLocale,
    required this.resolvedLocale,
    this.releaseId,
    this.failure,
  });
  final String text, requestedLocale;
  final String? resolvedLocale, releaseId;
  final ContentSource source;
  final LocalisyncException? failure;
  bool get usedFallback =>
      resolvedLocale != null && resolvedLocale != requestedLocale;
}

/// Compile once. On browsers this yields between bounded batches rather than claiming
/// that compute() provides an off-thread isolate.
Future<TranslationBundle> prepareBundle(
  ReleaseManifest manifest,
  Map<String, LocaleFile> files, {
  Map<String, TranslationEntry> contracts = const {},
}) async {
  final result = <String, Map<String, CompiledMessage>>{};
  Set<String>? inventory;
  Map<String, TranslationEntry>? definitions;
  var processed = 0;
  for (final file in files.values) {
    if (file.releaseId != manifest.releaseId ||
        file.entries.length != manifest.keyCount ||
        !manifest.files.containsKey(file.locale))
      invalid('Inconsistent locale artifact.');
    final keys = file.entries.keys.toSet();
    if (inventory != null &&
        (keys.length != inventory.length || !keys.containsAll(inventory)))
      invalid('Mismatched artifact key inventory.');
    inventory = keys;
    final messages = <String, CompiledMessage>{};
    final compiler = MessageCompiler(file.locale);
    for (final entry in file.entries.values) {
      final definition = definitions?[entry.key] ?? contracts[entry.key];
      if (definition != null && !definition.sameContract(entry))
        throw const LocalisyncException(
          FailureCode.incompatible,
          'A message contract is incompatible with the application.',
        );
      if (entry.value != null) messages[entry.key] = compiler.compile(entry);
      if (++processed % 64 == 0) await Future<void>.delayed(Duration.zero);
    }
    definitions ??= file.entries;
    result[file.locale] = messages;
  }
  return TranslationBundle.prepared(
    fallbacks: manifest.languages,
    messages: result,
  );
}
