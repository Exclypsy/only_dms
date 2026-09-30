/// Loading placeholders: what NoFeed shows over the WebView while Instagram's
/// page is still loading, so the app never shows an empty screen – a skeleton
/// of the page (grey shapes, see page_skeleton.dart) or, for a chat you have
/// opened before, its saved picture (see chat_snapshot.dart).
///
/// To know when to fade the placeholder out, a read-only script returns a
/// single number ("is the page drawn yet?") – no text, names or images
/// (CLAUDE.md §4). Pure Dart so it can be unit-tested.
library;

import 'chat_snapshot.dart';
import 'url_policy.dart';

/// Pages that have a placeholder.
enum PagePlaceholder { inbox, chat, feed }

/// The placeholder for [url], or null for pages without one (login, profile,
/// posts, …).
PagePlaceholder? pagePlaceholderFor(String? url) {
  if (UrlPolicy.isInbox(url)) return PagePlaceholder.inbox;
  if (UrlPolicy.isChat(url)) return PagePlaceholder.chat;
  if (UrlPolicy.isFollowingFeed(url)) return PagePlaceholder.feed;
  return null;
}

/// Read-only script for `runJavaScriptReturningResult`: returns a number > 0
/// once the page of [kind] shows its real content.
String pageReadyScript(PagePlaceholder kind) => switch (kind) {
  // At least one chat row (a row has a timestamp) is in the list.
  PagePlaceholder.inbox => '''(() => document.querySelector('[data-pagelet="IGDInboxThreadListScrollableAreaPagelet"] div[role="button"] abbr') ? 1 : 0)()''',
  // At least one post is in the feed.
  PagePlaceholder.feed => '''(() => document.querySelector('article') ? 1 : 0)()''',
  PagePlaceholder.chat => chatPageStateScript,
};

/// Parses the result of [pageReadyScript]; anything unexpected is "not yet".
bool parsePageReady(Object? result) {
  final value = switch (result) {
    final num n => n,
    final String s => num.tryParse(s),
    _ => null,
  };
  return value != null && value > 0;
}
