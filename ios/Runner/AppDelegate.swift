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

/// iOS side of lib/native_bridge.dart: local notifications, WebView keyboard
/// behaviour and chat pictures. (The other channel methods are Android-only
/// and not implemented here.)
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
      case "saveChatSnapshot":
        let args = call.arguments as? [String: Any]
        if let id = (args?["id"] as? NSNumber)?.int64Value,
          let key = args?["key"] as? String,
          let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
            forIdentifier: id, withPluginRegistrar: registrar)
        {
          ChatSnapshots.save(webView, key: key) { saved in result(saved) }
        } else {
          result(false)
        }
      case "loadChatSnapshot":
        let key = (call.arguments as? [String: Any])?["key"] as? String ?? ""
        ChatSnapshots.load(key: key) { data in
          result(data.map { FlutterStandardTypedData(bytes: $0) })
        }
      case "clearChatSnapshots":
        ChatSnapshots.clear()
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
        // One notification per chat: a newer message of the same chat
        // replaces the older one, different chats are listed separately.
        let tag = args?["tag"] as? String ?? "unread"
        content.threadIdentifier = tag
        let request = UNNotificationRequest(
          identifier: "nofeed-\(tag)", content: content, trigger: nil)
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

/// Pictures of opened chats for instant opening (see lib/chat_snapshot.dart).
/// Stored only in the app's Caches folder (never backed up, the system may
/// purge it), encrypted by iOS while the phone is locked, at most
/// `maxCount` chats; deleted on logout.
enum ChatSnapshots {
  private static let maxCount = 30
  private static let queue = DispatchQueue(label: "nofeed.chat-snapshots", qos: .userInitiated)

  private static var directory: URL? {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
      .appendingPathComponent("chat_snapshots", isDirectory: true)
  }

  /// Keys come from lib/chat_snapshot.dart; checked again so that a key can
  /// never leave the folder.
  private static func file(for key: String) -> URL? {
    let allowed = CharacterSet(
      charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
    guard !key.isEmpty, key.count <= 80,
      key.unicodeScalars.allSatisfy({ allowed.contains($0) })
    else { return nil }
    return directory?.appendingPathComponent("\(key).jpg")
  }

  static func save(_ webView: WKWebView, key: String, completion: @escaping (Bool) -> Void) {
    guard let file = file(for: key), webView.window != nil, webView.bounds.height > 100 else {
      completion(false)
      return
    }
    webView.takeSnapshot(with: nil) { image, _ in
      guard let data = image?.jpegData(compressionQuality: 0.82) else {
        completion(false)
        return
      }
      queue.async {
        var saved = false
        do {
          try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
          try data.write(to: file, options: [.atomic, .completeFileProtection])
          prune()
          saved = true
        } catch {
          saved = false
        }
        DispatchQueue.main.async { completion(saved) }
      }
    }
  }

  static func load(key: String, completion: @escaping (Data?) -> Void) {
    guard let file = file(for: key) else {
      completion(nil)
      return
    }
    queue.async {
      let data = try? Data(contentsOf: file)
      DispatchQueue.main.async { completion(data) }
    }
  }

  static func clear() {
    guard let directory else { return }
    queue.async { try? FileManager.default.removeItem(at: directory) }
  }

  /// Keeps the most recently saved `maxCount` pictures.
  private static func prune() {
    guard let directory,
      let files = try? FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
    else { return }
    let byDate = files.sorted {
      let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate ?? .distantPast
      let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate ?? .distantPast
      return a > b
    }
    for file in byDate.dropFirst(maxCount) {
      try? FileManager.default.removeItem(at: file)
    }
  }
}
