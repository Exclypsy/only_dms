import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'app_colors.dart';
import 'cosmetic_css.dart';
import 'error_view.dart';
import 'media_pick_request.dart';
import 'nav_bar.dart';
import 'nav_tabs.dart';
import 'native_bridge.dart';
import 'redirect_guard.dart';
import 'settings.dart';
import 'settings_screen.dart';
import 'url_policy.dart';
import 'username_dialog.dart';
import 'viewer_account.dart';

class DmScreen extends StatefulWidget {
  const DmScreen({super.key, required this.initialSettings, required this.store});

  final AppSettings initialSettings;
  final SettingsStore store;

  @override
  State<DmScreen> createState() => _DmScreenState();
}

class _DmScreenState extends State<DmScreen> {
  static const _offlineErrors = {
    WebResourceErrorType.hostLookup,
    WebResourceErrorType.connect,
    WebResourceErrorType.timeout,
  };

  late AppSettings _settings = widget.initialSettings;
  late UrlPolicy _policy = _settings.urlPolicy;
  final RedirectGuard _redirectGuard = RedirectGuard(maxRedirects: 5);
  late final WebViewController _controller;

  Timer? _redirectTimer;
  String? _lastUrl;

  /// URL shown right now, for the bottom bar and the cosmetic CSS.
  String? _currentUrl;
  int _progress = 0;
  LoadErrorKind? _error;
  Brightness? _appliedBrightness;

