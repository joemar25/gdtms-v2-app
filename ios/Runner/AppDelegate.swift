import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var timeChangeObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController

    // ── Storage + settings method channel ──────────────────────────────────
    FlutterMethodChannel(name: "fsi_courier/storage", binaryMessenger: controller.binaryMessenger)
      .setMethodCallHandler { (call, result) in
        switch call.method {
        case "getFreeDiskSpaceGb":
          do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let freeBytes = attrs[FileAttributeKey.systemFreeSize] as? Int64 ?? 0
            result(Double(freeBytes) / (1024.0 * 1024.0 * 1024.0))
          } catch {
            result(FlutterError(code: "UNAVAILABLE", message: error.localizedDescription, details: nil))
          }
        case "openDateTimeSettings":
          // iOS cannot deep-link to Date & Time settings; open app settings instead.
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    // ── Time-change event channel ───────────────────────────────────────────
    // NSSystemClockDidChangeNotification fires when the user changes the device
    // clock or timezone, allowing TimeEnforcer to react immediately.
    FlutterEventChannel(name: "fsi_courier/time_changes", binaryMessenger: controller.binaryMessenger)
      .setStreamHandler(TimeChangeStreamHandler())

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// MARK: - TimeChangeStreamHandler

private class TimeChangeStreamHandler: NSObject, FlutterStreamHandler {
  private var observer: NSObjectProtocol?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    observer = NotificationCenter.default.addObserver(
      forName: NSNotification.Name.NSSystemClockDidChange,
      object: nil,
      queue: .main
    ) { _ in
      events("clock_changed")
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let obs = observer {
      NotificationCenter.default.removeObserver(obs)
      observer = nil
    }
    return nil
  }
}
