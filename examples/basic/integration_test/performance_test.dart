import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:localisync_sdk/localisync_sdk.dart';
import 'package:localisync_sdk/src/platform/cache_io.dart';
import 'package:localisync_sdk/src/platform/factory_io.dart' as platform;
import 'package:localisync_sdk/src/platform/transport_io.dart';
import '../../../test_support/performance_delivery.dart';
import '../../../test_support/performance_metrics.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  // Device benchmarks leave frame scheduling to the engine. In fullyLive mode,
  // repeated pump hand-offs can stall the macOS profile runner between samples.
  testWidgets('profile delivery and cache', (tester) async {
    expect(kDebugMode, false, reason: 'Use profile or release mode.');
    final profiles = <Object?>[];
    final frames = _FrameMeasurements();
    await tester.runAsync(frames.monitorEventLoop);
    const controlSeconds = int.fromEnvironment(
      'LOCALISYNC_CONTROL_SECONDS',
      defaultValue: 2,
    );
    const startDelaySeconds = int.fromEnvironment(
      'LOCALISYNC_START_DELAY_SECONDS',
    );
    expect(controlSeconds, greaterThan(0));
    expect(startDelaySeconds, greaterThanOrEqualTo(0));
    const nativeState = MethodChannel('localisync.performance/device-state');
    Future<Object?> deviceState() async {
      try {
        return await nativeState.invokeMethod<Object?>('snapshot');
      } on MissingPluginException {
        return {'available': false};
      }
    }

    Future<void> show(Widget widget) async {
      await tester.pumpWidget(widget);
      await binding.endOfFrame.timeout(const Duration(seconds: 10));
    }

    try {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: startDelaySeconds)),
      );
      for (final name in ['small', 'icu', 'long']) {
        debugPrint('LOCALISYNC_STAGE $name fixtures');
        final root = await Directory.systemTemp.createTemp(
          'localisync-profile-',
        );
        final cacheDirectory = Directory('${root.path}/cache');
        PerformanceDelivery? server;
        try {
          await tester.runAsync(() async {
            server = await PerformanceDelivery.start(name, root);
          });
          final delivery = server!, index = delivery.index;
          final locale = index['locale']! as String;
          final locales = (index['files']! as List<Object?>)
              .map((v) => (v! as Map<String, Object?>)['locale']! as String)
              .toList();
          final bundled = TranslationBundle(
            fallbacks: {
              for (var i = 0; i < locales.length; i++)
                locales[i]: i == 0 ? null : locales[i - 1],
            },
            entries: {
              for (final value in locales)
                value: [
                  TranslationEntry(
                    key: 'key_1',
                    parameters: const {},
                    format: MessageFormat.plain,
                    value: 'Bundled text',
                  ),
                ],
            },
          );
          final samples = <String, List<double>>{
            for (final key in [
              'initialReadUs',
              'coldStartMs',
              'cacheStartMs',
              'networkMs',
              'verificationMs',
              'preparationMs',
              'activationMs',
              'rssAfterDisposeBytes',
            ])
              key: [],
          };
          final raw = <Object?>[];
          Map<String, num>? plain, icu;
          var diskBytes = 0;
          var visibleText = 'Bundled text';
          final deviceBefore = await tester.runAsync(deviceState);
          frames.reset();
          final rssBefore = ProcessInfo.currentRss;
          LocalisyncClient create(Measurements measurements) =>
              LocalisyncClient(
                config: LocalisyncConfig(
                  projectId: index['projectId']! as String,
                  distributionId: index['distributionId']! as String,
                  channel: Channel.preview,
                  addresses: delivery.addresses,
                  readKey: 'performance-fixture',
                  trustedKeys: {'test-1': index['publicKey']! as String},
                  appVersion: '1.0.0',
                  bundled: bundled,
                  locale: locale,
                  updatePolicy: UpdatePolicy.manual,
                  activationPolicy: ActivationPolicy.manual,
                  allowDevelopmentHttp: true,
                ),
                transport: TimedTransport(
                  PlatformDeliveryTransport(),
                  measurements,
                ),
                verification: TimedVerification(
                  platform.createVerification(),
                  measurements,
                ),
                preparer: TimedPreparer(
                  platform.createPreparer(),
                  measurements,
                ),
                cache: FileDeliveryCache(directory: () async => cacheDirectory),
              );
          for (var attempt = 0; attempt < 30; attempt++) {
            debugPrint('LOCALISYNC_STAGE $name $attempt start');
            LocalisyncClient? client, restored;
            final measurements = Measurements(
              onStage: (stage) => frames.stage = stage,
            );
            try {
              frames.recording = true;
              await tester.runAsync(() async {
                if (await cacheDirectory.exists())
                  await cacheDirectory.delete(recursive: true);
                await cacheDirectory.create();
                await delivery.online(true);
                final watch = Stopwatch()..start();
                frames.stage = 'create';
                client = create(measurements);
                expect(client!.translate('key_1'), 'Bundled text');
                samples['initialReadUs']!.add(
                  watch.elapsedMicroseconds.toDouble(),
                );
                await client!.ready;
                debugPrint('LOCALISYNC_STAGE $name $attempt ready');
              });
              await show(
                LocalisyncScope(
                  client: client!,
                  child: const _Screen(sdk: true),
                ),
              );
              await tester.runAsync(() async {
                final watch = Stopwatch()..start();
                final result = await client!.refresh();
                debugPrint('LOCALISYNC_STAGE $name $attempt downloaded');
                expect(
                  result.outcome,
                  UpdateOutcome.pending,
                  reason: result.failure?.message,
                );
                samples['coldStartMs']!.add(watch.elapsedMicroseconds / 1000);
                final transport = client!.status;
                expect(transport.failure, isNull);
                watch.reset();
                frames.stage = 'activate';
                await client!.activatePending();
                debugPrint('LOCALISYNC_STAGE $name $attempt activated');
                samples['activationMs']!.add(watch.elapsedMicroseconds / 1000);
                expect(client!.resolve('key_1').source, ContentSource.remote);
                samples['networkMs']!.add(measurements.networkMs);
                samples['verificationMs']!.add(measurements.verificationMs);
                samples['preparationMs']!.add(measurements.preparationMs);
                visibleText = client!.translate('key_1').substring(0, 12);
                frames.recording = false;
                if (attempt == 0) {
                  plain = lookup(() => client!.translate('key_1'));
                  icu = lookup(
                    () => client!.translate('key_0', arguments: {'count': 22}),
                  );
                }
                frames.recording = true;
                diskBytes = 0;
                await for (final entity in cacheDirectory.list(
                  recursive: true,
                )) {
                  if (entity is File) diskBytes += await entity.length();
                }
              });
              debugPrint('LOCALISYNC_STAGE $name $attempt detach');
              await show(_Screen(text: visibleText));
              debugPrint('LOCALISYNC_STAGE $name $attempt detached');
              frames.stage = 'dispose';
              await client!.dispose();
              debugPrint('LOCALISYNC_STAGE $name $attempt disposed');
              await tester.runAsync(() async {
                await delivery.online(false);
                final watch = Stopwatch()..start();
                frames.stage = 'restore';
                restored = create(
                  Measurements(
                    onStage: (stage) => frames.stage = 'restore-$stage',
                  ),
                );
                await restored!.ready;
                debugPrint('LOCALISYNC_STAGE $name $attempt restored');
                expect(restored!.resolve('key_1').source, ContentSource.remote);
                expect(restored!.status.persisted, true);
                samples['cacheStartMs']!.add(watch.elapsedMicroseconds / 1000);
                await restored!.dispose();
                samples['rssAfterDisposeBytes']!.add(
                  ProcessInfo.currentRss.toDouble(),
                );
                raw.add({
                  for (final entry in samples.entries)
                    if (entry.value.isNotEmpty) entry.key: entry.value.last,
                });
              });
            } finally {
              await client?.dispose();
              await restored?.dispose();
            }
          }
          frames.recording = false;
          final sdkFrames = frames.result();
          frames.reset();
          await show(_Screen(text: visibleText));
          frames.recording = true;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: controlSeconds)),
          );
          frames.recording = false;
          final controlFrames = frames.result();
          final record = {
            'profile': name,
            'keys': index['keys'],
            'values': index['values'],
            'contentBytes': index['bytes'],
            'iterations': 30,
            'transport':
                'two device loopback sockets, disk server on separate isolate',
            'mode': kReleaseMode ? 'release' : 'profile',
            'os': Platform.operatingSystem,
            'runtime': Platform.version,
            'rssBeforeBytes': rssBefore,
            'processPeakRssBytes': ProcessInfo.maxRss,
            'diskBytes': diskBytes,
            'plainLookupUs': plain,
            'icuLookupUs': icu,
            for (final entry in samples.entries)
              if (entry.value.isNotEmpty) entry.key: percentiles(entry.value),
            'sdkFrames': sdkFrames,
            'controlFrames': controlFrames,
            'controlSeconds': controlSeconds,
            'deviceBefore': deviceBefore,
            'deviceAfter': await tester.runAsync(deviceState),
            'raw': raw,
          };
          profiles.add(record);
          debugPrint('LOCALISYNC_PERFORMANCE ${jsonEncode(record)}');
          frames.reset();
        } finally {
          server?.close();
          await show(const SizedBox.shrink());
          await root.delete(recursive: true);
        }
      }
      binding.reportData = {'profiles': profiles};
    } finally {
      frames.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}

