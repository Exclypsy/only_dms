import Flutter
import UIKit
import UserNotifications
import WebKit
import webview_flutter_wkwebview

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

/// iOS side of lib/native_bridge.dart: local notifications and WebView
/// keyboard behaviour. (The other channel methods are Android-only and not
/// implemented here.)
enum NativeChannel {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.martinbartko.nofeed/native",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "configureWebView":
        let args = call.arguments as? [String: Any]
        if let id = (args?["id"] as? NSNumber)?.int64Value,
          let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
            forIdentifier: id, withPluginRegistrar: registrar)
        {
          WebViewKeyboard.configure(webView)
        }
        result(nil)
      case "dismissKeyboard":
        let args = call.arguments as? [String: Any]
        if let id = (args?["id"] as? NSNumber)?.int64Value,
          let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
            forIdentifier: id, withPluginRegistrar: registrar)
        {
          webView.endEditing(true)
        }
        result(nil)
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

/// Keyboard behaviour of the chat, like in the Instagram app:
/// - Flutter shrinks the WebView above the keyboard (resizeToAvoidBottomInset),
///   so the chat's header stays visible. WKWebView's own keyboard handling
///   (it scrolls the whole page up, like Safari) is turned off, otherwise the
///   page would move twice.
/// - No "‹ › Done" bar above the keyboard (WebKit's form accessory bar).
enum WebViewKeyboard {
  private static let keyboardNotifications: [Notification.Name] = [
    UIResponder.keyboardWillShowNotification,
    UIResponder.keyboardDidShowNotification,
    UIResponder.keyboardWillHideNotification,
    UIResponder.keyboardDidHideNotification,
    UIResponder.keyboardWillChangeFrameNotification,
    UIResponder.keyboardDidChangeFrameNotification,
  ]

  static func configure(_ webView: WKWebView) {
    for name in keyboardNotifications {
      NotificationCenter.default.removeObserver(webView, name: name, object: nil)
    }
    hideAccessoryBar()
  }

  /// WebKit's text input view (WKContentView) returns no `inputAccessoryView`.
  /// Done once for the class (public Objective-C runtime API only); changing
  /// the class of a live view instead left the page blank.
  private static var accessoryBarHidden = false

  private static func hideAccessoryBar() {
    guard !accessoryBarHidden, let contentViewClass = NSClassFromString("WKContentView") else {
      return
    }
    accessoryBarHidden = true
    let selector = #selector(getter: UIResponder.inputAccessoryView)
    guard let method = class_getInstanceMethod(UIResponder.self, selector) else { return }
    let noAccessory: @convention(block) (AnyObject) -> UIView? = { _ in nil }
    class_replaceMethod(
      contentViewClass, selector, imp_implementationWithBlock(noAccessory),
      method_getTypeEncoding(method))
  }
}
