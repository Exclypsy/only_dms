/// Bottom navigation of NoFeed: only Messages and Profile.
/// Pure Dart so it can be unit-tested.
library;

enum NavTab { messages, profile }

class NavTabs {
  const NavTabs._();

  static const Set<String> _hosts = {'instagram.com', 'www.instagram.com', 'm.instagram.com'};
  static final RegExp _username = RegExp(r'^[a-z0-9._]{1,30}$');

  /// Cleans up what the user typed (`@Name ` → `name`); null if invalid.
  static String? normalizeUsername(String input) {
    var name = input.trim().toLowerCase();
    if (name.startsWith('@')) name = name.substring(1);
    return _username.hasMatch(name) ? name : null;
  }

  static Uri profileUri(String username) => Uri.https('www.instagram.com', '/$username/');

  /// Which tab is active for [url] (null = none, e.g. a post or a story).
  static NavTab? activeTab(String? url, {String? username}) {
    final segments = _segments(url);
    if (segments == null || segments.isEmpty) return null;
    if (segments.first == 'direct') return NavTab.messages;
    if (username != null && segments.first == username) return NavTab.profile;
    return null;
  }

  /// The bar is hidden inside a chat (like the Instagram app) and on login /
  /// verification pages, where there is nothing to navigate to yet.
  static bool showBar(String? url) {
    final segments = _segments(url);
    if (segments == null) return false;
    if (segments.isEmpty) return true;
    return switch (segments.first) {
      'direct' => segments.length < 2 || segments[1] != 't',
      'accounts' || 'challenge' => false,
      _ => true,
    };
  }

  static List<String>? _segments(String? url) {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !_hosts.contains(uri.host.toLowerCase())) return null;
    return [
      for (final s in uri.pathSegments)
        if (s.isNotEmpty) s.toLowerCase(),
    ];
  }
}