class _Screen extends StatelessWidget {
  const _Screen({this.sdk = false, this.text = 'Bundled text'});
  final bool sdk;
  final String text;
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sdk
                  ? LocalisyncScope.of(
                      context,
                    ).translate('key_1').substring(0, 12)
                  : text,
            ),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    ),
  );
}

/// Vsync gaps flag delayed frame delivery; event-loop and lifecycle evidence is
/// needed to distinguish UI work from scheduling or backgrounding.
/// Lookup microbenchmarks and fixture extraction are excluded from frame samples.
class _FrameMeasurements with WidgetsBindingObserver {
  _FrameMeasurements() {
    _ticker = Ticker(_tick);
    unawaited(_ticker.start());
    SchedulerBinding.instance.addTimingsCallback(_timings);
    WidgetsBinding.instance.addObserver(this);
  }
  final _clock = Stopwatch()..start();
  Timer? _heartbeat;
  int? _lastHeartbeat, _lastArrival;
  final _heartbeatGaps = <double>[];
  final _lateHeartbeats = <Map<String, Object?>>[];
  final _lifecycleEvents = <Map<String, Object?>>[];
  String? _initialLifecycle = WidgetsBinding.instance.lifecycleState?.name;
  Future<void> monitorEventLoop() async {
    // Start in tester.runAsync's real zone, not the widget test's fake clock.
    _heartbeat = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = _clock.elapsedMicroseconds;
      if (_recording && _lastHeartbeat != null) {
        final gap = (now - _lastHeartbeat!) / 1000;
        _heartbeatGaps.add(gap);
        if (gap > 50) {
          _lateHeartbeats.add({
            'milliseconds': gap,
            'elapsedUs': now,
            'stage': stage,
            'lifecycle': WidgetsBinding.instance.lifecycleState?.name,
          });
        }
      }
      _lastHeartbeat = _recording ? now : null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleEvents.add({
      'elapsedUs': _clock.elapsedMicroseconds,
      'state': state.name,
    });
  }

