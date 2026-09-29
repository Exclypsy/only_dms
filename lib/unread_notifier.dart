/// New-message notifications based only on Instagram's own unread counter,
/// which the website shows at the start of the page title, e.g.
/// "(2) Instagram • Messages". The title is read natively (WebView getTitle),
/// never from the page's content. Pure Dart so it can be unit-tested.
library;

final RegExp _counter = RegExp(r'^\s*\((\d{1,4})\+?\)');

/// The unread counter in [title], 0 if the title has none, null if there is no
/// title (page not loaded).
int? parseUnreadCount(String? title) {
  if (title == null || title.trim().isEmpty) return null;
  final match = _counter.firstMatch(title);
  return match == null ? 0 : int.parse(match.group(1)!);
}

/// Decides when to notify: only when the counter goes up (a new unread chat),
/// not for the first reading and not when it goes down (messages were read).
class UnreadTracker {
  int? _last;

  /// Feeds the latest counter; returns true if a notification should be shown.
  bool update(int? count) {
    if (count == null) return false;
    final last = _last;
    _last = count;
    return last != null && count > last;
  }

  void reset() => _last = null;
}

/// Notification text: no names or message content, only the counter.
String unreadNotificationText(int count) => switch (count) {
  1 => 'Máš novú správu na Instagrame.',
  < 5 => 'Máš $count neprečítané konverzácie na Instagrame.',
  _ => 'Máš $count neprečítaných konverzácií na Instagrame.',
};
