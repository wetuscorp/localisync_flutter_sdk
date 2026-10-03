import 'failure.dart';

/// Explicit opt-in. This credential can submit diagnostics but cannot read content.
final class DiagnosticsConfig {
  const DiagnosticsConfig({required this.endpoint, required this.key});
  final Uri endpoint;
  final String key;
  void validate(bool development) {
    if (endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        endpoint.path != '/telemetry/v1/sdk-events' ||
        !RegExp(r'^lsd_[\w-]{43}$').hasMatch(key) ||
        !(endpoint.scheme == 'https' ||
            development &&
                endpoint.scheme == 'http' &&
                [
                  'localhost',
                  '127.0.0.1',
                  '::1',
                  '10.0.2.2',
                ].contains(endpoint.host))) {
      throw const LocalisyncException(
        FailureCode.configuration,
        'Use a diagnostic endpoint and a separate write-only diagnostic key.',
      );
    }
  }
}

enum DiagnosticStage {
  start,
  refresh,
  locale,
  activate,
  translate,
  cache,
  worker,
}

/// A content-free port. Implementations must only enqueue bounded counters on record().
abstract interface class DiagnosticSink {
  void record(FailureCode code, DiagnosticStage stage);
  void close();
}
