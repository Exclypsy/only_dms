import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'app_colors.dart';
import 'chat_keyboard.dart';
import 'chat_snapshot.dart';
import 'cosmetic_css.dart';
import 'error_view.dart';
import 'header_reveal.dart';
import 'media_pick_request.dart';
import 'nav_tabs.dart';
import 'native_bridge.dart';
import 'redirect_guard.dart';
import 'url_policy.dart';

/// One Instagram WebView, used for one tab of the navigation pill (Messages,
/// Profile). Each tab keeps its own page alive, so switching tabs is instant
/// and keeps the scroll position – like the tabs of the Instagram app. All tabs
/// share the login (cookies), which WebViews keep per app.
///
/// Holds everything that belongs to a single page: navigation rules
/// ([UrlPolicy]), redirect-loop protection, error state, cosmetic CSS, the
/// inbox header behaviour, the file picker and camera/microphone requests.
class InstagramTab extends ChangeNotifier {
  InstagramTab({
    required this.homeUri,
    required this._policy,
    required this._pageBackground,
    required this._showMessage,
    this._onPageChanged,
    this._chatSnapshots,
    this._canCaptureChat,
  }) {
    // iOS: play videos inline in the chat instead of forcing full screen.
    final PlatformWebViewControllerCreationParams params =
        WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true)
        : const PlatformWebViewControllerCreationParams();
    controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: _onPermissionRequest,
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: _onNavigationRequest,
              onUrlChange: (change) => _onUrlChange(change.url),
              onProgress: (value) {
                progress = value;
                _notify();
              },
              onPageFinished: _onPageFinished,
              onWebResourceError: _onWebResourceError,
            ),
          );

    controller.setOnScrollPositionChange(_onScroll);

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      // Remote debugging only in debug builds.
      AndroidWebViewController.enableDebugging(kDebugMode);
      platform
        ..setAllowFileAccess(false)
        ..setAllowContentAccess(false)
        ..setGeolocationEnabled(false)
        ..setOnShowFileSelector(_onShowFileSelector);
      _nativeId = platform.webViewIdentifier;
    } else if (platform is WebKitWebViewController) {
      platform
        // Safari Web Inspector only in debug builds.
        ..setInspectable(kDebugMode)
        // iOS has no Back button: swipe from the edge to go back, like Safari.
        ..setAllowsBackForwardNavigationGestures(true)
        // Long-press previews would load links outside UrlPolicy.
        ..setAllowsLinkPreview(false)
        // Rubber-band only pages that really scroll (inbox, profile). Fixed
        // full-screen layouts like a chat keep their header in place; scroll
        // areas inside them still bounce natively.
        ..setOverScrollMode(WebViewOverScrollMode.ifContentScrolls);
      _nativeId = platform.webViewIdentifier;
      NativeBridge.configureWebView(platform.webViewIdentifier);
      // <input type="file"> is handled by WebKit itself (system photo picker,
      // camera needs NSCameraUsageDescription in Info.plist).
    }
  }

  /// How long the picture of a chat takes to fade into the live chat.
  static const Duration chatSnapshotFade = Duration(milliseconds: 180);

  static const _offlineErrors = {
    WebResourceErrorType.hostLookup,
    WebResourceErrorType.connect,
    WebResourceErrorType.timeout,
  };

  late final WebViewController controller;

  /// Start page of this tab; blocked pages redirect here.
  Uri homeUri;

  final UrlPolicy Function() _policy;
  final String Function() _pageBackground;
  final void Function(String message) _showMessage;
  final void Function(InstagramTab tab, String url)? _onPageChanged;

  /// Whether pictures of chats may be kept for instant opening (setting).
  final bool Function()? _chatSnapshots;

  /// Whether this tab is on screen right now (a picture can be taken).
  final bool Function()? _canCaptureChat;

  final RedirectGuard _redirectGuard = RedirectGuard(maxRedirects: 5);
  Timer? _redirectTimer;
  String? _lastUrl;

  final HeaderReveal _headerReveal = HeaderReveal();
  HeaderFrame? _sentHeaderFrame;
  bool _sentHeaderAnimated = false;
  Timer? _headerSettleTimer;

  final ChatKeyboard _chatKeyboard = ChatKeyboard();
  bool _keyboardVisible = false;

  /// Identifier of the native WebView (see NativeBridge).
  int? _nativeId;

  bool _dark = false;

  /// Counts page changes, so work started for an older page stops.
  int _pageSession = 0;

  /// Picture of the chat being opened, shown over the page until Instagram
  /// has loaded the live chat (see chat_snapshot.dart).
  Uint8List? chatSnapshot;

  /// False while [chatSnapshot] fades out.
  bool chatSnapshotVisible = false;

  bool _disposed = false;

  /// URL shown right now (only allowed pages).
  String? currentUrl;
  int progress = 0;
  LoadErrorKind? error;

  /// iPhone inbox: the page reaches under the status bar and scrolls
  /// underneath a blurred band, like the Instagram app. Other pages keep the
  /// safe area, as their fixed headers would end up under the Dynamic Island.
  bool get edgeToEdge => _edgeToEdge(currentUrl);

  bool _edgeToEdge(String? url) =>
      defaultTargetPlatform == TargetPlatform.iOS && UrlPolicy.isInbox(url) && error == null;

  /// Loads [uri], or the tab's home page.
  void load([Uri? uri]) {
    _lastUrl = null;
    controller.loadRequest(uri ?? homeUri);
  }

  void retry() {
    final wasLoop = error == LoadErrorKind.redirectLoop;
    error = null;
    _redirectGuard.reset();
    _notify();
    if (wasLoop) {
      load();
    } else {
      controller.reload();
    }
  }

  /// Background colour for the current theme, so the page never flashes white;
  /// the cosmetic CSS uses it for the blurred header.
  void applyBrightness(Brightness brightness) {
    // Only Android and iOS are supported targets (macOS WebKit throws here).
    final supported =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!supported) return;
    _dark = brightness == Brightness.dark;
    controller.setBackgroundColor(_dark ? darkBackground : lightBackground);
    final url = currentUrl;
    if (url != null) _applyCosmetics(url);
  }

  /// Runs a read-only script (see viewer_account.dart); null on failure.
  Future<Object?> read(String script) async {
    try {
      return await controller.runJavaScriptReturningResult(script);
    } on Object {
      return null;
    }
  }

  /// The keyboard appeared or disappeared while this tab is shown.
  void keyboardChanged({required bool visible}) {
    if (visible == _keyboardVisible) return;
    _keyboardVisible = visible;
    // Instagram focuses the composer by itself when a chat opens; the
    // Instagram app does not open the keyboard until you tap the composer.
    if (visible && _chatKeyboard.keyboardShown()) _dismissKeyboard();
  }

  /// Touches on the page (see [ChatKeyboard]); only used in a chat.
  void pointerDown(Offset position, double height) {
    if (UrlPolicy.isChat(currentUrl)) _chatKeyboard.pointerDown(position, height);
  }

  void pointerMove(Offset position) {
    if (_keyboardVisible && UrlPolicy.isChat(currentUrl) && _chatKeyboard.pointerMove(position)) {
      _dismissKeyboard();
    }
  }

  void pointerUp(Offset position) {
    if (_keyboardVisible && UrlPolicy.isChat(currentUrl) && _chatKeyboard.pointerUp(position)) {
      _dismissKeyboard();
    }
  }

  void _dismissKeyboard() => NativeBridge.dismissKeyboard(webViewId: _nativeId);

  @override
  void dispose() {
    _disposed = true;
    _redirectTimer?.cancel();
    _headerSettleTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final policy = _policy();
    final action = request.isMainFrame
        ? policy.decide(request.url)
        : policy.decideSubframe(request.url);
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
    if (_policy().decide(url) != UrlAction.allow) {
      _requestRedirect();
      return;
    }
    _setCurrentUrl(url);
  }

  void _onPageFinished(String url) {
    if (_policy().decide(url) == UrlAction.allow) _setCurrentUrl(url);
  }

  void _setCurrentUrl(String url) {
    final changed = url != currentUrl;
    if (changed) {
      currentUrl = url;
      _notify();
    }
    _applyCosmetics(url);
    if (!changed) return;
    if (UrlPolicy.isChat(url)) _chatKeyboard.chatOpened();
    _watchChat(url);
    _headerSettleTimer?.cancel();
    _headerReveal.reset();
    _sentHeaderFrame = null;
    _sendHeaderFrame(_headerReveal.frame, animate: false);
    _onPageChanged?.call(this, url);
  }

  /// Instant chats: shows the saved picture of the chat at once, fades it out
  /// when the live chat has loaded, and keeps the picture up to date while
  /// the chat is open and shows its newest messages.
  Future<void> _watchChat(String url) async {
    final session = ++_pageSession;
    bool current() => session == _pageSession && !_disposed;

    final key = (_chatSnapshots?.call() ?? false) ? chatSnapshotKey(url, dark: _dark) : null;
    final id = _nativeId;
    if (key == null || id == null) {
      _dropSnapshot();
      return;
    }

    final picture = await NativeBridge.loadChatSnapshot(key);
    if (!current()) return;
    chatSnapshot = picture;
    chatSnapshotVisible = picture != null;
    _notify();

    // Wait until Instagram has rendered the messages (give up after a while:
    // a stale picture must not hide an error or a very slow page for long).
    final started = DateTime.now();
    var state = ChatPageState.loading;
    while (state == ChatPageState.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!current()) return;
      state = parseChatPageState(await read(chatPageStateScript));
      if (!current()) return;
      if (DateTime.now().difference(started) > const Duration(seconds: 5)) break;
    }
    // Let the freshly rendered chat paint before the picture goes away.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!current()) return;
    await _fadeOutSnapshot(current);
    if (state == ChatPageState.loading) return;

    // Keep the picture fresh: photos finish loading, messages come and go.
    var delay = const Duration(milliseconds: 900);
    while (current()) {
      await Future<void>.delayed(delay);
      if (!current()) return;
      delay = const Duration(seconds: 5);
      if (_keyboardVisible || error != null || !(_canCaptureChat?.call() ?? false)) continue;
      state = parseChatPageState(await read(chatPageStateScript));
      if (!current()) return;
      if (state == ChatPageState.atNewest) {
        await NativeBridge.saveChatSnapshot(webViewId: id, key: key);
      }
    }
  }

  Future<void> _fadeOutSnapshot(bool Function() current) async {
    if (chatSnapshot == null) return;
    chatSnapshotVisible = false;
    _notify();
    await Future<void>.delayed(chatSnapshotFade);
    if (current()) _dropSnapshot();
  }

  void _dropSnapshot() {
    if (chatSnapshot == null) return;
    chatSnapshot = null;
    chatSnapshotVisible = false;
    _notify();
  }

  void _requestRedirect() {
    if (_redirectTimer?.isActive ?? false) return; // one is already scheduled
    switch (_redirectGuard.request()) {
      case RedirectNow():
        load();
      case RedirectLater(:final delay):
        _redirectTimer = Timer(delay, load);
      case RedirectGiveUp():
        error = LoadErrorKind.redirectLoop;
        _notify();
    }
  }

  Future<void> _openExternal(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on PlatformException {
      opened = false;
    }
    if (!opened) _showMessage('Odkaz sa nepodarilo otvoriť v prehliadači.');
  }

  /// `<input type="file">` on Android: system Photo Picker, no storage permission.
  Future<List<String>> _onShowFileSelector(FileSelectorParams params) async {
    if (params.mode == FileSelectorMode.save) return const [];
    if (!UrlPolicy.isInstagramOrigin(await controller.currentUrl())) return const [];
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
    final fromInstagram = UrlPolicy.isInstagramOrigin(await controller.currentUrl());
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
      _showMessage(
        'Bez povolenia kamery alebo mikrofónu to nepôjde. '
        'Povolenie môžeš zmeniť v nastaveniach Androidu.',
      );
    }
  }

  void _onWebResourceError(WebResourceError webError) {
    if (webError.isForMainFrame != true) return;
    error = _offlineErrors.contains(webError.errorType)
        ? LoadErrorKind.offline
        : LoadErrorKind.generic;
    _notify();
  }

  /// Native scroll position of the page → Instagram-style header in the inbox.
  /// The header follows the finger while scrolling and settles (eased) once
  /// the scrolling stops, like in the Instagram app.
  void _onScroll(ScrollPositionChange change) {
    if (!UrlPolicy.isInbox(currentUrl)) return;
    _sendHeaderFrame(_headerReveal.update(change.y), animate: false);
    _headerSettleTimer?.cancel();
    _headerSettleTimer = Timer(
      const Duration(milliseconds: 120),
      () => _sendHeaderFrame(_headerReveal.settle(), animate: true),
    );
  }

  /// Sends a header frame to the page, skipping tiny changes so the WebView is
  /// not flooded with calls while scrolling.
  void _sendHeaderFrame(HeaderFrame frame, {required bool animate}) {
    final last = _sentHeaderFrame;
    if (last != null) {
      if (last == frame && animate == _sentHeaderAnimated) return;
      final tiny =
          (last.text - frame.text).abs() < 0.02 && (last.backdrop - frame.backdrop).abs() < 0.02;
      if (!animate && tiny && last.state == frame.state) return;
    }
    _sentHeaderFrame = frame;
    _sentHeaderAnimated = animate;
    _runCosmetic(headerFrameScript(frame, animate: animate));
  }

  Future<void> _runCosmetic(String script) async {
    try {
      await controller.runJavaScript(script);
    } on Object {
      // Cosmetic only; ignore failures (e.g. page navigated away meanwhile).
    }
  }

  Future<void> _applyCosmetics(String url) => _runCosmetic(
    cosmeticScript(
      isInbox: UrlPolicy.isInbox(url),
      navBar: NavTabs.showBar(url),
      background: _pageBackground(),
      edgeToEdge: _edgeToEdge(url),
    ),
  );
}

