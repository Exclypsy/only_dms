import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'instagram_tab.dart';
import 'nav_bar.dart';
import 'nav_tabs.dart';
import 'native_bridge.dart';
import 'settings.dart';
import 'settings_screen.dart';
import 'unread_notifier.dart';
import 'url_policy.dart';
import 'username_dialog.dart';
import 'viewer_account.dart';

/// App shell: two Instagram tabs (Messages, Profile) that stay alive, the
/// floating navigation pill and the settings.
class DmScreen extends StatefulWidget {
  const DmScreen({super.key, required this.initialSettings, required this.store});

  final AppSettings initialSettings;
  final SettingsStore store;

  @override
  State<DmScreen> createState() => _DmScreenState();
}

class _DmScreenState extends State<DmScreen> with WidgetsBindingObserver {
  late AppSettings _settings = widget.initialSettings;
  late UrlPolicy _policy = _settings.urlPolicy;

  late final InstagramTab _messages;

  /// Created (and preloaded in the background) once the username is known.
  InstagramTab? _profile;
  NavTab _activeTab = NavTab.messages;

  /// Profile picture of the logged-in account (memory only, see viewer_account.dart).
  Uri? _avatarUrl;
  Brightness? _appliedBrightness;

  /// New-message notifications (see unread_notifier.dart).
  final UnreadTracker _unread = UnreadTracker();
  Timer? _unreadTimer;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  InstagramTab get _active => _activeTab == NavTab.profile ? (_profile ?? _messages) : _messages;

  @override
  void initState() {
    super.initState();
    _messages = _createTab(UrlPolicy.inboxUri)..load();
    WidgetsBinding.instance.addObserver(this);
    _applyNotifications();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _lifecycle = state;

  /// Starts or stops watching Instagram's unread counter (and, on Android, the
  /// background service) according to the settings.
  void _applyNotifications() {
    _unreadTimer?.cancel();
    _unread.reset();
    final enabled = _settings.notificationsEnabled;
    NativeBridge.setKeepAlive(enabled);
    if (enabled) {
      _unreadTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkUnread());
    }
  }

