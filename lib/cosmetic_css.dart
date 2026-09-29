import 'dart:convert';

import 'header_reveal.dart';

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

/* Instagram's own bottom tab bar and its "Use the app" banner (NoFeed shows
   its own pill): the elements that contain both the Explore and the Reels tab
   but not the page content (<main>). Only on pages with NoFeed's pill; the
   inbox and chats are never touched. */
html[data-nofeed-nav="1"]:not([data-nofeed-page="inbox"]) div:has(a[href="/explore/"]):has(a[href="/reels/"]):not(:has(main)) {
  display: none !important;
}

/* Room at the end of the page so the last item can scroll above NoFeed's
   floating navigation pill (pages that scroll as a whole, e.g. the profile). */
html[data-nofeed-nav="1"]:not([data-nofeed-page="inbox"]) body {
  padding-bottom: 96px !important;
}

/* Inbox scrolling like the Instagram app: the header, search bar, notes and
   chats scroll together as one native page. Instagram's web instead shows a
   fixed full-screen box where only the chat list scrolls. Everything is
   anchored on the thread-list pagelet, so if Instagram changes its markup these
   rules simply stop matching and the web's own layout comes back. */

/* The fixed full-screen inbox container and its parents become normal,
   growing blocks, so the page itself scrolls. */
