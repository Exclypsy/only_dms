import 'package:flutter_test/flutter_test.dart';
import 'package:only_dms/redirect_guard.dart';

void main() {
  late DateTime now;
  late RedirectGuard guard;

  setUp(() {
    now = DateTime(2026);
    guard = RedirectGuard(now: () => now);
  });

  test('first redirect happens immediately', () {
    expect(guard.request(), isA<RedirectNow>());
  });

  test('second redirect within a second is delayed', () {
    guard.request();
    now = now.add(const Duration(milliseconds: 300));
    final verdict = guard.request();
    expect(verdict, isA<RedirectLater>());
    expect((verdict as RedirectLater).delay, const Duration(milliseconds: 700));
  });

  test('redirects a second apart are immediate', () {
    guard.request();
    now = now.add(const Duration(seconds: 1));
    expect(guard.request(), isA<RedirectNow>());
  });

  test('gives up after too many redirects in the window', () {
    for (var i = 0; i < 3; i++) {
      expect(guard.request(), isNot(isA<RedirectGiveUp>()));
      now = now.add(const Duration(seconds: 2));
    }
    expect(guard.request(), isA<RedirectGiveUp>());
  });

  test('old redirects fall out of the window', () {
    for (var i = 0; i < 3; i++) {
      guard.request();
      now = now.add(const Duration(seconds: 2));
    }
    now = now.add(const Duration(seconds: 10));
    expect(guard.request(), isA<RedirectNow>());
  });

  test('reset clears the history', () {
    for (var i = 0; i < 3; i++) {
      guard.request();
    }
    guard.reset();
    expect(guard.request(), isA<RedirectNow>());
  });
}
