import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'media_pick_request.dart';

/// Small Android-only platform channel (see MainActivity.kt). On other
/// platforms every call is a safe no-op.
class NativeBridge {
  const NativeBridge._();

  static const MethodChannel _channel = MethodChannel('com.martinbartko.nofeed/native');

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
