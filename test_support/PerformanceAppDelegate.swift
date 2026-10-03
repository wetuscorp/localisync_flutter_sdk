// Test-only entry point for an isolated basic example; never part of an SDK package.
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var events: [[String: Any]] = []
  private var observers: [NSObjectProtocol] = []
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    application.isIdleTimerDisabled = true
    let names: [Notification.Name] = [
      ProcessInfo.thermalStateDidChangeNotification,
      .NSProcessInfoPowerStateDidChange, UIApplication.didReceiveMemoryWarningNotification,
      UIApplication.willResignActiveNotification, UIApplication.didBecomeActiveNotification,
      UIApplication.didEnterBackgroundNotification, UIApplication.willEnterForegroundNotification,
    ]
    for name in names {
      observers.append(
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
          [weak self] event in
          self?.events.append([
            "event": event.name.rawValue, "uptimeSeconds": ProcessInfo.processInfo.systemUptime,
            "thermalState": ProcessInfo.processInfo.thermalState.rawValue,
          ])
        })
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LocalisyncPerformanceProbe")!
    let channel = FlutterMethodChannel(
      name: "localisync.performance/device-state", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "snapshot" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let process = ProcessInfo.processInfo
      result([
        "available": true, "uptimeSeconds": process.systemUptime,
        "thermalState": process.thermalState.rawValue,
        "lowPowerMode": process.isLowPowerModeEnabled,
        "applicationState": UIApplication.shared.applicationState.rawValue,
        "events": self?.events ?? [],
      ])
    }
  }
}
