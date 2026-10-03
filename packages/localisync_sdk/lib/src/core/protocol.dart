import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'failure.dart';
import 'json.dart';
import 'version.dart';

abstract final class DeliveryLimits {
  static const keys = 10000;
  static const values = 50000;
  static const bytes = 100 * 1024 * 1024;
  static const catalog = 1024 * 1024;
  static const valueBytes = 16 * 1024;
}

enum Channel { preview, production }

final class Publication {
  Publication._(
    this.id,
    this.releaseId,
    this.manifestDigest,
    this.sequence,
    this.compatibility,
  );
  factory Publication.fromJson(Object? value) {
    final d = object(value, {
      'id',
      'releaseId',
      'manifestDigest',
      'sequence',
      'compatibility',
    });
    return Publication._(
      uuid(d['id']),
      uuid(d['releaseId']),
      hash(d['manifestDigest']),
      integer(d['sequence'], min: 1),
      Compatibility.fromJson(d['compatibility']),
    );
  }
  final String id, releaseId, manifestDigest;
  final int sequence;
  final Compatibility compatibility;
}

final class Catalog {
  Catalog._(
    this.projectId,
    this.distributionId,
    this.channel,
    this.revision,
    List<Publication> publications,
  ) : publications = List.unmodifiable(publications);
  factory Catalog.fromJson(Object? value) {
    final d = object(value, {
      'protocol',
      'kind',
      'projectId',
      'distributionId',
      'channel',
      'revision',
      'publications',
    });
    if (d['protocol'] != 1 || d['kind'] != 'catalog')
      invalid('Unsupported catalog protocol.');
    final channel = switch (d['channel']) {
      'preview' => Channel.preview,
      'production' => Channel.production,
      _ => invalid('Unknown delivery channel.'),
    };
    final revision = integer(d['revision']);
    final publications = array(
      d['publications'],
    ).map(Publication.fromJson).toList();
    if (publications.map((p) => p.id).toSet().length != publications.length ||
        publications.map((p) => p.sequence).toSet().length !=
            publications.length ||
        publications.any((p) => p.sequence > revision))
      invalid('Invalid publication ordering.');
    return Catalog._(
      uuid(d['projectId']),
      uuid(d['distributionId']),
      channel,
      revision,
      publications,
    );
  }
  final String projectId, distributionId;
  final Channel channel;
  final int revision;
  final List<Publication> publications;
  Publication? select(AppVersion version) {
    Publication? best;
    for (final item in publications) {
      if (item.compatibility.accepts(version) &&
          (best == null || item.sequence > best.sequence))
        best = item;
    }
    return best;
  }
}

final class ArtifactDescriptor {
  ArtifactDescriptor._(this.locale, this.digest, this.bytes);
  factory ArtifactDescriptor.fromJson(Object? value) {
    final d = object(value, {'locale', 'digest', 'bytes'});
    return ArtifactDescriptor._(
      localeTag(d['locale']),
      hash(d['digest']),
      integer(d['bytes'], min: 1, max: DeliveryLimits.bytes),
    );
  }
  final String locale, digest;
  final int bytes;
}

final class ReleaseManifest {
  ReleaseManifest._(
    this.projectId,
    this.releaseId,
    this.compatibility,
    List<String> requested,
    Map<String, String?> languages,
    Map<String, ArtifactDescriptor> files,
    this.keyCount,
  ) : requestedLocales = List.unmodifiable(requested),
      languages = Map.unmodifiable(languages),
      files = Map.unmodifiable(files);
  factory ReleaseManifest.fromJson(Object? value) {
    final d = object(value, {
      'protocol',
      'kind',
      'projectId',
      'releaseId',
      'compatibility',
      'requestedLocales',
      'languages',
      'files',
      'keyCount',
    });
    if (d['protocol'] != 1 || d['kind'] != 'release')
      invalid('Unsupported release protocol.');
    final requested = array(
      d['requestedLocales'],
      min: 1,
    ).map(localeTag).toList();
    final languages = <String, String?>{};
    for (final item in array(d['languages'], min: 1)) {
      final lang = object(item, {'locale', 'fallback'}),
          locale = localeTag(lang['locale']);
      if (languages.containsKey(locale)) invalid('Duplicate release language.');
      languages[locale] = lang['fallback'] == null
          ? null
          : localeTag(lang['fallback']);
    }
    final files = <String, ArtifactDescriptor>{};
    var bytes = 0;
    for (final item in array(d['files'], min: 1)) {
      final f = ArtifactDescriptor.fromJson(item);
      if (files.containsKey(f.locale)) invalid('Duplicate release artifact.');
      files[f.locale] = f;
      bytes += f.bytes;
    }
    final count = integer(d['keyCount'], min: 1, max: DeliveryLimits.keys);
    if (bytes > DeliveryLimits.bytes ||
        count * languages.length > DeliveryLimits.values ||
        requested.toSet().length != requested.length ||
        requested.any((l) => !languages.containsKey(l)) ||
        files.length != languages.length ||
        languages.keys.any((l) => !files.containsKey(l)))
      invalid('Inconsistent release inventory.');
    validateFallbacks(languages);
    return ReleaseManifest._(
      uuid(d['projectId']),
      uuid(d['releaseId']),
      Compatibility.fromJson(d['compatibility']),
      requested,
      languages,
      files,
      count,
    );
  }
  final String projectId, releaseId;
  final Compatibility compatibility;
  final List<String> requestedLocales;
  final Map<String, String?> languages;
  final Map<String, ArtifactDescriptor> files;
  final int keyCount;
  List<String> chain(String locale) => fallbackChain(languages, locale);
}

