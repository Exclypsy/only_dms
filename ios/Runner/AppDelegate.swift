import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Show NoFeed's notifications also while the app is open (e.g. when you
    // are on the Profile tab or in another chat).
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NoFeedNative") {
      NativeChannel.register(with: registrar)
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }
}

/// iOS side of lib/native_bridge.dart: local notifications only. Their text
/// never contains names or message content – only Instagram's unread counter.
/// (The other channel methods are Android-only and not implemented here.)
enum NativeChannel {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.martinbartko.nofeed/native",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "requestNotifications":
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
          granted, _ in
          DispatchQueue.main.async { result(granted) }
        }
      case "showNotification":
        let args = call.arguments as? [String: Any]
        let content = UNMutableNotificationContent()
        content.title = args?["title"] as? String ?? "NoFeed"
        content.body = args?["body"] as? String ?? ""
        content.sound = .default
        // Same identifier: a newer notification replaces the older one.
        let request = UNNotificationRequest(identifier: "nofeed-unread", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in
          DispatchQueue.main.async { result(nil) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
