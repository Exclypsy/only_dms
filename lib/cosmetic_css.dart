import 'dart:convert';

/// Purely cosmetic CSS that hides links to the feed, Reels and Explore.
/// Blocking itself is done by `UrlPolicy`; this only removes dead-end buttons.
/// If Instagram changes its markup, update the selectors here.
const String cosmeticCss = '''
a[href="/"],
a[href="/explore/"],
a[href="/reels/"] {
  display: none !important;
}
''';

/// JavaScript that inserts [cosmeticCss] as a `<style>` element once.
/// It only adds a style element and does not read any page content.
final String cosmeticCssScript =
    '''
(function () {
  var id = 'onlydms-style';
  if (document.getElementById(id)) return;
  var style = document.createElement('style');
  style.id = id;
  style.textContent = ${jsonEncode(cosmeticCss)};
  (document.head || document.documentElement).appendChild(style);
})();
''';