void validateFallbacks(Map<String, String?> languages) {
  if (languages.isEmpty) invalid('A fallback graph cannot be empty.');
  final roots = <String, String>{};
  for (final locale in languages.keys) {
    if (roots.containsKey(locale)) continue;
    final path = <String>[], visiting = <String>{};
    String? cursor = locale;
    String? root;
    while (cursor != null) {
      if (!languages.containsKey(cursor) || !visiting.add(cursor))
        invalid('Invalid fallback graph.');
      final known = roots[cursor];
      if (known != null) {
        root = known;
        break;
      }
      path.add(cursor);
      root = cursor;
      cursor = languages[cursor];
    }
    for (final item in path) {
      roots[item] = root!;
    }
  }
  if (roots.values.toSet().length != 1)
    invalid('Fallbacks must end in one source language.');
}

List<String> fallbackChain(Map<String, String?> languages, String locale) {
  final chain = <String>[];
  final seen = <String>{};
  String? cursor = locale;
  while (cursor != null) {
    if (!languages.containsKey(cursor) || !seen.add(cursor))
      invalid('Invalid fallback graph.');
    chain.add(cursor);
    cursor = languages[cursor];
  }
  return List.unmodifiable(chain);
}

enum MessageFormat { plain, icu }

enum ParameterType { text, number }

final class TranslationEntry {
  TranslationEntry({
    required this.key,
    required this.format,
    required Map<String, ParameterType> parameters,
    required this.value,
  }) : parameters = Map.unmodifiable(parameters) {
    text(key, max: 200);
    if (parameters.length > 32 ||
        parameters.keys.any(
          (name) =>
              name.length > 100 ||
              !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name),
        ))
      invalid('Invalid parameter contract.');
    if (value != null && utf8.encode(value!).length > DeliveryLimits.valueBytes)
      invalid('Translation exceeds 16 KiB.');
    if (format == MessageFormat.plain && parameters.isNotEmpty)
      invalid('Plain text cannot declare parameters.');
  }
  factory TranslationEntry.fromJson(Object? value) {
    final d = object(value, {'key', 'format', 'parameters', 'value'});
    final format = switch (d['format']) {
      'plain' => MessageFormat.plain,
      'icu' => MessageFormat.icu,
      _ => invalid('Unknown translation format.'),
    };
    final parameters = <String, ParameterType>{};
    for (final item in array(d['parameters'], max: 32)) {
      final p = object(item, {'name', 'type'}),
          name = text(p['name'], max: 100);
      if (parameters.containsKey(name)) invalid('Duplicate message parameter.');
      parameters[name] = switch (p['type']) {
        'text' => ParameterType.text,
        'number' => ParameterType.number,
        _ => invalid('Unknown parameter type.'),
      };
    }
    return TranslationEntry(
      key: text(d['key'], max: 200),
      format: format,
      parameters: parameters,
      value: d['value'] == null
          ? null
          : text(d['value'], max: DeliveryLimits.valueBytes, min: 0),
    );
  }
  final String key;
  final MessageFormat format;
  final Map<String, ParameterType> parameters;
  final String? value;
  Map<String, Object?> toJson() => {
    'key': key,
    'format': format.name,
    'parameters': parameters.entries
        .map((p) => <String, Object?>{'name': p.key, 'type': p.value.name})
        .toList(),
    'value': value,
  };
  bool sameContract(TranslationEntry other) =>
      format == other.format &&
      parameters.length == other.parameters.length &&
      parameters.entries.every((p) => other.parameters[p.key] == p.value);
}

