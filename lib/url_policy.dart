/// Navigation rules for the WebView, kept in one pure-Dart place so they are
/// easy to unit-test and to update when Instagram changes its web app.
library;

/// What the app should do with a URL the WebView wants to show.
enum UrlAction {
  /// Show it in the WebView.
  allow,

  /// Blocked Instagram page (feed, Reels, Explore): go to the inbox instead.
  redirectToInbox,

  /// A different web domain: open it in the system browser.
  openExternal,

  /// Anything else (dangerous scheme, unparsable URL): do nothing.
  block,
}

class UrlPolicy {
  const UrlPolicy({this.allowSharedReels = true, this.allowStories = true});

  /// Whether a single shared reel (`/reel/<id>`) may be opened.
  final bool allowSharedReels;

  /// Whether stories (`/stories/...`) may be opened.
  final bool allowStories;

  static final Uri inboxUri = Uri.parse('https://www.instagram.com/direct/inbox/');

  static const String _rootDomain = 'instagram.com';

  /// Hosts that serve the main web app. Path rules apply only to these; other
  /// subdomains (e.g. `accountscenter.`, the `l.` link redirector) are allowed
  /// as a whole.
  static const Set<String> _mainHosts = {'instagram.com', 'www.instagram.com', 'm.instagram.com'};

  /// First path segments that are always blocked.
  static const Set<String> _blockedSections = {'reels', 'explore'};

  /// First path segments that are always allowed.
  static const Set<String> _allowedSections = {'direct', 'accounts', 'challenge', 'p'};

  /// Instagram usernames: letters, digits, dot and underscore, max 30 chars.
  static final RegExp _username = RegExp(r'^[a-z0-9._]{1,30}$');

  /// Decides a navigation of the main frame.
  UrlAction decide(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return UrlAction.block;

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return UrlAction.block;

    final host = uri.host.toLowerCase();
    if (host.isEmpty) return UrlAction.block;

    if (!_isInstagramHost(host)) return UrlAction.openExternal;

    // Instagram itself only over HTTPS on the default port.
    if (scheme != 'https' || (uri.hasPort && uri.port != 443)) {
      return UrlAction.block;
    }
    // `https://user@instagram.com` style URLs are never legitimate.
    if (uri.userInfo.isNotEmpty) return UrlAction.block;

    if (!_mainHosts.contains(host)) return UrlAction.allow;
    return _decidePath(uri.pathSegments);
  }

  /// Decides a navigation inside an iframe. Other domains are fine there
  /// (e.g. login verification widgets); only non-web schemes are blocked.
  UrlAction decideSubframe(String url) {
    final scheme = Uri.tryParse(url.trim())?.scheme.toLowerCase();
    return (scheme == 'https' || scheme == 'about') ? UrlAction.allow : UrlAction.block;
  }

  /// Whether [url] is the DM inbox (where Back closes the app).
  static bool isInbox(String? url) {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !_mainHosts.contains(uri.host.toLowerCase())) return false;
    final segments = _segments(uri.pathSegments);
    return segments.length == 2 && segments[0] == 'direct' && segments[1] == 'inbox';
  }

  UrlAction _decidePath(List<String> rawSegments) {
    final segments = _segments(rawSegments);
    if (segments.isEmpty) return UrlAction.redirectToInbox; // home feed

    final section = segments.first;
    if (_blockedSections.contains(section)) return UrlAction.redirectToInbox;
    if (_allowedSections.contains(section)) return UrlAction.allow;
    if (section == 'reel') {
      return allowSharedReels && segments.length > 1 ? UrlAction.allow : UrlAction.redirectToInbox;
    }
    if (section == 'stories') {
      return allowStories ? UrlAction.allow : UrlAction.redirectToInbox;
    }
    // Everything else on the main host is treated as a profile page.
    return _username.hasMatch(section) ? UrlAction.allow : UrlAction.redirectToInbox;
  }

  static bool _isInstagramHost(String host) =>
      host == _rootDomain || host.endsWith('.$_rootDomain');

  /// Lowercased path segments without empty parts (`//`, trailing `/`).
  static List<String> _segments(List<String> raw) => [
    for (final s in raw)
      if (s.isNotEmpty) s.toLowerCase(),
  ];
}
