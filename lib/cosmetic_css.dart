import 'dart:convert';

/// Purely cosmetic CSS. Blocking itself is done by `UrlPolicy`; this only
/// removes dead-end buttons. If Instagram changes its markup, update the
/// selectors here – a selector that no longer matches simply does nothing.
const String cosmeticCss = '''
/* Links to the feed, Explore and Reels. */
a[href="/"],
a[href="/explore/"],
a[href="/reels/"] {
  display: none !important;
}

/* Instagram's own bottom tab bar (NoFeed shows its own): the element that
   directly holds both the Explore and the Messages tab (max. two levels). */
:is(div, nav):has(> a[href="/explore/"], > * > a[href="/explore/"]):has(> a[href="/direct/inbox/"], > * > a[href="/direct/inbox/"]) {
  display: none !important;
}

/* Room at the end of the page so the last item can scroll above NoFeed's
   floating navigation pill (only on pages where the pill is shown). */
html[data-nofeed-nav="1"] body {
  padding-bottom: 96px !important;
}

/* Back arrow in the inbox header (it leads to the feed). Only in the inbox –
   inside a chat the same arrow goes back to the inbox. visibility keeps the
   header layout and makes the hidden button untappable. */
html[data-nofeed-page="inbox"] :is(a, [role="button"], [role="link"]):has(svg:is([aria-label="Back"], [aria-label="Späť"], [aria-label="Zpět"])),
html[data-nofeed-page="inbox"] svg:is([aria-label="Back"], [aria-label="Späť"], [aria-label="Zpět"]) {
  visibility: hidden !important;
}
''';

/// JavaScript that marks the current page on `<html>` (for the rules above)
/// and inserts [cosmeticCss] as a `<style>` element once.
/// It only writes attributes and a style element; it reads no page content.
String cosmeticScript({required bool isInbox, required bool navBar}) =>
    '''
(function () {
  var html = document.documentElement;
  html.setAttribute('data-nofeed-page', ${jsonEncode(isInbox ? 'inbox' : 'other')});
  html.setAttribute('data-nofeed-nav', ${jsonEncode(navBar ? '1' : '0')});
  var id = 'nofeed-style';
  if (document.getElementById(id)) return;
  var style = document.createElement('style');
  style.id = id;
  style.textContent = ${jsonEncode(cosmeticCss)};
  (document.head || document.documentElement).appendChild(style);
})();
''';