/// Shows an [InstagramTab]: the WebView, a thin loading bar and the error
/// screen instead of a blank page.
class InstagramTabView extends StatelessWidget {
  const InstagramTabView({super.key, required this.tab, required this.onOpenSettings});

  final InstagramTab tab;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return ListenableBuilder(
      listenable: tab,
      builder: (context, _) {
        final edgeToEdge = tab.edgeToEdge;
        return SafeArea(
          // iPhone inbox: the page reaches under the status bar (blurred band
          // drawn by the page's CSS). Elsewhere the status bar keeps its safe
          // area. Bottom on iOS: WKWebView handles the home indicator itself.
          top: !edgeToEdge,
          bottom: !isIOS,
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) => Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (e) => tab.pointerDown(e.localPosition, constraints.maxHeight),
                  onPointerMove: (e) => tab.pointerMove(e.localPosition),
                  onPointerUp: (e) => tab.pointerUp(e.localPosition),
                  child: WebViewWidget(controller: tab.controller),
                ),
              ),
              if (tab.chatSnapshot case final picture?)
                Positioned.fill(
                  // Touches go to the page underneath.
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: tab.chatSnapshotVisible ? 1 : 0,
                      duration: InstagramTab.chatSnapshotFade,
                      child: Image.memory(
                        picture,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              if (tab.progress < 100 && tab.error == null)
                Positioned(
                  top: edgeToEdge ? MediaQuery.paddingOf(context).top : 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    value: tab.progress == 0 ? null : tab.progress / 100,
                  ),
                ),
              if (tab.error case final error?)
                Positioned.fill(
                  child: ErrorView(kind: error, onRetry: tab.retry, onOpenSettings: onOpenSettings),
                ),
            ],
          ),
        );
      },
    );
  }
}
