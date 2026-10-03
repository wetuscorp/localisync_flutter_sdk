import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:localisync_sdk/core.dart';

/// Content-addressed blobs and a small revision guard share one IndexedDB transaction.
/// Parsing/verification happens outside transactions; no large JSON document is parsed
/// in an IndexedDB callback. Concurrent tabs serialize through the readwrite transaction.
final class IndexedDbDeliveryCache implements DeliveryCache {
  IndexedDbDeliveryCache({this.databaseName = 'localisync-delivery-v1'});
  final String databaseName;
  Future<web.IDBDatabase>? _opening;
  bool _closed = false;
  Future<web.IDBDatabase> _open() {
    if (_closed)
      throw const LocalisyncException(
        FailureCode.storage,
        'The cache is closed.',
      );
    return _opening ??= _connect();
  }

  Future<web.IDBDatabase> _connect() {
    final done = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(databaseName, 1);
    request.onupgradeneeded = ((web.Event event) {
      final db = request.result as web.IDBDatabase;
      db.createObjectStore('states');
      db.createObjectStore('blobs');
    }).toJS;
    request.onsuccess = ((web.Event event) {
      final db = request.result as web.IDBDatabase;
      if (done.isCompleted || _closed) {
        db.close();
        if (!done.isCompleted) done.completeError(_failure);
        return;
      }
      db.onversionchange = ((web.Event event) {
        db.close();
        _opening = null;
      }).toJS;
      done.complete(db);
    }).toJS;
    void fail() {
      if (!done.isCompleted) done.completeError(_failure);
    }

    request.onerror = ((web.Event event) => fail()).toJS;
    request.onblocked = ((web.Event event) => fail()).toJS;
    return done.future;
  }

  static const _failure = LocalisyncException(
    FailureCode.storage,
    'The persistent cache transaction could not be completed.',
  );
  List<JSAny?> _record(JSAny value) {
    if (!value.isA<JSArray>()) throw _failure;
    final parts = (value as JSArray<JSAny?>).toDart;
    if (parts.length != 4 ||
        parts[0] == null ||
        !parts[0]!.isA<JSNumber>() ||
        parts[1] == null ||
        !parts[1]!.isA<JSString>() ||
        parts[2] == null ||
        !parts[2]!.isA<JSString>() ||
        parts[3] == null ||
        !parts[3]!.isA<JSArray>())
      throw _failure;
    return parts;
  }