  late final Ticker _ticker;
  final _frames = <FrameTiming>[];
  final _gaps = <double>[];
  Duration? _previous;
  String stage = 'idle', _previousStage = 'idle';
  final _longFrames = <Map<String, Object?>>[];
  bool _recording = false;
  set recording(bool value) {
    _previous = null;
    _lastArrival = null;
    _lastHeartbeat = null;
    _recording = value;
  }

  void _tick(Duration timestamp) {
    if (!_recording) return;
    final now = _clock.elapsedMicroseconds;
    if (_previous != null) {
      final gap = (timestamp - _previous!).inMicroseconds / 1000;
      _gaps.add(gap);
      if (gap > 50)
        _longFrames.add({
          'milliseconds': gap,
          'from': _previousStage,
          'to': stage,
          'elapsedUs': now,
          'callbackGapMs': _lastArrival == null
              ? null
              : (now - _lastArrival!) / 1000,
          'lifecycle': WidgetsBinding.instance.lifecycleState?.name,
        });
    }
    _previous = timestamp;
    _lastArrival = now;
    _previousStage = stage;
  }

  void _timings(List<FrameTiming> values) {
    if (_recording) _frames.addAll(values);
  }

  Map<String, Object?> result() => {
    'buildUs': percentiles(
      _frames.map((f) => f.buildDuration.inMicroseconds.toDouble()).toList(),
    ),
    'rasterUs': percentiles(
      _frames.map((f) => f.rasterDuration.inMicroseconds.toDouble()).toList(),
    ),
    'vsyncGapMs': percentiles(_gaps),
    'gapsOver50Ms': _gaps.where((v) => v > 50).length,
    'longFrames': List.of(_longFrames),
    'eventLoopGapMs': percentiles(_heartbeatGaps),
    'eventLoopGapsOver50Ms': List.of(_lateHeartbeats),
    'initialLifecycle': _initialLifecycle,
    'finalLifecycle': WidgetsBinding.instance.lifecycleState?.name,
    'lifecycleEvents': List.of(_lifecycleEvents),
  };
  void reset() {
    _frames.clear();
    _gaps.clear();
    _longFrames.clear();
    _previous = null;
    _lastArrival = null;
    _lastHeartbeat = null;
    _heartbeatGaps.clear();
    _lateHeartbeats.clear();
    _lifecycleEvents.clear();
    _initialLifecycle = WidgetsBinding.instance.lifecycleState?.name;
  }

  void dispose() {
    _ticker.dispose();
    _heartbeat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    SchedulerBinding.instance.removeTimingsCallback(_timings);
  }
}
