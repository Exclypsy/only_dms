import 'dart:convert';

import 'header_reveal.dart';

/// Purely cosmetic CSS. Blocking itself is done by `UrlPolicy`; this only
/// removes dead-end buttons. If Instagram changes its markup, update the
/// selectors here – a selector that no longer matches simply does nothing.
const String _pageCss = '''
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

/* Custom chat background (chat_wallpaper.dart). The photo itself arrives in a
   separate <style>; here is only how it is laid out behind the messages.
   Instagram rounds the message bubbles with a wide outline in the page colour,
   which would show as dark squares on a photo. */
html[data-nofeed-wallpaper] [data-pagelet="IGDMessagesList"] {
  background-size: cover !important;
  background-position: center !important;
  background-repeat: no-repeat !important;
}
html[data-nofeed-wallpaper] [data-pagelet="IGDMessagesList"] * {
  outline-color: transparent !important;
}
/* Times, names and "Seen" are written straight on the photo in Instagram's
   secondary text colour. There it becomes black or white, whichever is
   readable on this photo (--nofeed-wallpaper-text, chat_wallpaper.dart);
   inside the message bubbles (role=presentation) it stays as it was. */
html[data-nofeed-wallpaper] {
  --nofeed-ig-secondary-text: var(--ig-secondary-text);
  --nofeed-ig-tertiary-text: var(--ig-tertiary-text);
}
html[data-nofeed-wallpaper] [data-pagelet="IGDMessagesList"] {
  --ig-secondary-text: var(--nofeed-wallpaper-text, var(--nofeed-ig-secondary-text)) !important;
  --ig-tertiary-text: var(--nofeed-wallpaper-text, var(--nofeed-ig-tertiary-text)) !important;
}
html[data-nofeed-wallpaper] [data-pagelet="IGDMessagesList"] [role="presentation"] {
  --ig-secondary-text: var(--nofeed-ig-secondary-text) !important;
  --ig-tertiary-text: var(--nofeed-ig-tertiary-text) !important;
}

/* In a chat, holding the header opens NoFeed's menu for that chat. Without
   this WebKit would start selecting the header's text. Messages stay
   selectable; text fields handle selection themselves. */
html[data-nofeed-chat="1"] body {
  -webkit-user-select: none !important;
  user-select: none !important;
  -webkit-touch-callout: none !important;
}
html[data-nofeed-chat="1"] [data-pagelet="IGDMessagesList"] {
  -webkit-user-select: text !important;
  user-select: text !important;
}
''';

/// Anonymous mode (setting): names and profile pictures in the chat list and
/// inside chats are covered, so nobody looking at the screen sees who you talk
/// to. Message texts stay. Purely visual – the page itself is unchanged.
///
/// Texts that are names. Found by their place in the page (Instagram's class
/// names are random), so a change of Instagram's page can uncover them again.
const List<String> anonymousNameSelectors = [
  // Chat list: the name line of a chat row (the other line has the time).
  '[data-pagelet="IGDInboxThreadListScrollableAreaPagelet"] div[role="button"]:has(abbr) div:not(:has(abbr)) > span[dir="auto"]',
  // Notes above the chat list: the name under the picture.
  '[data-pagelet="IGDInboxThreadListScrollableAreaPagelet"] ul li div:has(> span[role="link"]) + div > span[dir="auto"]',
  // Your own username at the top of the chat list.
  '[role="navigation"] [role="button"] h2',
  // Header of an open chat: name and username.
  '[data-pagelet="IGDInboxHeaderOffMsys"] h2',
  '[data-pagelet="IGDInboxHeaderOffMsys"] span[dir="auto"]',
  // Inside a chat: sender names in groups and "… replied to …".
  '[data-pagelet="IGDMessagesList"] div:empty + div > div:not([role]) > span[dir="auto"]',
  // Inside a chat: "Seen by …".
  '[data-pagelet="IGDMessagesList"] > div > div > div > span[dir="auto"]',
];

/// Profile pictures.
const List<String> anonymousPictureSelectors = [
  '[data-pagelet="IGDInboxThreadListScrollableAreaPagelet"] :is(img[alt="user-profile-picture"], img[alt="User avatar"])',
  '[data-pagelet="IGDInboxHeaderOffMsys"] :is(img[alt="user-profile-picture"], img[alt="User avatar"])',
  '[data-pagelet="IGDMessagesList"] :is(img[alt="user-profile-picture"], img[alt="User avatar"])',
  // Notes above the chat list.
  '[data-pagelet="IGDInboxThreadListScrollableAreaPagelet"] ul li span[role="link"] img',
];

const String _anonymous = 'html[data-nofeed-anon="1"]';

/// A neutral person icon shown instead of a profile picture (the picture's
/// address in the page stays as it is).
const String _anonymousPicture =
    "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 40 40'%3E"
    "%3Crect width='40' height='40' fill='%23717b85'/%3E"
    "%3Ccircle cx='20' cy='15.5' r='7' fill='%23c3c9cf'/%3E"
    "%3Cpath d='M5.5 40c0-8.6 6.2-14 14.5-14s14.5 5.4 14.5 14z' fill='%23c3c9cf'/%3E%3C/svg%3E\")";

/// One rule per selector: if a browser does not understand one of them, the
/// others still work. A name is made fully transparent: that also hides emoji
/// and pictures inside it, keeps the layout and the taps, and does not touch
/// the `::before`/`::after` Instagram itself uses on its texts.
final String anonymousCss = [
  for (final selector in anonymousNameSelectors) '$_anonymous $selector { opacity: 0 !important; }',
  for (final selector in anonymousPictureSelectors)
    '$_anonymous $selector { content: $_anonymousPicture !important; }',
].join('\n');

/// All cosmetic rules inserted into the page.
final String cosmeticCss = '$_pageCss\n$anonymousCss\n';

/// JavaScript that marks the current page on `<html>` (for the rules above),
/// sets the page background colour, adds the empty decorative blur element
/// and inserts [cosmeticCss] as a `<style>` element once.
/// It only writes attributes, styles and that element; it reads no page content.
String cosmeticScript({
  required bool isInbox,
  required bool navBar,
  required String background,
  bool edgeToEdge = false,
  bool isChat = false,
  bool anonymous = false,
}) =>
    '''
(function () {
  var html = document.documentElement;
  html.setAttribute('data-nofeed-page', ${jsonEncode(isInbox ? 'inbox' : 'other')});
  html.setAttribute('data-nofeed-nav', ${jsonEncode(navBar ? '1' : '0')});
  html.setAttribute('data-nofeed-edge', ${jsonEncode(edgeToEdge ? '1' : '0')});
  html.setAttribute('data-nofeed-chat', ${jsonEncode(isChat ? '1' : '0')});
  html.setAttribute('data-nofeed-anon', ${jsonEncode(anonymous ? '1' : '0')});
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