  @override
  void initState() {
    super.initState();
    // iOS: play videos inline in the chat instead of forcing full screen.
    final PlatformWebViewControllerCreationParams params =
        WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true)
        : const PlatformWebViewControllerCreationParams();
    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: _onPermissionRequest,
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: _onNavigationRequest,
              onUrlChange: (change) => _onUrlChange(change.url),
              onProgress: (progress) => setState(() => _progress = progress),
              onPageFinished: _onPageFinished,
              onWebResourceError: _onWebResourceError,
            ),
          );

    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      // Remote debugging only in debug builds.
      AndroidWebViewController.enableDebugging(kDebugMode);
      platform
        ..setAllowFileAccess(false)
        ..setAllowContentAccess(false)
        ..setGeolocationEnabled(false)
        ..setOnShowFileSelector(_onShowFileSelector);
    } else if (platform is WebKitWebViewController) {
      platform
        // Safari Web Inspector only in debug builds.
        ..setInspectable(kDebugMode)
        // iOS has no Back button: swipe from the edge to go back, like Safari.
        ..setAllowsBackForwardNavigationGestures(true)
        // Long-press previews would load links outside UrlPolicy.
        ..setAllowsLinkPreview(false);
      // <input type="file"> is handled by WebKit itself (system photo picker,
      // camera needs NSCameraUsageDescription in Info.plist).
    }

    _controller.loadRequest(UrlPolicy.inboxUri);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Match the WebView background to the system theme so it never flashes white.
    // Only Android and iOS are supported targets (macOS WebKit throws here).
    final brightness = MediaQuery.platformBrightnessOf(context);
    final supported =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (supported && brightness != _appliedBrightness) {
      _appliedBrightness = brightness;
      _controller.setBackgroundColor(
        brightness == Brightness.dark ? darkBackground : lightBackground,
      );
    }
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final action = request.isMainFrame
        ? _policy.decide(request.url)
        : _policy.decideSubframe(request.url);
    switch (action) {
      case UrlAction.allow:
        return NavigationDecision.navigate;
      case UrlAction.redirectToInbox:
        _requestRedirect();
      case UrlAction.openExternal:
        _openExternal(request.url);
      case UrlAction.block:
        break;
    }
    return NavigationDecision.prevent;
  }

  /// Instagram is a single-page app: moving between pages often only changes
  /// the URL via `history.pushState`, which never reaches [_onNavigationRequest].
  void _onUrlChange(String? url) {
    if (url == null || url == _lastUrl) return;
    _lastUrl = url;
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    // Non-web schemes are already blocked in _onNavigationRequest.
    if (scheme != 'https' && scheme != 'http') return;
    if (_policy.decide(url) != UrlAction.allow) {
      _requestRedirect();
      return;
    }
    _setCurrentUrl(url);
  }

  void _onPageFinished(String url) {
    if (_policy.decide(url) == UrlAction.allow) _setCurrentUrl(url);
  }

  void _setCurrentUrl(String url) {
    final changed = url != _currentUrl;
    if (changed) setState(() => _currentUrl = url);
    _applyCosmetics(url);
    if (changed && UrlPolicy.isInbox(url)) _detectUsername();
  }

  /// Reads the logged-in username from the inbox header (see
  /// viewer_username.dart). The header renders a moment after the page, so a
  /// few attempts are made while the inbox is shown. Returns null if not found.
  Future<String?> _detectUsername({int attempts = 5}) async {
    for (var i = 0; i < attempts; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted || !UrlPolicy.isInbox(_currentUrl)) return null;
      Object? result;
      try {
        result = await _controller.runJavaScriptReturningResult(readViewerUsernameScript);
      } on Object {
        result = null;
      }
      final username = parseViewerUsername(result);
      if (username != null) {
        if (username != _settings.username) {
          await _updateSettings(_settings.copyWith(username: username));
        }
        return username;
      }
    }
    return null;
  }

  void _requestRedirect() {
    if (_redirectTimer?.isActive ?? false) return; // one is already scheduled
    switch (_redirectGuard.request()) {
      case RedirectNow():
        _loadInbox();
      case RedirectLater(:final delay):
        _redirectTimer = Timer(delay, _loadInbox);
      case RedirectGiveUp():
        setState(() => _error = LoadErrorKind.redirectLoop);
    }
  }

  void _loadInbox() {
    _lastUrl = null;
    _controller.loadRequest(UrlPolicy.inboxUri);
  }

  Future<void> _openExternal(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on PlatformException {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Odkaz sa nepodarilo otvoriť v prehliadači.')));
    }
  }

  /// `<input type="file">` on Android: system Photo Picker, no storage permission.
  Future<List<String>> _onShowFileSelector(FileSelectorParams params) async {
    if (params.mode == FileSelectorMode.save) return const [];
    if (!UrlPolicy.isInstagramOrigin(await _controller.currentUrl())) return const [];
    final request = MediaPickRequest.fromAcceptTypes(
      params.acceptTypes,
      multiple: params.mode == FileSelectorMode.openMultiple,
    );
    return NativeBridge.pickMedia(request);
  }

  /// Camera/microphone: only for instagram.com and only after the user confirms
  /// it in a system dialog. Everything else is denied.
  /// The plugins do not expose the requesting origin, so the main-frame URL is
  /// checked; UrlPolicy guarantees the main frame is always Instagram, and
  /// browsers block cross-origin iframes unless the page delegates access.
  Future<void> _onPermissionRequest(WebViewPermissionRequest request) async {
    const supported = {
      WebViewPermissionResourceType.camera,
      WebViewPermissionResourceType.microphone,
    };
    final types = request.types;
    final fromInstagram = UrlPolicy.isInstagramOrigin(await _controller.currentUrl());
    if (!fromInstagram || types.isEmpty || !supported.containsAll(types)) {
      await request.deny();
      return;
    }
    // iOS: let WebKit ask ("instagram.com wants to use your microphone");
    // iOS itself shows its permission dialog on first use.
    final platformRequest = request.platform;
    if (platformRequest is WebKitWebViewPermissionRequest) {
      await platformRequest.prompt();
      return;
    }
    final granted = await NativeBridge.requestMediaPermissions(
      camera: types.contains(WebViewPermissionResourceType.camera),
      microphone: types.contains(WebViewPermissionResourceType.microphone),
    );
    if (granted) {
      await request.grant();
    } else {
      await request.deny();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bez povolenia kamery alebo mikrofónu to nepôjde. '
              'Povolenie môžeš zmeniť v nastaveniach Androidu.',
            ),
          ),
        );
      }
    }
  }

  void _onWebResourceError(WebResourceError error) {
    if (error.isForMainFrame != true) return;
    setState(() {
      _error = _offlineErrors.contains(error.errorType)
          ? LoadErrorKind.offline
          : LoadErrorKind.generic;
    });
  }

  Future<void> _applyCosmetics(String url) async {
    try {
      await _controller.runJavaScript(
        cosmeticScript(isInbox: UrlPolicy.isInbox(url), navBar: NavTabs.showBar(url)),
      );
    } on Object {
      // Cosmetic only; ignore failures (e.g. page navigated away meanwhile).
    }
  }

  void _retry() {
    final wasLoop = _error == LoadErrorKind.redirectLoop;
    setState(() => _error = null);
    _redirectGuard.reset();
    if (wasLoop) {
      _loadInbox();
    } else {
      _controller.reload();
    }
  }

  Future<void> _updateSettings(AppSettings settings) async {
    final secureChanged = settings.hideInRecents != _settings.hideInRecents;
    setState(() {
      _settings = settings;
      _policy = settings.urlPolicy;
    });
    if (secureChanged) await NativeBridge.setSecure(settings.hideInRecents);
    await widget.store.save(settings);
  }

  /// Log out locally: delete cookies, cache and web storage, then show login.
  Future<void> _logoutAndClearData() async {
    _redirectTimer?.cancel();
    await WebViewCookieManager().clearCookies();
    await _controller.clearCache();
    await _controller.clearLocalStorage();
    _redirectGuard.reset();
    _lastUrl = null;
    if (mounted) setState(() => _error = null);
    // Another account may log in next.
    await _updateSettings(_settings.copyWith(clearUsername: true));
    await _controller.loadRequest(UrlPolicy.loginUri);
  }

  Future<void> _onNavTap(NavTab tab) async {
    switch (tab) {
      case NavTab.messages:
        if (!UrlPolicy.isInbox(_currentUrl)) _loadInbox();
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
        await _controller.loadRequest(NavTabs.profileUri(username));
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          initial: _settings,
          onChanged: _updateSettings,
          onLogout: _logoutAndClearData,
        ),
      ),
    );
  }

  /// Back: in the inbox (or with nowhere to go back to) close the app,
  /// otherwise go one step back. Going back onto a blocked page just triggers
  /// a redirect to the inbox, from where the next Back closes the app.
  Future<void> _handleBack() async {
    if (_error != null) {
      await SystemNavigator.pop();
      return;
    }
    final url = await _controller.currentUrl();
    if (UrlPolicy.isInbox(url) || !await _controller.canGoBack()) {
      await SystemNavigator.pop();
    } else {
      await _controller.goBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 44,
          title: const Text('NoFeed'),
          titleTextStyle: Theme.of(context).textTheme.titleMedium,
          actions: [
            IconButton(
              tooltip: 'Nastavenia',
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          // iOS: WKWebView handles the home-indicator area itself and fills it
          // with the page background, so no empty strip is left at the bottom.
          bottom: !isIOS,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_progress < 100 && _error == null)
                LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100),
              if (_error case final error?)
                Positioned.fill(
                  child: ErrorView(kind: error, onRetry: _retry),
                ),
              // Floating Instagram-style pill: Messages and Profile only.
              // Hidden inside a chat, on login pages and while typing.
              if (NavTabs.showBar(_currentUrl) &&
                  _error == null &&
                  MediaQuery.viewInsetsOf(context).bottom == 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: isIOS ? math.max(MediaQuery.paddingOf(context).bottom - 12, 12) : 12,
                  child: Center(
                    child: NoFeedNavBar(
                      active: NavTabs.activeTab(_currentUrl, username: _settings.username),
                      onTap: _onNavTap,
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
