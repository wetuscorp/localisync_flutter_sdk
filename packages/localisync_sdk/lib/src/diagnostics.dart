import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:localisync_sdk/core.dart';
import 'platform/diagnostics_io.dart'
    if (dart.library.js_interop) 'platform/diagnostics_web.dart';

final class _Event {
  _Event(this.code, this.stage, this.time);
  final FailureCode code;
  final DiagnosticStage stage;
  final DateTime time;
  int count = 1;
}

/// Memory-only bounded SDK diagnostics; network/serialization runs after the read path returns.
final class SdkDiagnosticReporter implements DiagnosticSink {
  SdkDiagnosticReporter(this.config, this.appVersion)
    : _transport = DiagnosticTransport();
  final DiagnosticsConfig config;
  final String appVersion;
  final DiagnosticTransport _transport;
  LocalisyncStatus Function()? _context;
  void attach(LocalisyncClient client) => _context = () => client.status;
  final Map<(FailureCode, DiagnosticStage), _Event> _items = {};
  Timer? _timer;
  bool _closed = false, _sending = false;
  final Cancellation _cancel = Cancellation();
  @override
  void record(FailureCode code, DiagnosticStage stage) {
    if (_closed ||
        code == FailureCode.cancelled ||
        code == FailureCode.disposed)
      return;
    final now = DateTime.now(), key = (code, stage), old = _items[key];
    if (old != null && now.difference(old.time) < const Duration(minutes: 15)) {
      old.count = min(1000000, old.count + 1);
    } else {
      if (_items.length >= 100) return;
      // Fixed enum/date/count entries remain below 128 KiB even at the 100-event limit.
      _items[key] = _Event(code, stage, now);
    }
    _schedule();
  }

  void _schedule() {
    if (!_closed && !_sending && _timer == null)
      _timer = Timer(const Duration(seconds: 1), () {
        _timer = null;
        unawaited(_flush());
      });
  }

  String _id() {
    final random = Random.secure(),
        bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  Future<void> _flush() async {
    if (_closed || _sending) return;
    _sending = true;
    try {
      final events = <Map<String, Object>>[], now = DateTime.now();
      final context = _context?.call();
      for (final key in _items.keys.take(20).toList()) {
        final item = _items.remove(key)!;
        if (now.difference(item.time) >= const Duration(minutes: 15)) continue;
        events.add({
          'id': _id(),
          'observedAt': item.time.toUtc().toIso8601String(),
          'sdk': 'flutter',
          'sdkVersion': '0.1.0',
          'appVersion': appVersion,
          'code': item.code.name,
          'stage': item.stage.name,
          'count': item.count,
          if (context?.releaseId != null) 'releaseId': context!.releaseId!,
          if (context?.revision != null) 'revision': context!.revision!,
        });
      }
      if (events.isEmpty) return;
      final body = jsonEncode({'version': 1, 'events': events});
      if (utf8.encode(body).length > 32768) return;
      for (var attempt = 0; attempt < 2 && !_closed; attempt++) {
        try {
          final status = await _transport.send(config, body, _cancel);
          if (status < 500) break;
        } on Object {
          if (_closed) break;
        }
        if (attempt == 0)
          await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } on Object {
      /* Reporting failures never affect translation content or report themselves. */
    } finally {
      _sending = false;
      if (_items.isNotEmpty) _schedule();
    }
  }

  @override
  void close() {
    _closed = true;
    _timer?.cancel();
    _cancel.cancel();
    _transport.close();
    _items.clear();
    _context = null;
  }
}
