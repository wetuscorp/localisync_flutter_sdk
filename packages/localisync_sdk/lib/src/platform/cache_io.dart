import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui' show RootIsolateToken;
import 'package:localisync_sdk/core.dart';
import 'package:path_provider/path_provider.dart';

/// Immutable content blobs plus two recoverable metadata slots. File locks coordinate
/// processes; the keyed gate also coordinates handles in the same Dart isolate.
final class FileDeliveryCache implements DeliveryCache {
  FileDeliveryCache({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory {
    // POSIX advisory locks are process-scoped, not isolate-scoped. Coordinate all
    // cache transactions on Flutter's root isolate. Private blob workers never
    // acquire locks or read/change activation metadata.
    if (RootIsolateToken.instance == null) {
      throw const LocalisyncException(
        FailureCode.configuration,
        'Create native platform storage on the Flutter root isolate.',
      );
    }
  }
  final Future<Directory> Function() _directory;
  static final _gates = <String, Future<void>>{};
  bool _closed = false;
  Future<T> _locked<T>(String scope, Future<T> Function(Directory) work) async {
    if (_closed)
      throw const LocalisyncException(
        FailureCode.storage,
        'The cache is closed.',
      );
    final key = await sha256Hex(utf8.encode(scope)), root = await _directory();
    final directory = Directory('${root.path}/localisync/$key');
    await directory.create(recursive: true);
    final gateKey = directory.path,
        previous = _gates[gateKey],
        done = Completer<void>();
    _gates[gateKey] = done.future;
    if (previous != null) await previous;
    RandomAccessFile? handle;
    try {
      handle = await File('${directory.path}/lock').open(mode: FileMode.append);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (true) {
        try {
          await handle.lock(FileLock.exclusive);
          break;
        } on FileSystemException {
          if (DateTime.now().isAfter(deadline)) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      }
      return await work(directory);
    } finally {
      if (handle != null) {
        try {
          await handle.unlock();
        } on FileSystemException {
          /* A failed lock owns no region. */
        }
        await handle.close();
      }
      done.complete();
      if (identical(_gates[gateKey], done.future)) {
        final removed = _gates.remove(gateKey);
        if (removed != null) unawaited(removed);
      }
    }
  }

  Future<Map<String, Object?>?> _record(Directory dir, String name) async {
    final file = File('${dir.path}/$name');
    if (!await file.exists()) return null;
    try {
      if (await file.length() > 8 * 1024 * 1024) return null;
      final envelope = await decodeDocument(
        await file.readAsString(),
        maxBytes: 8 * 1024 * 1024,
      );
      if (envelope is! Map<String, Object?> ||
          envelope['payload'] is! String ||
          envelope['digest'] is! String)
        return null;
      final payload = envelope['payload']! as String;
      if (await _textDigest(payload) != envelope['digest']) return null;
      final data = await decodeDocument(payload, maxBytes: 8 * 1024 * 1024);
      return data is Map<String, Object?> ? data : null;
    } on Object {
      return null;
    }
  }

  Future<({Map<String, Object?> data, int sequence})?> _latest(
    Directory dir,
  ) async {
    ({Map<String, Object?> data, int sequence})? latest;
    for (final name in ['state-0.json', 'state-1.json']) {
      final data = await _record(dir, name), sequence = data?['sequence'];
      // Records without a version are the identical pre-release schema. Upgrade
      // them only on a verified commit; never overwrite a future unknown schema.
      if (data != null && data['version'] != null && data['version'] != 1)
        throw const LocalisyncException(
          FailureCode.storage,
          'Unsupported persistent cache schema.',
        );
      if (data != null &&
          sequence is int &&
          sequence >= 0 &&
          (latest == null || sequence > latest.sequence))
        latest = (data: data, sequence: sequence);
    }
    return latest;
  }

  Future<CachedGeneration?> _generation(Directory dir, Object? value) async {
    if (value == null) return null;
    if (value is! Map<String, Object?>)
      throw const LocalisyncException(
        FailureCode.storage,
        'Invalid cache metadata.',
      );
    final data = Map<String, Object?>.of(value), list = data['files'];
    if (list is! List<Object?>)
      throw const LocalisyncException(
        FailureCode.storage,
        'Invalid cached artifact list.',
      );
    final files = <String, String>{};
    var total = 0;
    for (final item in list) {
      if (item is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(item))
        throw const LocalisyncException(
          FailureCode.storage,
          'Invalid cached artifact identifier.',
        );
      final file = File('${dir.path}/$item.blob');
      total += await file.length();
      if (total > DeliveryLimits.bytes)
        throw const LocalisyncException(
          FailureCode.storage,
          'Cached content exceeds its limit.',
        );
      files[item] = await file.readAsString();
    }
    data['files'] = files;
    return CachedGeneration.fromJson(data);
  }

  @override
  Future<CacheState?> read(String scope) => _locked(scope, (dir) async {
    final latest = await _latest(dir);
    if (latest == null) return null;
    final data = latest.data, catalog = data['catalog'];
    CachedGeneration? active, previous;
    try {
      active = await _generation(dir, data['active']);
    } on Object {
      /* Try a previous complete generation. */
    }
    try {
      previous = await _generation(dir, data['previous']);
    } on Object {
      /* The bundled baseline remains available. */
    }
    return CacheState(
      catalog: catalog is String ? catalog : null,
      active: active,
      previous: previous,
    );
  });

  @override
  Future<bool> write(
    String scope,
    CacheState state, {
    required int revision,
    required String catalogDigest,
    required int maxBytes,
    Cancellation? cancellation,
  }) => _locked(scope, (dir) async {
    cancellation?.check();
    final latest = await _latest(dir), old = latest?.data;
    if (old != null) {
      final r = old['revision'];
      if (r is! int ||
          r > revision ||
          (r == revision && old['catalogDigest'] != catalogDigest))
        return false;
    }
    final blobs = <String, String>{};
    Map<String, Object?>? metadata(CachedGeneration? g) {
      if (g == null) return null;
      blobs.addAll(g.files);
      return {
        'catalog': g.catalog,
        'manifest': g.manifest,
        'locale': g.locale,
        'files': g.files.keys.toList(),
      };
    }

    final sequence = (latest?.sequence ?? -1) + 1;
    final record = {
      'version': 1,
      'sequence': sequence,
      'revision': revision,
      'catalogDigest': catalogDigest,
      'catalog': state.catalog,
      'active': metadata(state.active),
      'previous': metadata(state.previous),
    };
    final payload = jsonEncode(record),
        envelope = utf8.encode(
          jsonEncode({
            'payload': payload,
            'digest': await _textDigest(payload),
          }),
        );
    // Size a generation once, away from the UI isolate. Encoding every locale
    // twice here previously blocked frames at the 100 MiB package boundary.
    final lengths = await _blobLengths(blobs);
    final bytes =
        envelope.length * 2 +
        lengths.values.fold(0, (total, length) => total + length);
    if (bytes > maxBytes)
      throw const LocalisyncException(
        FailureCode.storage,
        'The cache budget cannot hold the active and previous generations.',
      );
    // Reserve the peak staging footprint as well as the final pair. Neither live
    // generation may be deleted merely to make room for an uncommitted update.
    final protected = <String>{};
    for (final slot in ['state-0.json', 'state-1.json']) {
      final saved = await _record(dir, slot);
      for (final kind in ['active', 'previous']) {
        final generation = saved?[kind];
        if (generation is Map<String, Object?> &&
            generation['files'] is List<Object?>) {
          for (final key in generation['files']! as List<Object?>) {
            if (key is String) protected.add('$key.blob');
          }
        }
      }
    }
    var stagedBytes = envelope.length * 2;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.endsWith('.tmp') ||
          name.endsWith('.blob') && !protected.contains(name)) {
        await entity.delete();
      } else if (name != 'lock') {
        stagedBytes += await entity.length();
      }
    }
    for (final item in blobs.entries) {
      if (!protected.contains('${item.key}.blob'))
        stagedBytes += lengths[item.key]!;
    }
    if (stagedBytes > maxBytes)
      throw const LocalisyncException(
        FailureCode.storage,
        'The cache budget cannot safely stage this update while preserving verified generations.',
      );
    for (final item in blobs.entries) {
      // The root isolate keeps the process/file lock for the complete commit.
      // A private worker owns only this immutable blob operation; large byte
      // buffers never return to the UI isolate.
      await _storeBlob(
        '${dir.path}/${item.key}.blob',
        item.value,
        item.key,
        maxBytes - stagedBytes,
      );
    }
    cancellation?.check();
    await _atomic(File('${dir.path}/state-${sequence % 2}.json'), envelope);
    // Repair the redundant slot only after the first durable commit. Both slots now
    // protect the same active/previous pair, rather than retaining a third generation.
    await _atomic(
      File('${dir.path}/state-${(sequence + 1) % 2}.json'),
      envelope,
    );
    final referenced = Set<String>.of(blobs.keys);
    for (final name in ['state-0.json', 'state-1.json']) {
      final saved = await _record(dir, name);
      for (final kind in ['active', 'previous']) {
        final generation = saved?[kind];
        if (generation is Map<String, Object?> &&
            generation['files'] is List<Object?>) {
          for (final key in generation['files']! as List<Object?>) {
            if (key is String) referenced.add(key);
          }
        }
      }
    }
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.endsWith('.blob') &&
              !referenced.contains(name.substring(0, name.length - 5)) ||
          name.endsWith('.tmp')) {
        try {
          await entity.delete();
        } on FileSystemException {
          /* Retry cleanup on the next successful commit. */
        }
      }
    }
    return true;
  });
  @override
  Future<void> close() async {
    _closed = true;
  }
}

