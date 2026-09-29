import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'app_colors.dart';
import 'cosmetic_css.dart';
import 'error_view.dart';
import 'redirect_guard.dart';
import 'url_policy.dart';

class DmScreen extends StatefulWidget {
  const DmScreen({super.key});

  @override
  State<DmScreen> createState() => _DmScreenState();
}

class _DmScreenState extends State<DmScreen> {
  static const _offlineErrors = {
    WebResourceErrorType.hostLookup,
    WebResourceErrorType.connect,
    WebResourceErrorType.timeout,
  };

  final UrlPolicy _policy = const UrlPolicy();
  final RedirectGuard _redirectGuard = RedirectGuard(maxRedirects: 5);
  late final WebViewController _controller;

  Timer? _redirectTimer;
  String? _lastUrl;
  int _progress = 0;
  LoadErrorKind? _error;
  Brightness? _appliedBrightness;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onUrlChange: (change) => _onUrlChange(change.url),
          onProgress: (progress) => setState(() => _progress = progress),
          onPageFinished: (_) => _injectCss(),
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
        ..setGeolocationEnabled(false);
    }

    _controller.loadRequest(UrlPolicy.inboxUri);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Match the WebView background to the system theme so it never flashes white.
    final brightness = MediaQuery.platformBrightnessOf(context);
    if (brightness != _appliedBrightness) {
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
    if (_policy.decide(url) != UrlAction.allow) _requestRedirect();
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

  void _onWebResourceError(WebResourceError error) {
    if (error.isForMainFrame != true) return;
    setState(() {
      _error = _offlineErrors.contains(error.errorType)
          ? LoadErrorKind.offline
          : LoadErrorKind.generic;
    });
  }

  Future<void> _injectCss() async {
    try {
      await _controller.runJavaScript(cosmeticCssScript);
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_progress < 100 && _error == null)
                LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100),
              if (_error case final error?)
                Positioned.fill(
                  child: ErrorView(kind: error, onRetry: _retry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