final class LocaleFile {
  LocaleFile._(
    this.releaseId,
    this.locale,
    Map<String, TranslationEntry> entries,
  ) : entries = Map.unmodifiable(entries);
  factory LocaleFile.fromJson(Object? value) {
    final d = object(value, {'protocol', 'releaseId', 'locale', 'entries'});
    if (d['protocol'] != 1) invalid('Unsupported artifact protocol.');
    final entries = <String, TranslationEntry>{};
    for (final item in array(d['entries'], max: DeliveryLimits.keys)) {
      final entry = TranslationEntry.fromJson(item);
      if (entries.containsKey(entry.key)) invalid('Duplicate translation key.');
      entries[entry.key] = entry;
    }
    return LocaleFile._(uuid(d['releaseId']), localeTag(d['locale']), entries);
  }
  final String releaseId, locale;
  final Map<String, TranslationEntry> entries;
}

Future<String> sha256Hex(List<int> bytes) async => (await Sha256().hash(
  bytes,
)).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Trust anchors are supplied by the application, never learned from an untrusted response.
final class SignatureVerifier {
  SignatureVerifier(Map<String, String> keys)
    : _keys = Map.unmodifiable(
        keys.map((kid, key) => MapEntry(kid, _publicKey(key))),
      );
  final Map<String, SimplePublicKey> _keys;
  static SimplePublicKey _publicKey(String input) {
    List<int> bytes;
    try {
      if (input.startsWith('-----BEGIN PUBLIC KEY-----')) {
        final der = base64.decode(
          input
              .replaceAll('-----BEGIN PUBLIC KEY-----', '')
              .replaceAll('-----END PUBLIC KEY-----', '')
              .replaceAll(RegExp(r'\s'), '')
              .trim(),
        );
        const prefix = [
          0x30,
          0x2a,
          0x30,
          0x05,
          0x06,
          0x03,
          0x2b,
          0x65,
          0x70,
          0x03,
          0x21,
          0x00,
        ];
        if (der.length != 44 ||
            !List.generate(
              prefix.length,
              (i) => der[i] == prefix[i],
            ).every((v) => v))
          invalid('Expected an Ed25519 SPKI public key.');
        bytes = der.sublist(12);
      } else {
        bytes = base64Url.decode(base64Url.normalize(input));
      }
    } on FormatException {
      invalid('Invalid public verification key.');
    }
    if (bytes.length != 32) invalid('Expected a 32-byte Ed25519 public key.');
    return SimplePublicKey(bytes, type: KeyPairType.ed25519);
  }

  Future<Object?> verify(String jws, {required int maxPayloadBytes}) async {
    if (jws.length > (maxPayloadBytes * 4 / 3).ceil() + 4096)
      invalid('Signed document exceeds its limit.');
    final parts = jws.split('.');
    if (parts.length != 3 ||
        parts.any(
          (p) => p.isEmpty || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(p),
        ) ||
        parts[0].length > 2048)
      invalid('Invalid compact JWS.');
    try {
      final header = object(
        await decodeDocument(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
          maxBytes: 2048,
        ),
        {'alg', 'kid', 'typ'},
      );
      final key = _keys[header['kid']];
      if (header['alg'] != 'EdDSA' ||
          header['typ'] != 'localisync+json' ||
          key == null)
        throw const LocalisyncException(
          FailureCode.integrity,
          'Untrusted delivery signature.',
        );
      final signature = base64Url.decode(base64Url.normalize(parts[2]));
      if (signature.length != 64 ||
          !await Ed25519().verify(
            utf8.encode('${parts[0]}.${parts[1]}'),
            signature: Signature(signature, publicKey: key),
          ))
        throw const LocalisyncException(
          FailureCode.integrity,
          'Invalid delivery signature.',
        );
      final payload = base64Url.decode(base64Url.normalize(parts[1]));
      if (payload.length > maxPayloadBytes)
        invalid('Signed payload exceeds its limit.');
      return await decodeDocument(
        utf8.decode(payload),
        maxBytes: maxPayloadBytes,
      );
    } on FormatException {
      invalid('Invalid signed document encoding.');
    }
  }
}

Uint8List strictUtf8(String value) => Uint8List.fromList(utf8.encode(value));
