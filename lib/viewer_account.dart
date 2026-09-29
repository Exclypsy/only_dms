/// Reads the logged-in account's username and profile-picture URL for the
/// Profile button.
///
/// These are the ONLY non-cosmetic scripts in the app – the exception to
/// CLAUDE.md §4 approved on 29 Sep 2026. They return one string each to the app
/// via `runJavaScriptReturningResult` (no JavaScriptChannel); nothing else is
/// read and nothing is sent anywhere. If Instagram changes its markup, nothing
/// is found and the app falls back (asks for the name / shows a person icon).
library;

import 'dart:convert';

import 'nav_tabs.dart';

/// Username: the text of the account-switcher heading in the inbox header
/// (`[role=navigation] › [role=button] › h2`).
const String readViewerUsernameScript = '''
(function () {
  var heading = document.querySelector('[role="navigation"] [role="button"] h2');
  return heading ? String(heading.textContent || '').trim().slice(0, 64) : '';
})();
''';

/// Words that can never be the user's own profile (page names, not people).
const Set<String> _reserved = {
  'direct',
  'inbox',
  'messages',
  'chats',
  'explore',
  'reels',
  'reel',
  'stories',
  'accounts',
  'p',
  'instagram',
};

/// Turns the script result into a validated username, or null.
/// Android returns strings JSON-encoded (`"name"`), iOS returns them as is.
String? parseViewerUsername(Object? result) {
  if (result is! String) return null;
  var text = result.trim();
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    try {
      text = jsonDecode(text) as String;
    } on FormatException {
      return null;
    }
  }
  final username = NavTabs.normalizeUsername(text);
  if (username == null || _reserved.contains(username)) return null;
  return username;
}

/// Profile picture of the logged-in account ([username] must already be
/// validated). Preferred source: the image inside Instagram's own link to the
/// user's profile (`a[href="/<username>/"] img`, present on profile and post
/// pages, language independent). In the inbox: the user's own tile, which is
/// always the first one in the notes row.
String readViewerAvatarScript(String username, {required bool inbox}) {
  final safeName = NavTabs.normalizeUsername(username) ?? '';
  return '''
(function (user, inbox) {
  var img = user ? document.querySelector('a[href="/' + user + '/"] img') : null;
  if (!img && inbox) {
    // The notes row is the only list on the inbox page; its first picture is
    // the user's own "Your note" tile (the first item is an empty spacer).
    img = document.querySelector('ul > li span[role="link"] img');
  }
  return img ? String(img.currentSrc || img.getAttribute('src') || '').slice(0, 2048) : '';
})(${jsonEncode(safeName)}, ${inbox ? 'true' : 'false'});
''';
}

/// Accepts only an HTTPS image URL from Instagram's / Facebook's CDN.
Uri? parseAvatarUrl(Object? result) {
  if (result is! String) return null;
  var text = result.trim();
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    try {
      text = jsonDecode(text) as String;
    } on FormatException {
      return null;
    }
  }
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) return null;
  if (uri.hasPort && uri.port != 443) return null;
  final host = uri.host.toLowerCase();
  const cdns = ['cdninstagram.com', 'fbcdn.net'];
  final fromCdn = cdns.any((cdn) => host == cdn || host.endsWith('.$cdn'));
  return fromCdn ? uri : null;
}
