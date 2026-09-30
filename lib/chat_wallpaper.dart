/// Custom chat backgrounds: a photo you pick is shown behind the messages of
/// every chat ("default") or of one chat (its own picture wins).
///
/// The photo is stored only on this device (see NativeBridge / ChatWallpapers
/// on the native side) and is put into Instagram's page as a CSS background of
/// the message list – cosmetic only: the scripts here write a `<style>`, one
/// attribute and two CSS variables and read nothing from the page.
///
/// Pure Dart so it can be unit-tested.
library;

import 'dart:math' as math;

/// Key of the background used for all chats without their own.
const String defaultWallpaperKey = 'default';

/// How strongly the page colour is laid over the photo (0 = not at all), to
/// tone a busy photo down. Text on it is kept readable by its colour, see
/// [wallpaperNeedsDarkText].
const double defaultWallpaperDim = 0.2;
const double maxWallpaperDim = 0.8;

final RegExp _chatId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final RegExp _key = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final RegExp _base64 = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
final RegExp _cssColor = RegExp(r'^#[0-9a-fA-F]{6}$');

/// Key of the own background of the chat at [url] (`/direct/t/<id>/`), or
/// null if [url] is not a chat. Only characters safe in a file name and in CSS.
String? chatWallpaperKey(String? url) {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null) return null;
  final segments = [
    for (final s in uri.pathSegments)
      if (s.isNotEmpty) s,
  ];
  if (segments.length < 3 || segments[0] != 'direct' || segments[1] != 't') return null;
  final id = segments[2];
  // "default" is reserved for the background of all chats.
  if (!_chatId.hasMatch(id) || id == defaultWallpaperKey) return null;
  return id;
}

/// Which saved background the chat at [url] shows: its own, else the default,
/// else none. Null also for pages that are not a chat.
String? resolveWallpaperKey(String? url, Set<String> saved) {
  final own = chatWallpaperKey(url);
  if (own == null) return null;
  if (saved.contains(own)) return own;
  return saved.contains(defaultWallpaperKey) ? defaultWallpaperKey : null;
}

bool isWallpaperKey(String key) => _key.hasMatch(key);

/// An sRGB colour with channels 0–255 (average colour of a photo).
typedef Rgb = ({int r, int g, int b});

Rgb _parseCssColor(String color) {
  if (!_cssColor.hasMatch(color)) throw ArgumentError.value(color, 'color');
  return (
    r: int.parse(color.substring(1, 3), radix: 16),
    g: int.parse(color.substring(3, 5), radix: 16),
    b: int.parse(color.substring(5, 7), radix: 16),
  );
}

/// Relative luminance (0 = black, 1 = white) as defined by WCAG.
double _luminance(double r, double g, double b) {
  double linear(double channel) {
    final c = channel / 255;
    return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b);
}

/// Whether text written straight on the background (times, names) should be
/// black rather than white: [photo] is the photo's average colour, over which
/// the page colour [background] (`#rrggbb`) is laid at opacity [dim]. Picks
/// the colour with the higher contrast.
bool wallpaperNeedsDarkText({required Rgb photo, required String background, required double dim}) {
  final page = _parseCssColor(background);
  final a = dim.clamp(0, maxWallpaperDim).toDouble();
  double mix(int photoChannel, int pageChannel) => photoChannel * (1 - a) + pageChannel * a;
  final luminance = _luminance(mix(photo.r, page.r), mix(photo.g, page.g), mix(photo.b, page.b));
  // Black text contrasts better than white above this luminance
  // ((L + 0.05) / 0.05 > 1.05 / (L + 0.05)).
  return luminance > 0.179;
}

/// Script that puts the photo ([jpegBase64]) of background [key] into the
/// page. It does not show it yet – see [selectWallpaperScript].
String installWallpaperScript(String key, String jpegBase64) {
  if (!isWallpaperKey(key)) throw ArgumentError.value(key, 'key');
  if (!_base64.hasMatch(jpegBase64)) throw ArgumentError('not base64');
  // The dim layer is a flat gradient in the page colour above the photo.
  final css =
      'html[data-nofeed-wallpaper="$key"] [data-pagelet="IGDMessagesList"]{'
      'background-image:linear-gradient(var(--nofeed-wallpaper-dim,transparent),'
      'var(--nofeed-wallpaper-dim,transparent)),'
      'url(data:image/jpeg;base64,$jpegBase64)!important}';
  return '''
(() => {
  const id = 'nofeed-wallpaper-$key';
  let style = document.getElementById(id);
  if (!style) {
    style = document.createElement('style');
    style.id = id;
    (document.head || document.documentElement).appendChild(style);
  }
  style.textContent = '$css';
})()
''';
}

/// Script that shows background [key] (null = none) with the page colour
/// [background] (`#rrggbb`) laid over it at opacity [dim]. [darkText] makes
/// the text written straight on the background black (true) or white (false);
/// null leaves Instagram's colour.
String selectWallpaperScript(
  String? key, {
  required String background,
  required double dim,
  bool? darkText,
}) {
  if (key == null) {
    return "document.documentElement.removeAttribute('data-nofeed-wallpaper');";
  }
  if (!isWallpaperKey(key)) throw ArgumentError.value(key, 'key');
  final page = _parseCssColor(background);
  final alpha = dim.clamp(0, maxWallpaperDim).toStringAsFixed(2);
  final text = switch (darkText) {
    true => "root.style.setProperty('--nofeed-wallpaper-text', '0, 0, 0');",
    false => "root.style.setProperty('--nofeed-wallpaper-text', '255, 255, 255');",
    null => "root.style.removeProperty('--nofeed-wallpaper-text');",
  };
  return '''
(() => {
  const root = document.documentElement;
  root.style.setProperty('--nofeed-wallpaper-dim', 'rgba(${page.r},${page.g},${page.b},$alpha)');
  $text
  root.setAttribute('data-nofeed-wallpaper', '$key');
})()
''';
}
