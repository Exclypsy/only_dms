/// Protects against redirect loops (e.g. if Instagram starts sending the
/// inbox back to a blocked page). Pure Dart so it can be unit-tested.
library;

sealed class RedirectVerdict {
  const RedirectVerdict();
}

/// Redirect right now.
class RedirectNow extends RedirectVerdict {
  const RedirectNow();
}

/// Redirect after [delay] (rate limit: at most one redirect per interval).
class RedirectLater extends RedirectVerdict {
  const RedirectLater(this.delay);
  final Duration delay;
}

/// Too many redirects in a short time: stop and show an error instead.
class RedirectGiveUp extends RedirectVerdict {
  const RedirectGiveUp();
}

class RedirectGuard {
  RedirectGuard({
    DateTime Function()? now,
    this.minInterval = const Duration(seconds: 1),
    this.maxRedirects = 3,
    this.window = const Duration(seconds: 10),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Minimum time between two redirects.
  final Duration minInterval;

  /// How many redirects are allowed within [window] before giving up.
  final int maxRedirects;
  final Duration window;

  final List<DateTime> _history = [];

  /// Asks whether a redirect may happen. A [RedirectNow] or [RedirectLater]
  /// verdict is counted as a redirect.
  RedirectVerdict request() {
    final now = _now();
    _history.removeWhere((t) => now.difference(t) >= window);
    if (_history.length >= maxRedirects) return const RedirectGiveUp();

    final earliest = _history.isEmpty ? now : _history.last.add(minInterval);
    final scheduled = earliest.isAfter(now) ? earliest : now;
    _history.add(scheduled);
    final delay = scheduled.difference(now);
    return delay == Duration.zero ? const RedirectNow() : RedirectLater(delay);
  }

  /// Forget past redirects (e.g. after the user taps "Try again").
  void reset() => _history.clear();
}
