import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/url_policy.dart';

void main() {
  const policy = UrlPolicy();
  void expectAction(String url, UrlAction expected, {UrlPolicy p = policy}) =>
      expect(p.decide(url), expected, reason: url);

  group('allowed Instagram pages', () {
    for (final url in [
      'https://www.instagram.com/direct/inbox/',
      'https://www.instagram.com/direct/t/1234567890/',
      'https://www.instagram.com/accounts/login/?next=%2Fdirect%2Finbox%2F',
      'https://www.instagram.com/accounts/login/two_factor',
      'https://www.instagram.com/challenge/abc/',
      'https://www.instagram.com/some.user_1/',
      'https://www.instagram.com/some.user_1/tagged/',
      'https://www.instagram.com/p/ABC123/',
      'https://www.instagram.com/reel/abc/',
      'https://www.instagram.com/stories/some.user/123/',
      'https://instagram.com/direct/inbox/',
      'https://accountscenter.instagram.com/personal_info/',
      'https://l.instagram.com/?u=https%3A%2F%2Fexample.com',
    ]) {
      test(url, () => expectAction(url, UrlAction.allow));
    }
  });

  group('blocked Instagram pages redirect to inbox', () {
    for (final url in [
      'https://www.instagram.com/',
      'https://www.instagram.com',
      'https://www.instagram.com/?variant=following',
      'https://www.instagram.com//',
      'https://www.instagram.com/reels/',
      'https://www.instagram.com/reels',
      'https://www.instagram.com/reels/xyz/',
      'https://www.instagram.com/explore/',
      'https://www.instagram.com/explore/tags/cats/',
      'https://www.instagram.com/EXPLORE/',
      'https://www.instagram.com/Reels/',
      'https://www.instagram.com/reel/', // no id
      'https://www.instagram.com/not-a-username/',
    ]) {
      test(url, () => expectAction(url, UrlAction.redirectToInbox));
    }
  });

  test('/reels is blocked but /reel/abc is allowed', () {
    expectAction('https://www.instagram.com/reels/', UrlAction.redirectToInbox);
    expectAction('https://www.instagram.com/reel/abc', UrlAction.allow);
  });

  test('uppercase host is treated like lowercase', () {
    expectAction('https://WWW.INSTAGRAM.COM/direct/inbox/', UrlAction.allow);
    expectAction('HTTPS://WwW.Instagram.Com/explore/', UrlAction.redirectToInbox);
  });

  group('other domains open in the system browser', () {
    for (final url in [
      'https://example.com/',
      'https://www.facebook.com/login/',
      'https://instagram.com.evil.com/direct/inbox/',
      'https://evilinstagram.com/',
      'https://www.instagram.com@evil.com/',
      'https://instagram.co/',
      'http://example.com/',
    ]) {
      test(url, () => expectAction(url, UrlAction.openExternal));
    }
  });

  group('bad schemes and malformed URLs are blocked', () {
    for (final url in [
      'intent://direct#Intent;scheme=instagram;end',
      'instagram://direct',
      'javascript:alert(1)',
      'JavaScript:alert(1)',
      'file:///sdcard/secret.txt',
      'content://com.android.contacts/contacts',
      'data:text/html,<h1>x</h1>',
      'about:blank',
      'http://www.instagram.com/direct/inbox/', // no cleartext for Instagram
      'https://www.instagram.com:8443/direct/inbox/',
      'https://user:pass@www.instagram.com/direct/inbox/',
      '',
      '   ',
      '/direct/inbox/',
      'https://',
      'http://[::1',
    ]) {
      test('"$url"', () => expectAction(url, UrlAction.block));
    }
  });

  group('settings toggles', () {
    const strict = UrlPolicy(allowSharedReels: false, allowStories: false);
    test('shared reels can be disabled', () {
      expectAction('https://www.instagram.com/reel/abc/', UrlAction.redirectToInbox, p: strict);
    });
    test('stories can be disabled', () {
      expectAction('https://www.instagram.com/stories/u/1/', UrlAction.redirectToInbox, p: strict);
    });
  });

  group('subframes', () {
    test('allow https and about:blank from any domain', () {
      expect(policy.decideSubframe('https://www.google.com/recaptcha/'), UrlAction.allow);
      expect(policy.decideSubframe('about:blank'), UrlAction.allow);
    });
    test('block other schemes', () {
      for (final url in ['intent://x', 'javascript:1', 'http://example.com', 'file:///x']) {
        expect(policy.decideSubframe(url), UrlAction.block, reason: url);
      }
    });
  });

  group('isInbox', () {
    test('recognises the inbox', () {
      expect(UrlPolicy.isInbox('https://www.instagram.com/direct/inbox/'), isTrue);
      expect(UrlPolicy.isInbox('https://www.instagram.com/direct/inbox'), isTrue);
      expect(UrlPolicy.isInbox('https://instagram.com/Direct/Inbox/?x=1'), isTrue);
    });
    test('rejects everything else', () {
      expect(UrlPolicy.isInbox(null), isFalse);
      expect(UrlPolicy.isInbox('https://www.instagram.com/direct/t/1/'), isFalse);
      expect(UrlPolicy.isInbox('https://evil.com/direct/inbox/'), isFalse);
      expect(UrlPolicy.isInbox('https://instagram.com.evil.com/direct/inbox/'), isFalse);
    });
  });
}
