import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/unread_notifier.dart';

String result(int rows, List<List<String>> unread) => jsonEncode({'rows': rows, 'unread': unread});

void main() {
  group('parseUnreadChats', () {
    test('reads the name and the preview of unread chats', () {
      final chats = parseUnreadChats(
        result(12, [
          ['Tímea', 'Jeden trapny toast'],
          ['VUT FIT', 'Miro: Kde ste?'],
        ]),
      );
      expect(chats, const [
        UnreadChat('Tímea', 'Jeden trapny toast'),
        UnreadChat('VUT FIT', 'Miro: Kde ste?'),
      ]);
    });

    test('no unread chats is an empty list', () {
      expect(parseUnreadChats(result(12, [])), isEmpty);
    });

    test('Android wraps the result in a JSON string', () {
      final wrapped = jsonEncode(
        result(3, [
          ['Anna', 'Ahoj'],
        ]),
      );
      expect(parseUnreadChats(wrapped), const [UnreadChat('Anna', 'Ahoj')]);
    });

    test('unknown while the list is missing or still empty', () {
      expect(parseUnreadChats(null), isNull);
      expect(parseUnreadChats('null'), isNull);
      expect(parseUnreadChats(result(0, [])), isNull);
      expect(parseUnreadChats('not json'), isNull);
      expect(parseUnreadChats(42), isNull);
      expect(parseUnreadChats(jsonEncode({'rows': 3})), isNull);
    });

    test('cleans up whitespace, control characters and very long texts', () {
      final chats = parseUnreadChats(
        result(1, [
          ['  Anna\n\tNováková ', 'a\u202Eb   c${'x' * 500}'],
        ]),
      )!;
      expect(chats.single.name, 'Anna Nováková');
      expect(chats.single.text, startsWith('a b c'));
      expect(chats.single.text.runes.length, 200);
      expect(chats.single.text, endsWith('…'));
    });

    test('skips malformed rows', () {
      final chats = parseUnreadChats(
        jsonEncode({
          'rows': 5,
          'unread': [
            ['Anna'],
            ['Anna', 5],
            ['', 'text'],
            ['Boris', '  '],
            'x',
            ['Cyril', 'Čau'],
          ],
        }),
      );
      expect(chats, const [UnreadChat('Cyril', 'Čau')]);
    });
  });

  group('UnreadChatTracker', () {
    const anna = UnreadChat('Anna', 'Ahoj');

    test('does not notify for chats that were already unread', () {
      expect(UnreadChatTracker().update(const [anna]), isEmpty);
    });

    test('notifies for a new unread chat, once', () {
      final tracker = UnreadChatTracker()..update(const []);
      expect(tracker.update(const [anna]), const [anna]);
      expect(tracker.update(const [anna]), isEmpty);
    });

    test('notifies again when another message arrives in the same chat', () {
      final tracker = UnreadChatTracker()..update(const [anna]);
      const next = UnreadChat('Anna', 'Si tam?');
      expect(tracker.update(const [next]), const [next]);
    });

    test('notifies again after the chat was read and a new message came', () {
      final tracker = UnreadChatTracker()
        ..update(const [])
        ..update(const [anna])
        ..update(const []);
      expect(tracker.update(const [anna]), const [anna]);
    });

    test('an unknown reading changes nothing', () {
      final tracker = UnreadChatTracker()..update(const [anna]);
      expect(tracker.update(null), isEmpty);
      expect(tracker.update(const [anna]), isEmpty);
    });

    test('reset forgets everything', () {
      final tracker = UnreadChatTracker()..update(const []);
      tracker.reset();
      expect(tracker.update(const [anna]), isEmpty);
    });
  });
}
