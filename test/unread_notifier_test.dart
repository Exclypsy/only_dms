import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/unread_notifier.dart';

void main() {
  group('parseUnreadCount', () {
    test('reads the counter at the start of the title', () {
      expect(parseUnreadCount('(2) Instagram • Messages'), 2);
      expect(parseUnreadCount('(1) Instagram'), 1);
      expect(parseUnreadCount(' (12) Inbox'), 12);
      expect(parseUnreadCount('(99+) Instagram'), 99);
    });
    test('no counter means nothing unread', () {
      expect(parseUnreadCount('Instagram • Messages'), 0);
      expect(parseUnreadCount('Chat (2) Instagram'), 0); // only at the start
    });
    test('no title means unknown', () {
      expect(parseUnreadCount(null), isNull);
      expect(parseUnreadCount('  '), isNull);
    });
  });

  group('UnreadTracker', () {
    test('does not notify for the first reading', () {
      expect(UnreadTracker().update(3), isFalse);
    });
    test('notifies only when the counter goes up', () {
      final tracker = UnreadTracker()..update(0);
      expect(tracker.update(0), isFalse);
      expect(tracker.update(1), isTrue);
      expect(tracker.update(1), isFalse);
      expect(tracker.update(0), isFalse); // read
      expect(tracker.update(2), isTrue);
    });
    test('ignores unknown readings', () {
      final tracker = UnreadTracker()..update(1);
      expect(tracker.update(null), isFalse);
      expect(tracker.update(2), isTrue);
    });
    test('reset starts over', () {
      final tracker = UnreadTracker()..update(1);
      tracker.reset();
      expect(tracker.update(5), isFalse);
    });
  });

  test('notification text has no names, only the counter', () {
    expect(unreadNotificationText(1), 'Máš novú správu na Instagrame.');
    expect(unreadNotificationText(3), contains('3 neprečítané'));
    expect(unreadNotificationText(7), contains('7 neprečítaných'));
  });
}