html[data-nofeed-page="inbox"] div:has(> [role="navigation"] > div > [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) {
  position: relative !important;
  inset: auto !important;
  height: auto !important;
  min-height: 100dvh !important;
}
html[data-nofeed-page="inbox"] div:has(> div > [role="navigation"] > div > [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]),
html[data-nofeed-page="inbox"] div:has(> div > div > [role="navigation"] > div > [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) {
  height: auto !important;
  max-height: none !important;
  padding-top: 0 !important;
}
html[data-nofeed-page="inbox"] [role="navigation"]:has(> div > [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]),
html[data-nofeed-page="inbox"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]),
html[data-nofeed-page="inbox"] [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"],
html[data-nofeed-page="inbox"] [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"] > :last-child {
  overflow-y: visible !important;
  height: auto !important;
  max-height: none !important;
}
html[data-nofeed-page="inbox"] [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"],
html[data-nofeed-page="inbox"] [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"] > :last-child {
  flex: none !important;
}
/* The last chat can scroll above the floating navigation pill. */
html[data-nofeed-page="inbox"] [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"] > :last-child {
  padding-bottom: 96px !important;
}

/* Header with the username, like the Instagram app: at the top it sits in its
   place. Scrolling down, the search bar slides under it on a blurred backdrop
   while it fades out; further down it fades back in on scrolling up,
   following the finger. The app sets --nofeed-header (content opacity),
   --nofeed-backdrop (how much of the header area is blurred) and
   data-nofeed-header (top / shown / hidden) from the native scroll position;
   data-nofeed-snap turns on the easing when scrolling stops. */
html[data-nofeed-page="inbox"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2) {
  position: sticky !important;
  top: env(safe-area-inset-top, 0px) !important;
  z-index: 10 !important;
  background: transparent !important;
}
html[data-nofeed-page="inbox"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2) > * {
  opacity: var(--nofeed-header, 1) !important;
}
html[data-nofeed-page="inbox"][data-nofeed-header="hidden"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2) {
  pointer-events: none !important;
}
/* Round glass button behind the "new message" icon while floating. */
html[data-nofeed-page="inbox"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2) :is(a, [role="button"]):has(svg):not(:has(h2)) {
  border-radius: 50% !important;
  transition: box-shadow 0.3s ease, background-color 0.3s ease !important;
}
html[data-nofeed-page="inbox"][data-nofeed-header="shown"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2) :is(a, [role="button"]):has(svg):not(:has(h2)) {
  background-color: color-mix(in srgb, currentColor 10%, transparent) !important;
  box-shadow: 0 0 0 9px color-mix(in srgb, currentColor 10%, transparent),
    0 0 0 9.5px color-mix(in srgb, currentColor 16%, transparent) !important;
}

/* Progressive blur at the top (under the status bar and behind the floating
   header), like iOS: five layers with blur 16 → 8 → 4 → 2 → 1 px, each strong
   only in its own band and overlapping its neighbours, so the blur weakens
   step by step. (One fading layer would show the content twice: sharp and
   blurred.) #nofeed-blur is an empty decorative element added by the
   cosmetic script outside Instagram's content. Its height covers the status
   bar, the header while it is shown, and a 36 px fall-off below. */
#nofeed-blur {
  display: none;
}
/* The inbox's parent elements each form their own layer (position: relative
   with z-index 0/1), which would trap the header below #nofeed-blur. Without
   those layers the header (z-index 10) sits above the blur (z-index 5) and the
   chat list below it. Only the ancestors of the chat list, only in the inbox. */
html[data-nofeed-page="inbox"] :has([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) {
  z-index: auto !important;
}
html[data-nofeed-page="inbox"]:is([data-nofeed-header="shown"], [data-nofeed-header="hidden"]) #nofeed-blur {
  display: block;
  position: fixed;
  left: 0;
  right: 0;
  top: 0;
  z-index: 5;
  pointer-events: none;
  height: calc(env(safe-area-inset-top, 0px) + var(--nofeed-backdrop, 0) * 48px + 36px);
  background: linear-gradient(to bottom, color-mix(in srgb, var(--nofeed-bg) 45%, transparent) calc(100% - 36px), transparent 100%);
}
#nofeed-blur > div {
  position: absolute;
  inset: 0;
}
#nofeed-blur > div:nth-child(1) {
  -webkit-backdrop-filter: blur(16px);
  backdrop-filter: blur(16px);
  -webkit-mask-image: linear-gradient(to bottom, #000 calc(100% - 36px), transparent calc(100% - 24px));
  mask-image: linear-gradient(to bottom, #000 calc(100% - 36px), transparent calc(100% - 24px));
}
#nofeed-blur > div:nth-child(2) {
  -webkit-backdrop-filter: blur(8px);
  backdrop-filter: blur(8px);
  -webkit-mask-image: linear-gradient(to bottom, transparent calc(100% - 36px), #000 calc(100% - 30px), #000 calc(100% - 24px), transparent calc(100% - 16px));
  mask-image: linear-gradient(to bottom, transparent calc(100% - 36px), #000 calc(100% - 30px), #000 calc(100% - 24px), transparent calc(100% - 16px));
}
#nofeed-blur > div:nth-child(3) {
  -webkit-backdrop-filter: blur(4px);
  backdrop-filter: blur(4px);
  -webkit-mask-image: linear-gradient(to bottom, transparent calc(100% - 24px), #000 calc(100% - 20px), #000 calc(100% - 16px), transparent calc(100% - 10px));
  mask-image: linear-gradient(to bottom, transparent calc(100% - 24px), #000 calc(100% - 20px), #000 calc(100% - 16px), transparent calc(100% - 10px));
}
#nofeed-blur > div:nth-child(4) {
  -webkit-backdrop-filter: blur(2px);
  backdrop-filter: blur(2px);
  -webkit-mask-image: linear-gradient(to bottom, transparent calc(100% - 16px), #000 calc(100% - 12px), #000 calc(100% - 10px), transparent calc(100% - 4px));
  mask-image: linear-gradient(to bottom, transparent calc(100% - 16px), #000 calc(100% - 12px), #000 calc(100% - 10px), transparent calc(100% - 4px));
}
#nofeed-blur > div:nth-child(5) {
  -webkit-backdrop-filter: blur(1px);
  backdrop-filter: blur(1px);
  -webkit-mask-image: linear-gradient(to bottom, transparent calc(100% - 10px), #000 calc(100% - 7px), #000 calc(100% - 4px), transparent calc(100% - 0px));
  mask-image: linear-gradient(to bottom, transparent calc(100% - 10px), #000 calc(100% - 7px), #000 calc(100% - 4px), transparent calc(100% - 0px));
}
/* Easing only when the header settles after scrolling stopped. */
html[data-nofeed-page="inbox"][data-nofeed-snap="1"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2) > * {
  transition: opacity 0.3s cubic-bezier(0.2, 0.8, 0.2, 1) !important;
}
html[data-nofeed-page="inbox"][data-nofeed-snap="1"] #nofeed-blur {
  transition: height 0.3s cubic-bezier(0.2, 0.8, 0.2, 1);
}

/* iPhone: in the inbox the WebView reaches under the status bar (the app sets
   data-nofeed-edge); the content starts below it and passes under the blur. */
html[data-nofeed-edge="1"][data-nofeed-page="inbox"] div:has(> [role="navigation"] > div > [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) {
  padding-top: env(safe-area-inset-top, 0px) !important;
}

/* Back arrow in the inbox header (it leads to the feed). Only in the inbox –
   inside a chat the same arrow goes back to the inbox. visibility keeps the
   header layout and makes the hidden button untappable. */
html[data-nofeed-page="inbox"] :is(a, [role="button"], [role="link"]):has(svg:is([aria-label="Back"], [aria-label="Späť"], [aria-label="Zpět"])),
html[data-nofeed-page="inbox"] svg:is([aria-label="Back"], [aria-label="Späť"], [aria-label="Zpět"]) {
  visibility: hidden !important;
}
''';

/// JavaScript that marks the current page on `<html>` (for the rules above),
/// sets the page background colour, adds the empty decorative blur element
/// and inserts [cosmeticCss] as a `<style>` element once.
/// It only writes attributes, styles and that element; it reads no page content.
String cosmeticScript({
  required bool isInbox,
  required bool navBar,
  required String background,
  bool edgeToEdge = false,
}) =>
    '''
(function () {
  var html = document.documentElement;
  html.setAttribute('data-nofeed-page', ${jsonEncode(isInbox ? 'inbox' : 'other')});
  html.setAttribute('data-nofeed-nav', ${jsonEncode(navBar ? '1' : '0')});
  html.setAttribute('data-nofeed-edge', ${jsonEncode(edgeToEdge ? '1' : '0')});
  html.style.setProperty('--nofeed-bg', ${jsonEncode(background)});
  if (!document.getElementById('nofeed-blur')) {
    var blur = document.createElement('div');
    blur.id = 'nofeed-blur';
    blur.setAttribute('aria-hidden', 'true');
    for (var i = 0; i < 5; i++) blur.appendChild(document.createElement('div'));
    html.appendChild(blur);
  }
  var id = 'nofeed-style';
  if (document.getElementById(id)) return;
  var style = document.createElement('style');
  style.id = id;
  style.textContent = ${jsonEncode(cosmeticCss)};
  (document.head || document.documentElement).appendChild(style);
})();
''';

/// Applies a header frame (see header_reveal.dart): content and backdrop
/// opacity as CSS variables plus the state attribute; [animate] eases into it
/// (used when scrolling stops). Only writes attributes and style properties.
String headerFrameScript(HeaderFrame frame, {required bool animate}) {
  String n(double v) => v.clamp(0.0, 1.0).toStringAsFixed(3);
  return '''
(function (html) {
  html.setAttribute('data-nofeed-snap', ${jsonEncode(animate ? '1' : '0')});
  html.style.setProperty('--nofeed-header', ${jsonEncode(n(frame.text))});
  html.style.setProperty('--nofeed-backdrop', ${jsonEncode(n(frame.backdrop))});
  html.setAttribute('data-nofeed-header', ${jsonEncode(frame.state.name)});
})(document.documentElement);
''';
}
