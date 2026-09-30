import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/chat_keyboard.dart';

void main() {
  late DateTime now;
  late ChatKeyboard keyboard;
  const height = 800.0;

  setUp(() {
    now = DateTime(2026, 9, 30, 12);
    keyboard = ChatKeyboard(clock: () => now);
  });

  void wait(int ms) => now = now.add(Duration(milliseconds: ms));

  group('keyboardShown', () {
    test('closes the keyboard Instagram opens by itself right after a chat opens', () {
      keyboard.chatOpened();
      wait(1100);
      expect(keyboard.keyboardShown(), isTrue);
    });

    test('keeps it when you tapped the composer', () {
      keyboard.chatOpened();
      keyboard.pointerDown(const Offset(100, height - 40), height);
      wait(500);
      expect(keyboard.keyboardShown(), isFalse);
    });

    test('keeps it later on or without a newly opened chat', () {
      keyboard.chatOpened();
      wait(4000);
      expect(keyboard.keyboardShown(), isFalse);
      expect(keyboard.keyboardShown(), isFalse);
    });

    test('only the first appearance after opening counts', () {
      keyboard.chatOpened();
      wait(800);
      expect(keyboard.keyboardShown(), isTrue);
      wait(500);
      expect(keyboard.keyboardShown(), isFalse);
    });
  });

  group('closing gestures', () {
    test('a tap on the conversation closes the keyboard', () {
      keyboard.pointerDown(const Offset(100, 300), height);
      wait(120);
      expect(keyboard.pointerUp(const Offset(104, 302)), isTrue);
    });

    test('a tap on the composer does not', () {
      keyboard.pointerDown(const Offset(100, height - 30), height);
      wait(120);
      expect(keyboard.pointerUp(const Offset(100, height - 30)), isFalse);
    });

    test('a long press or a scroll is not a tap', () {
      keyboard.pointerDown(const Offset(100, 300), height);
      wait(700);
      expect(keyboard.pointerUp(const Offset(100, 300)), isFalse);

      keyboard.pointerDown(const Offset(100, 300), height);
      wait(100);
      expect(keyboard.pointerUp(const Offset(100, 260)), isFalse);
    });

    test('dragging down over the conversation closes it once', () {
      keyboard.pointerDown(const Offset(100, 300), height);
      expect(keyboard.pointerMove(const Offset(100, 320)), isFalse);
      expect(keyboard.pointerMove(const Offset(100, 345)), isTrue);
      expect(keyboard.pointerMove(const Offset(100, 400)), isFalse);
    });

    test('dragging up (scrolling to newer messages) does not', () {
      keyboard.pointerDown(const Offset(100, 500), height);
      expect(keyboard.pointerMove(const Offset(100, 380)), isFalse);
    });
  });
}
