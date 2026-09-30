import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/chat_snapshot.dart';

void main() {
  const ig = 'https://www.instagram.com';

  group('chatSnapshotKey', () {
    test('one key per chat and theme', () {
      expect(chatSnapshotKey('$ig/direct/t/1234567890/', dark: true), '1234567890_dark');
      expect(chatSnapshotKey('$ig/direct/t/1234567890', dark: false), '1234567890_light');
      expect(chatSnapshotKey('$ig/direct/t/abc_DEF-1/?x=1', dark: true), 'abc_DEF-1_dark');
    });

    test('null for pages that are not a chat', () {
      expect(chatSnapshotKey('$ig/direct/inbox/', dark: true), isNull);
      expect(chatSnapshotKey('$ig/direct/t/', dark: true), isNull);
      expect(chatSnapshotKey('$ig/martin/', dark: true), isNull);
      expect(chatSnapshotKey(null, dark: true), isNull);
    });

    test('never produces a path or an odd file name', () {
      expect(chatSnapshotKey('$ig/direct/t/..%2F..%2Fetc/', dark: true), isNull);
      expect(chatSnapshotKey('$ig/direct/t/a.b/', dark: true), isNull);
      expect(chatSnapshotKey('$ig/direct/t/${'1' * 65}/', dark: true), isNull);
      expect(chatSnapshotKey('$ig/direct/t/a b/', dark: true), isNull);
    });
  });

  group('parseChatPageState', () {
    test('numbers from iOS and Android', () {
      expect(parseChatPageState(0), ChatPageState.loading);
      expect(parseChatPageState(1), ChatPageState.scrolledUp);
      expect(parseChatPageState(2), ChatPageState.atNewest);
      expect(parseChatPageState(2.0), ChatPageState.atNewest);
      expect(parseChatPageState('2'), ChatPageState.atNewest);
    });

    test('anything else means still loading', () {
      expect(parseChatPageState(null), ChatPageState.loading);
      expect(parseChatPageState('x'), ChatPageState.loading);
      expect(parseChatPageState(7), ChatPageState.loading);
    });
  });
}
