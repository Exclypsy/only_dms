/// Inbox header (username) behaving like in the Instagram app:
/// - Near the top it fades out with the scroll offset while the search bar
///   slides underneath it on a blurred backdrop.
/// - Further down it fades out while scrolling down and fades back in,
///   following the finger, when scrolling up; when scrolling stops it settles
///   fully shown or hidden.
/// Pure Dart so it can be unit-tested.
library;

import 'dart:math' as math;

enum HeaderState {
  /// Page scrolled to the top: header in its normal place, nothing behind it.
  top,

  /// Header (partly) visible, floating over the scrolled content.
  shown,

  /// Header fully faded out.
  hidden,
}

/// What the page should show right now.
class HeaderFrame {
  const HeaderFrame(this.text, this.backdrop, {required this.floating});

  /// Opacity of the header content (username, buttons): 0 hidden, 1 shown.
  final double text;

  /// Opacity of the blurred backdrop behind the header.
  final double backdrop;

  /// Content is scrolled underneath the header.
  final bool floating;

  HeaderState get state => !floating
      ? HeaderState.top
      : text <= 0
      ? HeaderState.hidden
      : HeaderState.shown;

  @override
  bool operator ==(Object other) =>
      other is HeaderFrame &&
      other.text == text &&
      other.backdrop == backdrop &&
      other.floating == floating;

  @override
  int get hashCode => Object.hash(text, backdrop, floating);

  @override
  String toString() => 'HeaderFrame(text: $text, backdrop: $backdrop, floating: $floating)';
}

class HeaderReveal {
  HeaderReveal({this.fadeZone = 72, this.revealDistance = 64, this.backdropFade = 40});

  /// Near the top, the header fades out over this scroll offset.
  final double fadeZone;

  /// Further down: how far to scroll up for the header to come fully back.
  final double revealDistance;

  /// After the fade zone the blurred backdrop shrinks over this distance.
  final double backdropFade;

  /// Offset up to which the page counts as "at the top" (rubber-band included).
  static const double _atTop = 4;

  double _lastY = 0;
  double _reveal = 1;

  HeaderFrame get frame => _frameFor(_lastY);

  /// Feeds a new scroll offset (called for every scroll event).
  HeaderFrame update(double y) {
    final delta = y - _lastY;
    _lastY = y;
    _reveal = y <= _atTop ? 1 : _clamp(_reveal - delta / revealDistance);
    return _frameFor(y);
  }

  /// Scrolling stopped: past the fade zone, finish showing or hiding.
  HeaderFrame settle() {
    if (_lastY > fadeZone) _reveal = _reveal >= 0.5 ? 1 : 0;
    return frame;
  }

  void reset() {
    _lastY = 0;
    _reveal = 1;
  }

  HeaderFrame _frameFor(double y) {
    final floating = y > _atTop;
    final byOffset = _clamp(1 - y / fadeZone);
    final backdropByOffset = _clamp(1 - (y - fadeZone) / backdropFade);
    return HeaderFrame(
      math.max(_reveal, byOffset),
      floating ? math.max(_reveal, backdropByOffset) : 0,
      floating: floating,
    );
  }

  static double _clamp(double v) => v.clamp(0.0, 1.0);
}
