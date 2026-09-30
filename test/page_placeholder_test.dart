import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/page_placeholder.dart';
import 'package:nofeed/page_skeleton.dart';

void main() {
  const ig = 'https://www.instagram.com';

  group('pagePlaceholderFor', () {
    test('inbox, chat and the Following feed have a placeholder', () {
      expect(pagePlaceholderFor('$ig/direct/inbox/'), PagePlaceholder.inbox);
      expect(pagePlaceholderFor('$ig/direct/t/123/'), PagePlaceholder.chat);
      expect(pagePlaceholderFor('$ig/?variant=following'), PagePlaceholder.feed);
    });

    test('other pages have none', () {
      for (final url in [
        '$ig/accounts/login/',
        '$ig/martin/',
        '$ig/p/abc/',
        '$ig/direct/requests/',
        '$ig/',
        'https://evil.example/direct/inbox/',
      ]) {
        expect(pagePlaceholderFor(url), isNull, reason: url);
      }
      expect(pagePlaceholderFor(null), isNull);
    });
  });

  group('pageReadyScript', () {
    test('every page has a script that returns only a number', () {
      for (final kind in PagePlaceholder.values) {
        final script = pageReadyScript(kind);
        expect(script, isNotEmpty);
        // No text, attribute values or network access leave the page.
        for (final forbidden in [
          'textContent',
          'innerText',
          'innerHTML',
          'cookie',
          'localStorage',
          'fetch(',
          'XMLHttpRequest',
          'postMessage',
        ]) {
          expect(script.contains(forbidden), isFalse, reason: '$kind uses $forbidden');
        }
      }
    });
  });

  group('parsePageReady', () {
    test('a positive number means the page is drawn', () {
      expect(parsePageReady(1), isTrue);
      expect(parsePageReady(2), isTrue);
      expect(parsePageReady(1.0), isTrue);
      expect(parsePageReady('1'), isTrue);
    });

    test('anything else means not yet', () {
      expect(parsePageReady(0), isFalse);
      expect(parsePageReady('0'), isFalse);
      expect(parsePageReady(null), isFalse);
      expect(parsePageReady('x'), isFalse);
      expect(parsePageReady(true), isFalse);
    });
  });

  group('PageSkeleton', () {
    for (final kind in PagePlaceholder.values) {
      for (final brightness in Brightness.values) {
        testWidgets('draws $kind (${brightness.name}) without errors', (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: PageSkeleton(kind: kind, topInset: 59, bottomInset: 17),
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(PageSkeleton), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('fits a very small screen', (tester) async {
      tester.view.physicalSize = const Size(240, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final kind in PagePlaceholder.values) {
        await tester.pumpWidget(MaterialApp(home: PageSkeleton(kind: kind)));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: '$kind');
      }
    });
  });
}
