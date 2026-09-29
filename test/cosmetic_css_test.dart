import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/cosmetic_css.dart';

void main() {
  test('script marks the page type and whether the nav pill is shown', () {
    final inbox = cosmeticScript(isInbox: true, navBar: true);
    expect(inbox, contains("'data-nofeed-page', \"inbox\""));
    expect(inbox, contains("'data-nofeed-nav', \"1\""));
    final chat = cosmeticScript(isInbox: false, navBar: false);
    expect(chat, contains("'data-nofeed-page', \"other\""));
    expect(chat, contains("'data-nofeed-nav', \"0\""));
  });

  test('script only writes an attribute and a style element', () {
    final script = cosmeticScript(isInbox: true, navBar: true);
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
}
