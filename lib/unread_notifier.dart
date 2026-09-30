/// New-message notifications with the sender and the text, like the Instagram
/// app. Instagram's inbox list shows unread chats in bold; NoFeed reads the
/// name and the preview text of those rows only (never an opened
/// conversation), shows them in a local notification and keeps them only in
/// memory. Approved exception to "JS does not read messages", see CLAUDE.md.
/// Pure Dart so it can be unit-tested.
library;

import 'dart:convert';

/// An unread chat in the inbox list: who wrote and the preview of the message.
class UnreadChat {
  const UnreadChat(this.name, this.text);

  final String name;
  final String text;

  @override
  bool operator ==(Object other) => other is UnreadChat && other.name == name && other.text == text;

  @override
  int get hashCode => Object.hash(name, text);

  @override
  String toString() => 'UnreadChat($name, $text)';
}

/// Read-only script for `runJavaScriptReturningResult` (no JavaScriptChannel).
/// Returns JSON `{"rows": <number of chat rows>, "unread": [[name, text], …]}`
/// or null if the inbox list is not on the page.
///
/// A chat row is a `div[role="button"]` with a timestamp (`abbr`); its first
/// two text leaves are the name and the preview. Unread rows have a bold name.
const String readUnreadChatsScript = r'''
(() => {
  const root = document.querySelector('[data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]');
  if (!root) return null;
  let rows = 0;
  const unread = [];
  for (const row of root.querySelectorAll('div[role="button"]')) {
    if (!row.querySelector('abbr') || row.querySelector('div[role="button"]')) continue;
    rows++;
    if (unread.length >= 10) continue;
    const leaves = [];
    for (const span of row.querySelectorAll('span')) {
      if (span.children.length === 0 && span.textContent.trim()) leaves.push(span);
      if (leaves.length === 2) break;
    }
    if (leaves.length < 2) continue;
    if (parseInt(getComputedStyle(leaves[0]).fontWeight, 10) < 600) continue;
    unread.push([leaves[0].textContent.slice(0, 80), leaves[1].textContent.slice(0, 300)]);
  }
  return JSON.stringify({rows: rows, unread: unread});
})()
''';

const int _maxName = 60;
const int _maxText = 200;

final RegExp _whitespace = RegExp(r'\s+');
final RegExp _control = RegExp(r'[\u0000-\u001F\u007F\u200E\u200F\u202A-\u202E\u2066-\u2069]');

String _clean(String value, int max) {
  final text = value.replaceAll(_control, ' ').replaceAll(_whitespace, ' ').trim();
  if (text.runes.length <= max) return text;
  return '${String.fromCharCodes(text.runes.take(max - 1))}…';
}

/// Parses the result of [readUnreadChatsScript]. Null means "unknown" (no
/// list on the page, the list is still empty while loading, or an unexpected
/// result), so the caller keeps what it knew before.
List<UnreadChat>? parseUnreadChats(Object? result) {
  Object? value = result;
  // Android returns a JSON-encoded string, iOS the string itself.
  for (var i = 0; i < 2 && value is String; i++) {
    try {
      value = jsonDecode(value);
    } on FormatException {
      return null;
    }
  }
  if (value is! Map) return null;
  final rows = value['rows'];
  final unread = value['unread'];
  if (rows is! num || rows <= 0 || unread is! List) return null;
  final chats = <UnreadChat>[];
  for (final item in unread) {
    if (item is! List || item.length != 2) continue;
    final name = item[0], text = item[1];
    if (name is! String || text is! String) continue;
    final cleanName = _clean(name, _maxName);
    final cleanText = _clean(text, _maxText);
    if (cleanName.isEmpty || cleanText.isEmpty) continue;
    chats.add(UnreadChat(cleanName, cleanText));
  }
  return chats;
}

/// Decides which unread chats deserve a notification: those that are new or
/// whose preview changed since the last reading. Nothing for the first
/// reading (chats that were already unread when notifications were turned on).
class UnreadChatTracker {
  Map<String, String>? _last;

  /// Feeds the latest reading; returns the chats to notify about.
  List<UnreadChat> update(List<UnreadChat>? chats) {
    if (chats == null) return const [];
    final last = _last;
    _last = {for (final chat in chats) chat.name: chat.text};
    if (last == null) return const [];
    return [
      for (final chat in chats)
        if (last[chat.name] != chat.text) chat,
    ];
  }

  void reset() => _last = null;
}
