/// Instant opening of chats, like the Instagram app that keeps messages on the
/// device: NoFeed keeps a picture (screenshot of the WebView) of each chat you
/// have opened and shows it immediately the next time, until Instagram's page
/// has loaded the live chat (about a second) and replaces it.
///
/// Approved exception to "the app does not store message content" (CLAUDE.md,
/// 30. 9. 2026): pictures only, in the app's private cache folder on this
/// device, excluded from backups, at most [maxChatSnapshots] chats, deleted on
/// logout or when the setting is turned off. Chats are never opened in the
/// background (that would mark them as read), so the first opening of a chat
/// is as fast as Instagram's website.
///
/// Pure Dart (keys and page state), so it can be unit-tested.
library;

/// Kept on disk by the native side (AppDelegate.swift / ChatSnapshots.kt).
const int maxChatSnapshots = 30;

final RegExp _chatId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// File key of the picture for the chat at [url] (`/direct/t/<id>/`), one per
/// theme; null if [url] is not a chat. Only characters safe in a file name.
String? chatSnapshotKey(String? url, {required bool dark}) {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null) return null;
  final segments = [
    for (final s in uri.pathSegments)
      if (s.isNotEmpty) s,
  ];
  if (segments.length < 3 || segments[0] != 'direct' || segments[1] != 't') return null;
  final id = segments[2];
  if (!_chatId.hasMatch(id)) return null;
  return '${id}_${dark ? 'dark' : 'light'}';
}

/// What the chat page looks like right now.
enum ChatPageState {
  /// Messages are not rendered yet.
  loading,

  /// Messages are shown, but scrolled up to older ones.
  scrolledUp,

  /// Messages are shown and the newest one is visible – what a freshly
  /// opened chat looks like, so this is the moment to take the picture.
  atNewest,
}

/// Read-only script for `runJavaScriptReturningResult`: returns only a number
/// (0 loading, 1 scrolled up, 2 at the newest message) from the size and the
/// scroll position of Instagram's message list – no text, names or images.
const String chatPageStateScript = r'''
(() => {
  const list = document.querySelector('[data-pagelet="IGDMessagesList"]');
  if (!list || list.querySelectorAll('*').length < 40) return 0;
  for (const e of [list, ...list.querySelectorAll('div')]) {
    const style = getComputedStyle(e);
    if (style.overflowY !== 'auto' && style.overflowY !== 'scroll') continue;
    if (e.scrollHeight <= e.clientHeight + 4) continue;
    const fromNewest = style.flexDirection === 'column-reverse'
        ? Math.abs(e.scrollTop)
        : e.scrollHeight - e.clientHeight - e.scrollTop;
    return fromNewest < 40 ? 2 : 1;
  }
  return 2;
})()
''';

/// Parses the result of [chatPageStateScript]; anything unexpected is
/// [ChatPageState.loading].
ChatPageState parseChatPageState(Object? result) {
  final value = switch (result) {
    final num n => n.toInt(),
    final String s => num.tryParse(s)?.toInt(),
    _ => null,
  };
  return switch (value) {
    1 => ChatPageState.scrolledUp,
    2 => ChatPageState.atNewest,
    _ => ChatPageState.loading,
  };
}