  /// Reads the counter from the page title (natively, not from the page's
  /// content) and notifies when it goes up while you are not looking at the
  /// inbox. The notification has no names or message content.
  Future<void> _checkUnread() async {
    String? title;
    try {
      title = await _messages.controller.getTitle();
    } on Object {
      title = null;
    }
    final count = parseUnreadCount(title);
    if (!_unread.update(count) || count == null) return;
    final lookingAtInbox =
        _lifecycle == AppLifecycleState.resumed &&
        _activeTab == NavTab.messages &&
        UrlPolicy.isInbox(_messages.currentUrl);
    if (!lookingAtInbox) {
      await NativeBridge.showNotification(title: 'NoFeed', body: unreadNotificationText(count));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Match the WebViews to the system theme so they never flash white.
    final brightness = MediaQuery.platformBrightnessOf(context);
    if (brightness != _appliedBrightness) {
      _appliedBrightness = brightness;
      for (final tab in [_messages, ?_profile]) {
        tab.applyBrightness(brightness);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadTimer?.cancel();
    _messages.dispose();
    _profile?.dispose();
    super.dispose();
  }

  InstagramTab _createTab(Uri home) {
    final tab = InstagramTab(
      homeUri: home,
      policy: () => _policy,
      pageBackground: () => _cssColor(Theme.of(context).scaffoldBackgroundColor),
      showMessage: _showMessage,
      onPageChanged: _onPageChanged,
    )..addListener(_onTabChanged);
    final brightness = _appliedBrightness;
    if (brightness != null) tab.applyBrightness(brightness);
    return tab;
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  static String _cssColor(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onPageChanged(InstagramTab tab, String url) {
    if (tab == _messages && UrlPolicy.isInbox(url)) {
      _detectAccount();
    } else if (NavTabs.activeTab(url, username: _settings.username) == NavTab.profile) {
      // The own profile page has the most reliable picture source.
      _detectAvatar(tab, inbox: false);
    }
  }

  Future<void> _detectAccount() async {
    final username = await _detectUsername();
    if (username != null) {
      _ensureProfileTab(username);
      await _detectAvatar(_messages, inbox: true);
    }
    await _maybeShowSettingsHint();
  }

  /// Reads the logged-in username from the inbox header (see
  /// viewer_account.dart). The header renders a moment after the page, so a
  /// few attempts are made while the inbox is shown. Returns null if not found.
  Future<String?> _detectUsername({int attempts = 5}) async {
    for (var i = 0; i < attempts; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted || !UrlPolicy.isInbox(_messages.currentUrl)) return null;
      final username = parseViewerUsername(await _messages.read(readViewerUsernameScript));
      if (username != null) {
        if (username != _settings.username) {
          await _updateSettings(_settings.copyWith(username: username));
        }
        return username;
      }
    }
    return null;
  }

  /// Reads the profile-picture URL (see viewer_account.dart) while the inbox or
  /// the own profile is shown in [tab]. Keeps the old picture if nothing is found.
  Future<void> _detectAvatar(InstagramTab tab, {required bool inbox, int attempts = 4}) async {
    final username = _settings.username;
    if (username == null) return;
    for (var i = 0; i < attempts; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 1500));
      final stillThere = inbox
          ? UrlPolicy.isInbox(tab.currentUrl)
          : NavTabs.activeTab(tab.currentUrl, username: username) == NavTab.profile;
      if (!mounted || !stillThere) return;
      final url = parseAvatarUrl(await tab.read(readViewerAvatarScript(username, inbox: inbox)));
      if (url != null) {
        if (mounted && url != _avatarUrl) setState(() => _avatarUrl = url);
        return;
      }
    }
  }

  /// Creates the Profile tab and loads it in the background, so the first
  /// switch to it is already instant. Follows a change of the account.
  void _ensureProfileTab(String username) {
    final home = NavTabs.profileUri(username);
    final profile = _profile;
    if (profile == null) {
      setState(() => _profile = _createTab(home)..load());
    } else if (profile.homeUri != home) {
      profile
        ..homeUri = home
        ..load();
    }
  }

  /// One-time tip: settings are opened with a long-press on Profile.
  Future<void> _maybeShowSettingsHint() async {
    if (await widget.store.settingsHintShown() || !mounted) return;
    await widget.store.markSettingsHintShown();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tip: podrž ikonu profilu dole a otvoria sa Nastavenia NoFeed.'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: 'Otvoriť', onPressed: _openSettings),
      ),
    );
  }

  Future<void> _updateSettings(AppSettings settings) async {
    final secureChanged = settings.hideInRecents != _settings.hideInRecents;
    final notificationsChanged = settings.notificationsEnabled != _settings.notificationsEnabled;
    setState(() {
      _settings = settings;
      _policy = settings.urlPolicy;
    });
    if (secureChanged) await NativeBridge.setSecure(settings.hideInRecents);
    if (notificationsChanged) _applyNotifications();
    await widget.store.save(settings);
  }

  /// Log out locally: delete cookies, cache and web storage (shared by all
  /// tabs), drop the Profile tab and show the login page.
  Future<void> _logoutAndClearData() async {
    await WebViewCookieManager().clearCookies();
    await _messages.controller.clearCache();
    await _messages.controller.clearLocalStorage();
    final profile = _profile;
    setState(() {
      _profile = null;
      _activeTab = NavTab.messages;
      // Another account may log in next.
      _avatarUrl = null;
    });
    profile
      ?..removeListener(_onTabChanged)
      ..dispose();
    await _updateSettings(_settings.copyWith(clearUsername: true, notificationsEnabled: false));
    _messages.load(UrlPolicy.loginUri);
  }

