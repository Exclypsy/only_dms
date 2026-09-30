import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/cosmetic_css.dart';
import 'package:nofeed/header_reveal.dart';

void main() {
  test('script marks the page type and whether the nav pill is shown', () {
    final inbox = cosmeticScript(isInbox: true, navBar: true, background: '#0c1014');
    expect(inbox, contains("'data-nofeed-page', \"inbox\""));
    expect(inbox, contains("'data-nofeed-nav', \"1\""));
    final chat = cosmeticScript(isInbox: false, navBar: false, background: '#ffffff');
    expect(chat, contains("'data-nofeed-page', \"other\""));
    expect(chat, contains("'data-nofeed-nav', \"0\""));
  });

  test('script only writes an attribute and a style element', () {
    final script = cosmeticScript(isInbox: true, navBar: true, background: '#0c1014');
    for (final forbidden in [
      'fetch(',
      'XMLHttpRequest',
      'innerText',
      'innerHTML',
      'cookie',
      'postMessage',
      '.click(',
    ]) {
      expect(script, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('back-arrow rule is limited to the inbox', () {
    for (final line in cosmeticCss.split('\n').where((l) => l.contains('aria-label="Back"'))) {
      expect(line, startsWith('html[data-nofeed-page="inbox"]'));
    }
  });

  test('page background is passed for the sticky header', () {
    expect(
      cosmeticScript(isInbox: true, navBar: true, background: '#0c1014'),
      contains("setProperty('--nofeed-bg', \"#0c1014\")"),
    );
  });

  test('header frame script only writes opacities and the state', () {
    final script = headerFrameScript(const HeaderFrame(0.25, 1, floating: true), animate: false);
    expect(script, contains("setProperty('--nofeed-header', \"0.250\")"));
    expect(script, contains("setProperty('--nofeed-backdrop', \"1.000\")"));
    expect(script, contains("'data-nofeed-header', \"shown\""));
    expect(script, contains("'data-nofeed-snap', \"0\""));
    final settled = headerFrameScript(const HeaderFrame(0, 0, floating: true), animate: true);
    expect(settled, contains('"hidden"'));
    expect(settled, contains("'data-nofeed-snap', \"1\""));
    expect(
      headerFrameScript(const HeaderFrame(1, 0, floating: false), animate: false),
      contains('"top"'),
    );
    for (final forbidden in ['fetch(', 'XMLHttpRequest', 'cookie', 'innerHTML', 'textContent']) {
      expect(script, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('edge-to-edge flag is written for the blur under the status bar', () {
    final script = cosmeticScript(
      isInbox: true,
      navBar: true,
      background: '#fff',
      edgeToEdge: true,
    );
    expect(script, contains("'data-nofeed-edge', \"1\""));
    expect(
      cosmeticScript(isInbox: true, navBar: true, background: '#fff'),
      contains("'data-nofeed-edge', \"0\""),
    );
  });

  test('inbox layout rules are scoped to the inbox page', () {
    final lines = cosmeticCss
        .split('\n')
        .where((l) => l.contains('IGDInboxThreadList') && !l.contains('data-nofeed-anon'));
    expect(lines, isNotEmpty);
    for (final line in lines) {
      expect(line, startsWith('html['), reason: line);
      expect(line, contains('[data-nofeed-page="inbox"]'), reason: line);
    }
  });

  group('anonymous mode', () {
    test('every rule applies only while the mode is on', () {
      final rules = anonymousCss.split('\n');
      expect(rules.length, anonymousNameSelectors.length + anonymousPictureSelectors.length);
      for (final rule in rules) {
        expect(rule, startsWith('html[data-nofeed-anon="1"] '), reason: rule);
      }
      expect(cosmeticCss, contains(anonymousCss));
    });

    test('names become transparent (layout kept) and pictures get a neutral icon', () {
      for (final selector in anonymousNameSelectors) {
        expect(anonymousCss, contains('$selector { opacity: 0 !important; }'), reason: selector);
      }
      // Instagram's own pseudo-elements and the layout are left alone.
      expect(anonymousCss.contains('::after'), isFalse);
      expect(anonymousCss.contains('display: none'), isFalse);
      for (final selector in anonymousPictureSelectors) {
        expect(
          anonymousCss,
          contains('$selector { content: url("data:image/svg+xml,'),
          reason: selector,
        );
      }
      // Nothing is loaded from the network for the icon.
      expect(anonymousCss.contains('http://www.w3.org/2000/svg'), isTrue);
      expect(RegExp(r'url\("(?!data:)').hasMatch(anonymousCss), isFalse);
    });

    test('message texts are not touched', () {
      for (final selector in [...anonymousNameSelectors, ...anonymousPictureSelectors]) {
        expect(selector.contains('[role="presentation"]'), isFalse, reason: selector);
      }
      // Pictures are limited to the chat list, the chat header and the chat.
      for (final selector in anonymousPictureSelectors) {
        expect(selector, startsWith('[data-pagelet="IGD'), reason: selector);
      }
    });

    test('the script switches the mode with one attribute', () {
      String script({required bool anonymous}) =>
          cosmeticScript(isInbox: true, navBar: true, background: '#0c1014', anonymous: anonymous);
      expect(script(anonymous: true), contains("'data-nofeed-anon', \"1\""));
      expect(script(anonymous: false), contains("'data-nofeed-anon', \"0\""));
    });
  });
}
