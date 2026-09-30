import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'chat_wallpaper.dart';
import 'native_bridge.dart';

/// The chat backgrounds saved on this device (see chat_wallpaper.dart):
/// which exist, picking a new one, removing one. Shared by all tabs, which
/// listen to it and update their pages.
class ChatWallpaperStore extends ChangeNotifier {
  Set<String> _keys = const {};
  final Map<String, int> _revisions = {};

  /// The last few photos as base64, so switching between chats does not read
  /// and encode the same file again.
  final Map<String, String> _encoded = {};
  static const int _maxEncoded = 3;

  /// Keys of the saved backgrounds ([defaultWallpaperKey] and chat ids).
  Set<String> get keys => _keys;

  bool get hasDefault => _keys.contains(defaultWallpaperKey);

  /// Changes whenever the photo of [key] changes, so pages know to reload it.
  int revision(String key) => _revisions[key] ?? 0;

  Future<void> load() async {
    _keys = await NativeBridge.listWallpapers();
    notifyListeners();
  }

  /// Lets the user pick a photo for [key]; false if nothing was picked.
  Future<bool> pick(String key) async {
    if (!isWallpaperKey(key) || !await NativeBridge.pickWallpaper(key)) return false;
    _changed(key, saved: true);
    return true;
  }

  Future<void> remove(String key) async {
    if (!_keys.contains(key)) return;
    await NativeBridge.removeWallpaper(key);
    _changed(key, saved: false);
  }

  /// Removes the backgrounds of single chats (on logout: chat ids belong to
  /// the account). The default background stays.
  Future<void> removeChatBackgrounds() async {
    for (final key in _keys.where((k) => k != defaultWallpaperKey).toList()) {
      await remove(key);
    }
  }

  /// The photo of [key] as JPEG bytes (for a preview), or null.
  Future<Uint8List?> bytes(String key) => NativeBridge.loadWallpaper(key);

  /// The photo of [key] as base64 (for the page's CSS), or null.
  Future<String?> base64(String key) async {
    final cached = _encoded[key];
    if (cached != null) return cached;
    final revision = this.revision(key);
    final data = await NativeBridge.loadWallpaper(key);
    if (data == null || revision != this.revision(key)) return null;
    final encoded = base64Encode(data);
    if (_encoded.length >= _maxEncoded) _encoded.remove(_encoded.keys.first);
    return _encoded[key] = encoded;
  }

  /// Average colour of the photo of [key] (to pick a readable text colour),
  /// or null if there is no photo or it cannot be decoded.
  Future<Rgb?> averageColor(String key) async {
    final revision = this.revision(key);
    final cached = _averages[key];
    if (cached != null && cached.revision == revision) return cached.color;
    final data = await NativeBridge.loadWallpaper(key);
    if (data == null) return null;
    final color = await averageColorOf(data);
    if (color != null) _averages[key] = (revision: revision, color: color);
    return color;
  }

  final Map<String, ({int revision, Rgb color})> _averages = {};

  /// Average sRGB colour of an encoded image, from a tiny decoded copy.
  @visibleForTesting
  static Future<Rgb?> averageColorOf(Uint8List encoded) async {
    try {
      final codec = await ui.instantiateImageCodec(encoded, targetWidth: 24);
      final image = (await codec.getNextFrame()).image;
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      codec.dispose();
      if (pixels == null || pixels.lengthInBytes < 4) return null;
      var r = 0, g = 0, b = 0;
      final count = pixels.lengthInBytes ~/ 4;
      for (var i = 0; i < count; i++) {
        r += pixels.getUint8(i * 4);
        g += pixels.getUint8(i * 4 + 1);
        b += pixels.getUint8(i * 4 + 2);
      }
      return (r: (r / count).round(), g: (g / count).round(), b: (b / count).round());
    } on Object {
      return null;
    }
  }

  void _changed(String key, {required bool saved}) {
    _keys = saved ? {..._keys, key} : ({..._keys}..remove(key));
    _revisions[key] = revision(key) + 1;
    _encoded.remove(key);
    _averages.remove(key);
    // Saved pictures of chats show the old background.
    NativeBridge.clearChatSnapshots();
    notifyListeners();
  }
}
