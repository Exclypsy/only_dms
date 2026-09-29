import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/nav_tabs.dart';

void main() {
  const ig = 'https://www.instagram.com';

  group('normalizeUsername', () {
    test('accepts valid names and cleans them up', () {
      expect(NavTabs.normalizeUsername('martin.b_1'), 'martin.b_1');
      expect(NavTabs.normalizeUsername('  @Martin.B  '), 'martin.b');
    });
    test('rejects invalid names', () {
      for (final input in ['', '@', 'a b', 'name/../x', 'ab-cd', 'x' * 31, '<script>']) {
        expect(NavTabs.normalizeUsername(input), isNull, reason: input);
      }
    });
  });

  test('profileUri', () {
    expect(NavTabs.profileUri('martin.b').toString(), '$ig/martin.b/');
  });

  group('activeTab', () {
    test('messages for everything under /direct/', () {
      expect(NavTabs.activeTab('$ig/direct/inbox/'), NavTab.messages);
      expect(NavTabs.activeTab('$ig/direct/t/123/'), NavTab.messages);
    });
    test('profile only for the own username', () {
      expect(NavTabs.activeTab('$ig/martin/', username: 'martin'), NavTab.profile);
      expect(NavTabs.activeTab('$ig/Martin/tagged/', username: 'martin'), NavTab.profile);
      expect(NavTabs.activeTab('$ig/someone/', username: 'martin'), isNull);
      expect(NavTabs.activeTab('$ig/martin/'), isNull);
    });
    test('none for other pages and domains', () {
      expect(NavTabs.activeTab('$ig/p/abc/', username: 'martin'), isNull);
      expect(NavTabs.activeTab('https://evil.com/direct/inbox/'), isNull);
      expect(NavTabs.activeTab(null), isNull);
    });
  });

  group('showBar', () {
    test('visible in the inbox and on profiles', () {
      expect(NavTabs.showBar('$ig/direct/inbox/'), isTrue);
      expect(NavTabs.showBar('$ig/direct/requests/'), isTrue);
      expect(NavTabs.showBar('$ig/martin/'), isTrue);
      expect(NavTabs.showBar('$ig/p/abc/'), isTrue);
    });
    test('hidden inside a chat and on login pages', () {
      expect(NavTabs.showBar('$ig/direct/t/123/'), isFalse);
      expect(NavTabs.showBar('$ig/accounts/login/'), isFalse);
      expect(NavTabs.showBar('$ig/challenge/x/'), isFalse);
      expect(NavTabs.showBar(null), isFalse);
      expect(NavTabs.showBar('https://example.com/'), isFalse);
    });
  });
}
