/// Keyboard in a chat, like in the Instagram app: it does not open by itself
/// when a chat is opened, and a tap into the conversation or a drag down over
/// it closes it. The composer at the bottom is left alone.
/// Pure Dart (only touch positions and times), so it can be unit-tested.
library;

import 'dart:ui' show Offset;

class ChatKeyboard {
  ChatKeyboard({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Height of the composer area at the bottom of the page (logical px).
  static const double composerZone = 96;

  /// Instagram focuses the composer about a second after a chat opens.
  static const Duration autoFocusWindow = Duration(seconds: 3);

  static const double _tapSlop = 12;
  static const double _dragDistance = 40;
  static const Duration _tapTimeout = Duration(milliseconds: 400);

  final DateTime Function() _clock;

  DateTime? _chatOpenedAt;
  bool _composerTouched = false;

  Offset? _down;
  DateTime? _downAt;
  bool _downOnConversation = false;

  /// A chat was opened (its URL was shown).
  void chatOpened() {
    _chatOpenedAt = _clock();
    _composerTouched = false;
  }

  /// The keyboard appeared. True if it was the page focusing the composer by
  /// itself right after the chat opened, i.e. it should be closed again.
  bool keyboardShown() {
    final openedAt = _chatOpenedAt;
    _chatOpenedAt = null;
    if (openedAt == null || _composerTouched) return false;
    return _clock().difference(openedAt) <= autoFocusWindow;
  }

  /// A finger touched the page at [position] in a view of [height].
  void pointerDown(Offset position, double height) {
    _down = position;
    _downAt = _clock();
    _downOnConversation = position.dy < height - composerZone;
    if (!_downOnConversation) _composerTouched = true;
  }

  /// The finger moved; true if it dragged down over the conversation far
  /// enough to close the keyboard.
  bool pointerMove(Offset position) {
    final down = _down;
    if (down == null || !_downOnConversation) return false;
    if (position.dy - down.dy < _dragDistance) return false;
    _down = null; // once per gesture
    return true;
  }

  /// The finger lifted; true if it was a tap on the conversation.
  bool pointerUp(Offset position) {
    final down = _down;
    final downAt = _downAt;
    _down = null;
    if (down == null || downAt == null || !_downOnConversation) return false;
    final short = _clock().difference(downAt) <= _tapTimeout;
    return short && (position - down).distance <= _tapSlop;
  }
}
