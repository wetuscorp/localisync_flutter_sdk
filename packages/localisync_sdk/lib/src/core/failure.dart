/// Stable, content-free diagnostic codes. Messages never contain translation input.
enum FailureCode {
  configuration,
  network,
  timeout,
  cancelled,
  authorization,
  integrity,
  protocol,
  incompatible,
  staleRevision,
  storage,
  locale,
  arguments,
  disposed,
}

final class LocalisyncException implements Exception {
  const LocalisyncException(this.code, this.message);
  final FailureCode code;
  final String message;
  @override
  String toString() => 'LocalisyncException(${code.name}): $message';
}

Never invalid(String message) =>
    throw LocalisyncException(FailureCode.protocol, message);

/// Cancellation belongs to one operation, not a shared HTTP client.
final class Cancellation {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];
  bool get isCancelled => _cancelled;
  void check() {
    if (_cancelled) {
      throw const LocalisyncException(
        FailureCode.cancelled,
        'The operation was cancelled.',
      );
    }
  }

  void Function() onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }
}
