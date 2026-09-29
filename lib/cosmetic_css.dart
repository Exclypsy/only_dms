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

/* Instagram's own bottom tab bar (NoFeed shows its own pill). Matched by its
   exact structure down to the Explore tab (as of Sep 2026), so it can never
   hide anything larger; if Instagram changes it, the rule simply stops matching. */
div:has(> div[tabindex="-1"] > div > div > div > div[data-visualcompletion="ignore-dynamic"] > div > span > div > a[href="/explore/"]) {
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
   --nofeed-backdrop (blur opacity) and data-nofeed-header (top / shown /
   hidden) from the native scroll position; data-nofeed-snap turns on the
   easing when scrolling stops. */
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
/* Blurred, tinted backdrop behind the floating header. It reaches up to the
   top of the screen (under the status bar), so the status bar and the header
   share one continuous blur without a seam. Below the header it fades out
   over a long, eased gradient; a second, lighter blur continues further down,
   so the blur weakens gradually (progressive blur) like in the app. */
html[data-nofeed-page="inbox"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2)::before,
html[data-nofeed-page="inbox"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2)::after {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  z-index: -1;
  pointer-events: none;
  opacity: var(--nofeed-backdrop, 0);
}
html[data-nofeed-page="inbox"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2)::before {
  top: calc(-1 * env(safe-area-inset-top, 0px));
  bottom: -44px;
  background: color-mix(in srgb, var(--nofeed-bg) 40%, transparent);
  -webkit-backdrop-filter: blur(16px);
  backdrop-filter: blur(16px);
  -webkit-mask-image: linear-gradient(to bottom, #000 calc(100% - 44px), rgb(0 0 0 / 0.84) calc(100% - 44px * 0.75), rgb(0 0 0 / 0.5) calc(100% - 44px * 0.5), rgb(0 0 0 / 0.16) calc(100% - 44px * 0.25), transparent 100%);
  mask-image: linear-gradient(to bottom, #000 calc(100% - 44px), rgb(0 0 0 / 0.84) calc(100% - 44px * 0.75), rgb(0 0 0 / 0.5) calc(100% - 44px * 0.5), rgb(0 0 0 / 0.16) calc(100% - 44px * 0.25), transparent 100%);
}
html[data-nofeed-page="inbox"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2)::after {
  top: calc(100% - 12px);
  bottom: -84px;
  -webkit-backdrop-filter: blur(5px);
  backdrop-filter: blur(5px);
  -webkit-mask-image: linear-gradient(to bottom, transparent 0, #000 12px, rgb(0 0 0 / 0.84) calc(12px + (100% - 12px) * 0.25), rgb(0 0 0 / 0.5) calc(12px + (100% - 12px) * 0.5), rgb(0 0 0 / 0.16) calc(12px + (100% - 12px) * 0.75), transparent 100%);
  mask-image: linear-gradient(to bottom, transparent 0, #000 12px, rgb(0 0 0 / 0.84) calc(12px + (100% - 12px) * 0.25), rgb(0 0 0 / 0.5) calc(12px + (100% - 12px) * 0.5), rgb(0 0 0 / 0.16) calc(12px + (100% - 12px) * 0.75), transparent 100%);
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
/* Easing only when the header settles after scrolling stopped. */
html[data-nofeed-page="inbox"][data-nofeed-snap="1"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2) > *,
html[data-nofeed-page="inbox"][data-nofeed-snap="1"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2)::before,
html[data-nofeed-page="inbox"][data-nofeed-snap="1"] div:has(> [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) > :not([data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]):has([role="button"] h2)::after,
html[data-nofeed-page="inbox"][data-nofeed-snap="1"] body::before,
html[data-nofeed-page="inbox"][data-nofeed-snap="1"] body::after {
  transition: opacity 0.3s cubic-bezier(0.2, 0.8, 0.2, 1), height 0.3s cubic-bezier(0.2, 0.8, 0.2, 1) !important;
}

/* iPhone: in the inbox the WebView reaches under the status bar (the app sets
   data-nofeed-edge). The content starts below it and, when scrolled, passes
   underneath a blurred, tinted band like in the Instagram app. The band is
   only used while the header's own backdrop (which also covers the status
   bar) is gone; the two cross-fade, so they never meet at a hard edge. */
html[data-nofeed-edge="1"][data-nofeed-page="inbox"] div:has(> [role="navigation"] > div > [data-pagelet="IGDInboxThreadListScrollableAreaPagelet"]) {
  padding-top: env(safe-area-inset-top, 0px) !important;
}
html[data-nofeed-edge="1"][data-nofeed-page="inbox"] body::before,
html[data-nofeed-edge="1"][data-nofeed-page="inbox"] body::after {
  content: "";
  position: fixed;
  left: 0;
  right: 0;
  z-index: 2147483000;
  pointer-events: none;
  opacity: calc(1 - var(--nofeed-backdrop, 0));
  --nofeed-fade: calc((1 - var(--nofeed-backdrop, 0)) * 32px);
}
html[data-nofeed-edge="1"][data-nofeed-page="inbox"] body::before {
  top: 0;
  height: calc(env(safe-area-inset-top, 0px) + var(--nofeed-fade));
  background: color-mix(in srgb, var(--nofeed-bg) 40%, transparent);
  -webkit-backdrop-filter: blur(16px);
  backdrop-filter: blur(16px);
  -webkit-mask-image: linear-gradient(to bottom, #000 calc(100% - var(--nofeed-fade)), rgb(0 0 0 / 0.84) calc(100% - var(--nofeed-fade) * 0.75), rgb(0 0 0 / 0.5) calc(100% - var(--nofeed-fade) * 0.5), rgb(0 0 0 / 0.16) calc(100% - var(--nofeed-fade) * 0.25), transparent 100%);
  mask-image: linear-gradient(to bottom, #000 calc(100% - var(--nofeed-fade)), rgb(0 0 0 / 0.84) calc(100% - var(--nofeed-fade) * 0.75), rgb(0 0 0 / 0.5) calc(100% - var(--nofeed-fade) * 0.5), rgb(0 0 0 / 0.16) calc(100% - var(--nofeed-fade) * 0.25), transparent 100%);
}
/* Lighter blur continuing below the band: the blur weakens gradually. */
html[data-nofeed-edge="1"][data-nofeed-page="inbox"] body::after {
  top: calc(env(safe-area-inset-top, 0px) + var(--nofeed-fade) - 12px);
  height: calc((1 - var(--nofeed-backdrop, 0)) * 60px);
  -webkit-backdrop-filter: blur(3px);
  backdrop-filter: blur(3px);
  -webkit-mask-image: linear-gradient(to bottom, transparent 0, #000 12px, rgb(0 0 0 / 0.84) calc(12px + (100% - 12px) * 0.25), rgb(0 0 0 / 0.5) calc(12px + (100% - 12px) * 0.5), rgb(0 0 0 / 0.16) calc(12px + (100% - 12px) * 0.75), transparent 100%);
  mask-image: linear-gradient(to bottom, transparent 0, #000 12px, rgb(0 0 0 / 0.84) calc(12px + (100% - 12px) * 0.25), rgb(0 0 0 / 0.5) calc(12px + (100% - 12px) * 0.5), rgb(0 0 0 / 0.16) calc(12px + (100% - 12px) * 0.75), transparent 100%);
}

/* At the top (and before the first scroll) the header sits right below the
   status bar: the band must end there, or it would blur the username. */
html[data-nofeed-edge="1"][data-nofeed-page="inbox"]:not([data-nofeed-header="shown"]):not([data-nofeed-header="hidden"]) body::before,
html[data-nofeed-edge="1"][data-nofeed-page="inbox"]:not([data-nofeed-header="shown"]):not([data-nofeed-header="hidden"]) body::after {
  --nofeed-fade: 0px;
}
html[data-nofeed-edge="1"][data-nofeed-page="inbox"]:not([data-nofeed-header="shown"]):not([data-nofeed-header="hidden"]) body::after {
  height: 0;
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
/// sets the page background colour for the sticky header and inserts
/// [cosmeticCss] as a `<style>` element once.
/// It only writes attributes and styles; it reads no page content.
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
