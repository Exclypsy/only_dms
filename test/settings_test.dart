import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/settings.dart';
import 'package:nofeed/settings_screen.dart';
import 'package:nofeed/url_policy.dart';

void main() {
  const reel = 'https://www.instagram.com/reel/abc/';
  const story = 'https://www.instagram.com/stories/u/1/';

  group('AppSettings', () {
    test('defaults allow reels and stories, do not hide in recents', () {
      const s = AppSettings();
      expect(s.allowSharedReels, isTrue);
      expect(s.allowStories, isTrue);
      expect(s.hideInRecents, isFalse);
      expect(s.urlPolicy.decide(reel), UrlAction.allow);
      expect(s.urlPolicy.decide(story), UrlAction.allow);
    });

    test('username can be set and cleared', () {
      final withName = const AppSettings().copyWith(username: 'martin');
      expect(withName.username, 'martin');
      expect(withName.copyWith(allowStories: false).username, 'martin');
      expect(withName.copyWith(clearUsername: true).username, isNull);
    });

    test('notifications are off by default and can be turned on', () {
      expect(const AppSettings().notificationsEnabled, isFalse);
      final on = const AppSettings().copyWith(notificationsEnabled: true);
      expect(on.notificationsEnabled, isTrue);
      expect(on.copyWith(allowStories: false).notificationsEnabled, isTrue);
    });

    test('toggles are reflected in the URL policy', () {
      final s = const AppSettings().copyWith(allowSharedReels: false, allowStories: false);
      expect(s.urlPolicy.decide(reel), UrlAction.redirectToInbox);
      expect(s.urlPolicy.decide(story), UrlAction.redirectToInbox);
      expect(s.hideInRecents, isFalse);
    });
  });

  group('SettingsScreen', () {
    Future<void> pump(
      WidgetTester tester, {
      required ValueChanged<AppSettings> onChanged,
      required Future<void> Function() onLogout,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(
                      initial: const AppSettings(),
                      onChanged: onChanged,
                      onLogout: onLogout,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('switching stories off reports new settings', (tester) async {
      AppSettings? changed;
      await pump(tester, onChanged: (s) => changed = s, onLogout: () async {});
      await tester.tap(find.text('Povoliť stories'));
      await tester.pump();
      expect(changed?.allowStories, isFalse);
      expect(changed?.allowSharedReels, isTrue);
    });

    testWidgets('logout needs confirmation', (tester) async {
      var logouts = 0;
      await pump(tester, onChanged: (_) {}, onLogout: () async => logouts++);

      await tester.tap(find.text('Odhlásiť a vymazať dáta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zrušiť'));
      await tester.pumpAndSettle();
      expect(logouts, 0);

      await tester.tap(find.text('Odhlásiť a vymazať dáta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odhlásiť'));
      await tester.pumpAndSettle();
      expect(logouts, 1);
      expect(find.byType(SettingsScreen), findsNothing); // back to the WebView
    });
  });

  group('notifications setting', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required Future<bool> Function() onRequest,
      required ValueChanged<AppSettings> onChanged,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            initial: const AppSettings(),
            onChanged: onChanged,
            onLogout: () async {},
            onRequestNotifications: onRequest,
            onTestNotification: () async {},
          ),
        ),
      );
    }

    testWidgets('turning on asks for permission', (tester) async {
      AppSettings? changed;
      var asked = 0;
      await pumpScreen(tester, onRequest: () async => ++asked > 0, onChanged: (s) => changed = s);
      await tester.tap(find.text('Oznámenia o nových správach'));
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(changed?.notificationsEnabled, isTrue);
      expect(find.text('Poslať skúšobné oznámenie'), findsOneWidget);
    });

    testWidgets('stays off when permission is refused', (tester) async {
      AppSettings? changed;
      await pumpScreen(tester, onRequest: () async => false, onChanged: (s) => changed = s);
      await tester.tap(find.text('Oznámenia o nových správach'));
      await tester.pumpAndSettle();
      expect(changed, isNull);
      expect(find.textContaining('nie sú povolené'), findsOneWidget);
    });
  });
}
