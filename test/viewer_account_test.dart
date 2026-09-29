import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/viewer_account.dart';

void main() {
  group('parseViewerUsername', () {
    test('accepts the iOS (raw) and Android (JSON-encoded) forms', () {
      expect(parseViewerUsername('martinbartkoo'), 'martinbartkoo');
      expect(parseViewerUsername('"martin.b_1"'), 'martin.b_1');
      expect(parseViewerUsername('  Martin.B '), 'martin.b');
    });

    test('rejects missing, invalid or non-string results', () {
      for (final result in <Object?>[null, '', '""', 42, true, 'two words', '"a/b"', '"broken']) {
        expect(parseViewerUsername(result), isNull, reason: '$result');
      }
    });

    test('rejects page names that are not a person', () {
      for (final word in ['Messages', 'Chats', 'direct', 'explore', 'reels', 'instagram']) {
        expect(parseViewerUsername(word), isNull, reason: word);
      }
    });
  });

  test('script reads only the header heading and sends nothing', () {
    expect(readViewerUsernameScript, contains('[role="navigation"] [role="button"] h2'));
    for (final forbidden in [
      'fetch(',
      'XMLHttpRequest',
      'cookie',
      'postMessage',
      'innerHTML',
      'querySelectorAll',
      '.click(',
      'localStorage',
    ]) {
      expect(readViewerUsernameScript, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  group('parseAvatarUrl', () {
    const cdn = 'https://scontent-prg1-1.cdninstagram.com/v/t51/123_n.jpg?stp=x&oh=1';
    test('accepts Instagram / Facebook CDN images (raw and JSON-encoded)', () {
      expect(parseAvatarUrl(cdn).toString(), cdn);
      expect(parseAvatarUrl('"$cdn"').toString(), cdn);
      expect(parseAvatarUrl('https://scontent.xx.fbcdn.net/a.jpg'), isNotNull);
    });
    test('rejects everything else', () {
      for (final url in <Object?>[
        null,
        '',
        42,
        'http://scontent.cdninstagram.com/a.jpg',
        'https://evil.com/a.jpg',
        'https://cdninstagram.com.evil.com/a.jpg',
        'https://user@scontent.cdninstagram.com/a.jpg',
        'https://scontent.cdninstagram.com:8443/a.jpg',
        'data:image/png;base64,AAAA',
        'javascript:alert(1)',
        '/relative.jpg',
      ]) {
        expect(parseAvatarUrl(url), isNull, reason: '$url');
      }
    });
  });

  group('readViewerAvatarScript', () {
    test('embeds only a validated username', () {
      expect(readViewerAvatarScript('martin.b', inbox: false), contains('"martin.b", false'));
      final hostile = readViewerAvatarScript('"]); fetch("x', inbox: true);
      expect(hostile, contains('"", true'));
      expect(hostile, isNot(contains('fetch("x')));
    });
    test('reads only an image address and sends nothing', () {
      final script = readViewerAvatarScript('martin', inbox: true);
      for (final forbidden in [
        'fetch(',
        'XMLHttpRequest',
        'cookie',
        'postMessage',
        'innerHTML',
        'textContent',
        '.click(',
        'localStorage',
      ]) {
        expect(script, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}