  List<String> _ids(JSAny value) =>
      (value as JSArray<JSAny?>).toDart.map((item) {
        if (item == null || !item.isA<JSString>()) throw _failure;
        final id = (item as JSString).toDart;
        if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) throw _failure;
        return id;
      }).toList();
  List<String> get _stores => ['states', 'blobs'];

  @override
  Future<CacheState?> read(String scope) async {
    final key = await sha256Hex(utf8.encode(scope)), db = await _open();
    final done = Completer<CacheState?>();
    final transaction = db.transaction(
      _stores.map((s) => s.toJS).toList().toJS,
      'readonly',
    );
    final request = transaction.objectStore('states').get(key.toJS);
    String? metadata;
    final blobs = <String, String>{};
    var total = 0;
    request.onsuccess = ((web.Event event) {
      try {
        final value = request.result;
        if (value == null) return;
        final parts = _record(value);
        metadata = (parts[2] as JSString).toDart;
        for (final id in _ids(parts[3]!)) {
          final blob = transaction.objectStore('blobs').get('$key:$id'.toJS);
          blob.onsuccess = ((web.Event event) {
            final value = blob.result;
            if (value != null && value.isA<JSString>()) {
              final text = (value as JSString).toDart;
              total += text.length;
              if (total > 256 * 1024 * 1024) {
                transaction.abort();
                return;
              }
              blobs[id] = text;
            }
          }).toJS;
        }
      } on Object {
        transaction.abort();
      }
    }).toJS;
    transaction.oncomplete = ((web.Event event) {
      if (done.isCompleted) return;
      done.complete(metadata == null ? null : _decode(metadata!, blobs));
    }).toJS;
    void fail() {
      if (!done.isCompleted) done.completeError(_failure);
    }

    transaction.onerror = ((web.Event event) => fail()).toJS;
    transaction.onabort = ((web.Event event) => fail()).toJS;
    return done.future;
  }

  Future<CacheState> _decode(String source, Map<String, String> blobs) async {
    final data = await decodeDocument(source, maxBytes: 8 * 1024 * 1024);
    if (data is! Map<String, Object?> || data['version'] != 1) throw _failure;
    CachedGeneration? generation(Object? value) {
      if (value == null) return null;
      if (value is! Map<String, Object?> || value['files'] is! List<Object?>)
        throw _failure;
      final files = <String, String>{};
      for (final id in value['files']! as List<Object?>) {
        final body = blobs[id];
        if (body == null) return null; // Recover previous or bundled content.
        files[id! as String] = body;
      }
      return CachedGeneration.fromJson({...value, 'files': files});
    }

    return CacheState(
      catalog: data['catalog'] is String ? data['catalog']! as String : null,
      active: generation(data['active']),
      previous: generation(data['previous']),
    );
  }

  @override
  Future<bool> write(
    String scope,
    CacheState state, {
    required int revision,
    required String catalogDigest,
    required int maxBytes,
    Cancellation? cancellation,
  }) async {
    cancellation?.check();
    final blobs = <String, String>{};
    Map<String, Object?>? metadata(CachedGeneration? generation) {
      if (generation == null) return null;
      blobs.addAll(generation.files);
      return {
        'catalog': generation.catalog,
        'manifest': generation.manifest,
        'locale': generation.locale,
        'files': generation.files.keys.toList(),
      };
    }

    final source = jsonEncode({
      'version': 1,
      'catalog': state.catalog,
      'active': metadata(state.active),
      'previous': metadata(state.previous),
    });
    var bytes = utf8.encode(source).length;
    for (final blob in blobs.entries) {
      final body = utf8.encode(blob.value);
      bytes += body.length;
      if (bytes > maxBytes)
        throw const LocalisyncException(
          FailureCode.storage,
          'The persistent cache exceeds its budget.',
        );
      if (await sha256Hex(body) != blob.key)
        throw const LocalisyncException(
          FailureCode.integrity,
          'A cached artifact does not match its digest.',
        );
      await Future<void>.delayed(Duration.zero);
    }
    if (bytes > maxBytes) throw _failure;
    final key = await sha256Hex(utf8.encode(scope)), db = await _open();
    cancellation?.check();
    final done = Completer<bool>();
    final transaction = db.transaction(
      _stores.map((s) => s.toJS).toList().toJS,
      'readwrite',
    );
    final states = transaction.objectStore('states'),
        artifacts = transaction.objectStore('blobs');
    final request = states.get(key.toJS);
    var accepted = true;
    request.onsuccess = ((web.Event event) {
      try {
        cancellation?.check();
        final value = request.result;
        List<String> oldIds = const [];
        if (value != null) {
          final parts = _record(value),
              oldRevision = (parts[0] as JSNumber).toDartDouble;
          if (oldRevision > revision ||
              oldRevision == revision &&
                  (parts[1] as JSString).toDart != catalogDigest)
            accepted = false;
          oldIds = _ids(parts[3]!);
        }
        if (!accepted) return;
        for (final blob in blobs.entries) {
          artifacts.put(blob.value.toJS, '$key:${blob.key}'.toJS);
        }
        for (final id in oldIds) {
          if (!blobs.containsKey(id)) artifacts.delete('$key:$id'.toJS);
        }
        states.put(
          <JSAny?>[
            revision.toJS,
            catalogDigest.toJS,
            source.toJS,
            blobs.keys.map((k) => k.toJS).toList().toJS,
          ].toJS,
          key.toJS,
        );
      } on Object {
        transaction.abort();
      }
    }).toJS;
    transaction.oncomplete = ((web.Event event) {
      if (!done.isCompleted) done.complete(accepted);
    }).toJS;
    void fail() {
      if (!done.isCompleted) done.completeError(_failure);
    }

    transaction.onerror = ((web.Event event) => fail()).toJS;
    transaction.onabort = ((web.Event event) => fail()).toJS;
    return done.future;
  }

  @override
  Future<void> close() async {
    _closed = true;
    final opening = _opening;
    if (opening != null) {
      try {
        (await opening).close();
      } on Object {
        /* Failed opens own no connection. */
      }
    }
  }
}
