import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    FlutterMethodChannel(name: "fsi_courier/storage", binaryMessenger: controller.binaryMessenger)
      .setMethodCallHandler { (call, result) in
        guard call.method == "getFreeDiskSpaceGb" else {
          result(FlutterMethodNotImplemented)
          return
        }
        do {
          let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
          let freeBytes = attrs[FileAttributeKey.systemFreeSize] as? Int64 ?? 0
          result(Double(freeBytes) / (1024.0 * 1024.0 * 1024.0))
        } catch {
          result(FlutterError(code: "UNAVAILABLE", message: error.localizedDescription, details: nil))
        }
      }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
