import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'media_pick_request.dart';

/// Small platform channel (MainActivity.kt on Android, AppDelegate.swift on
/// iOS). Calls a platform does not support are safe no-ops.
class NativeBridge {
  const NativeBridge._();

  static const MethodChannel _channel = MethodChannel('com.martinbartko.nofeed/native');

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Asks for permission to show notifications (system dialog). True if allowed.
  static Future<bool> requestNotifications() async {
    if (!_isAndroid && !_isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('requestNotifications') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Shows a local notification. Notifications with the same [tag] (one chat)
  /// replace each other; different chats are shown side by side.
  static Future<void> showNotification({
    required String title,
    required String body,
    String? tag,
  }) async {
    if (!_isAndroid && !_isIOS) return;
    try {
      await _channel.invokeMethod<void>('showNotification', {
        'title': title,
        'body': body,
        'tag': tag,
      });
    } on PlatformException {
      // Notifications are best effort.
    }
  }

  /// Android: keeps NoFeed running in the background with a foreground
  /// service (visible notification), like a browser tab left open, so the
  /// page keeps receiving messages. iOS does not allow this.
  static Future<void> setKeepAlive(bool keepAlive) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setKeepAlive', {'keepAlive': keepAlive});
    } on PlatformException {
      // Best effort.
    }
  }

  /// iOS: the WebView leaves the keyboard to Flutter (the page is resized
  /// above it instead of being scrolled away) and shows no form accessory bar
  /// above the keyboard. See WebViewKeyboard in AppDelegate.swift.
  static Future<void> configureWebView(int webViewId) async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod<void>('configureWebView', {'id': webViewId});
    } on PlatformException {
      // Keeps WebKit's default keyboard handling.
    }
  }

  /// Closes the keyboard of a WebView (iOS: [webViewId]; Android: the app's).
  static Future<void> dismissKeyboard({int? webViewId}) async {
    if (!_isAndroid && !_isIOS) return;
    try {
      await _channel.invokeMethod<void>('dismissKeyboard', {'id': webViewId});
    } on PlatformException {
      // Best effort.
    }
  }

  /// Saves a picture of the WebView [webViewId] as the snapshot of a chat
  /// (see chat_snapshot.dart). True if it was saved.
  static Future<bool> saveChatSnapshot({required int webViewId, required String key}) async {
    if (!_isAndroid && !_isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('saveChatSnapshot', {'id': webViewId, 'key': key}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// The saved picture of a chat (JPEG bytes), or null.
  static Future<Uint8List?> loadChatSnapshot(String key) async {
    if (!_isAndroid && !_isIOS) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('loadChatSnapshot', {'key': key});
    } on PlatformException {
      return null;
    }
  }

  /// Deletes all saved chat pictures.
  static Future<void> clearChatSnapshots() async {
    if (!_isAndroid && !_isIOS) return;
    try {
      await _channel.invokeMethod<void>('clearChatSnapshots');
    } on PlatformException {
      // Best effort.
    }
  }

  /// Opens the system photo picker and saves the chosen photo as the chat
  /// background [key] (see chat_wallpaper.dart). False if nothing was picked.
  static Future<bool> pickWallpaper(String key) async {
    if (!_isAndroid && !_isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('pickWallpaper', {'key': key}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// The saved chat background [key] (JPEG bytes), or null.
  static Future<Uint8List?> loadWallpaper(String key) async {
    if (!_isAndroid && !_isIOS) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('loadWallpaper', {'key': key});
    } on PlatformException {
      return null;
    }
  }

  static Future<void> removeWallpaper(String key) async {
    if (!_isAndroid && !_isIOS) return;
    try {
      await _channel.invokeMethod<void>('removeWallpaper', {'key': key});
    } on PlatformException {
      // Best effort.
    }
  }

  /// Keys of all saved chat backgrounds.
  static Future<Set<String>> listWallpapers() async {
    if (!_isAndroid && !_isIOS) return const {};
    try {
      return (await _channel.invokeListMethod<String>('listWallpapers'))?.toSet() ?? const {};
    } on PlatformException {
      return const {};
    }
  }

  /// Turns FLAG_SECURE on or off for the app window.
  static Future<void> setSecure(bool secure) async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('setSecure', {'secure': secure});
  }

  /// Opens the system Photo Picker (or document picker) and returns the
  /// picked `content://` URIs; an empty list means cancelled.
  static Future<List<String>> pickMedia(MediaPickRequest request) async {
    if (!_isAndroid) return const [];
    try {
      final uris = await _channel.invokeListMethod<String>('pickMedia', request.toMap());
      return uris ?? const [];
    } on PlatformException {
      return const [];
    }
  }

  /// Asks for Android runtime permissions (system dialog). Returns true only
  /// if all requested permissions are granted.
  static Future<bool> requestMediaPermissions({
    required bool camera,
    required bool microphone,
  }) async {
    if (!_isAndroid || (!camera && !microphone)) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermissions', {
        'camera': camera,
        'microphone': microphone,
      });
      return granted ?? false;
    } on PlatformException {
      return false;
    }
  }
}