  Future<void> _onNavTap(NavTab tab) async {
    switch (tab) {
      case NavTab.messages:
        // Tapping the active tab again goes back to its start, like in the app.
        if (_activeTab == NavTab.messages && !UrlPolicy.isInbox(_messages.currentUrl)) {
          _messages.load();
        }
        setState(() => _activeTab = NavTab.messages);
      case NavTab.profile:
        // Normally already detected in the inbox; ask only as a fallback
        // (e.g. if Instagram changed its page and the name can't be found).
        var username = _settings.username ?? await _detectUsername(attempts: 1);
        if (username == null) {
          if (!mounted) return;
          username = await showUsernameDialog(context);
          if (username == null) return;
          await _updateSettings(_settings.copyWith(username: username));
        }
        final wasActive = _activeTab == NavTab.profile && _profile != null;
        _ensureProfileTab(username);
        final profile = _profile!;
        if (wasActive &&
            NavTabs.activeTab(profile.currentUrl, username: username) != NavTab.profile) {
          profile.load();
        }
        setState(() => _activeTab = NavTab.profile);
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          initial: _settings,
          onChanged: _updateSettings,
          onLogout: _logoutAndClearData,
          onRequestNotifications: NativeBridge.requestNotifications,
          onTestNotification: () => NativeBridge.showNotification(
            title: 'NoFeed',
            body: 'Takto bude vyzerať oznámenie o novej správe.',
          ),
        ),
      ),
    );
  }

  /// Back (Android): one step back inside the tab; from the Profile tab's start
  /// back to Messages; in the inbox (or with nowhere to go back to) close the
  /// app. Going back onto a blocked page just triggers a redirect.
  Future<void> _handleBack() async {
    final tab = _active;
    if (tab.error != null && tab == _messages) {
      await SystemNavigator.pop();
      return;
    }
    final url = await tab.controller.currentUrl();
    final canGoBack = await tab.controller.canGoBack();
    if (tab == _messages) {
      if (UrlPolicy.isInbox(url) || !canGoBack) {
        await SystemNavigator.pop();
      } else {
        await tab.controller.goBack();
      }
    } else if (canGoBack && tab.error == null) {
      await tab.controller.goBack();
    } else {
      setState(() => _activeTab = NavTab.messages);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final active = _active;
    final profile = _profile;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      // Status-bar icons must contrast with the page, as there is no toolbar.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value:
            (Theme.of(context).brightness == Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          // iOS: WKWebView handles the keyboard itself (like Safari). Resizing
          // the WebView from Flutter as well would move the page twice and
          // break the chat composer. Android's WebView needs the resize.
          resizeToAvoidBottomInset: !isIOS,
          // No toolbar, like the Instagram app: the page starts right under the
          // status bar. Settings: long-press Profile in the navigation pill.
          body: Stack(
            children: [
              // Both tabs stay alive; only the active one is shown.
              IndexedStack(
                index: identical(active, profile) ? 1 : 0,
                sizing: StackFit.expand,
                children: [
                  InstagramTabView(tab: _messages, onOpenSettings: _openSettings),
                  if (profile != null)
                    InstagramTabView(tab: profile, onOpenSettings: _openSettings),
                ],
              ),
              // Floating Instagram-style pill: Messages and Profile only.
              // Hidden inside a chat, on login pages and while typing.
              if (NavTabs.showBar(active.currentUrl) &&
                  active.error == null &&
                  MediaQuery.viewInsetsOf(context).bottom == 0)
                Positioned(
                  left: 0,
                  right: 0,
                  // 25 pt above the screen edge on iPhone, as in the Instagram app.
                  bottom: isIOS
                      ? math.max(MediaQuery.paddingOf(context).bottom - 9, 12)
                      : MediaQuery.paddingOf(context).bottom + 12,
                  child: Center(
                    child: NoFeedNavBar(
                      active: _activeTab,
                      avatarUrl: _avatarUrl,
                      onTap: _onNavTap,
                      onLongPressProfile: _openSettings,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