Future<String> _textDigest(String source) => source.length < 65536
    ? sha256Hex(utf8.encode(source))
    : Isolate.run(() => sha256Hex(utf8.encode(source)));

Future<Map<String, int>> _blobLengths(Map<String, String> blobs) => Isolate.run(
  () => {
    for (final entry in blobs.entries)
      entry.key: utf8.encode(entry.value).length,
  },
);

Future<void> _atomic(File target, List<int> bytes) async {
  final random = Random.secure(),
      suffix = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
  final temporary = File('${target.path}.$suffix.tmp');
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(target.path);
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

Future<void> _storeBlob(
  String path,
  String source,
  String digest,
  int repairBudget,
) => Isolate.run(() async {
  final bytes = utf8.encode(source);
  if (await sha256Hex(bytes) != digest)
    throw const LocalisyncException(
      FailureCode.integrity,
      'A cache artifact does not match its digest.',
    );
  final file = File(path);
  final exists = await file.exists();
  if (!exists ||
      await file.length() != bytes.length ||
      await sha256Hex(await file.readAsBytes()) != digest) {
    if (exists && bytes.length > repairBudget)
      throw const LocalisyncException(
        FailureCode.storage,
        'The cache budget cannot safely repair an artifact.',
      );
    await _atomic(file, bytes);
  }
});
