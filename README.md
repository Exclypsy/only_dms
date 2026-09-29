# NoFeed

A minimal Android/iOS app that shows only your Instagram direct messages –
no feed, no Reels, no Explore. It is a WebView around `https://www.instagram.com`;
you log in directly on instagram.com and the app never sees your password.

> **Disclaimer:** NoFeed is an independent project for Instagram and is not
> affiliated with, endorsed or sponsored by Meta Platforms, Inc. or Instagram.

## How it works

- Starts at `/direct/inbox/`.
- `lib/url_policy.dart` decides every navigation (all rules in one place):
  - allowed: `/direct/*`, `/accounts/*`, `/challenge/*`, profiles, `/p/*`,
    `/reel/<id>`, `/stories/*` and other `*.instagram.com` subdomains;
  - redirected to the inbox: `/`, `/reels*`, `/explore*`;
  - other websites open in the system browser;
  - other schemes (`intent:`, `javascript:`, `file:` …) are blocked.
- Because Instagram is a single-page app, URL changes are checked both in
  `onNavigationRequest` and `onUrlChange`.
- `lib/redirect_guard.dart` limits redirects to one per second and shows an
  error screen after 5 redirects within 10 s (protection against loops).
- `lib/cosmetic_css.dart` only hides dead-end buttons with CSS (Home/Explore/
  Reels links, Instagram's own bottom bar, the ← arrow in the inbox header that
  leads to the feed). This script only sets `data-nofeed-*` attributes on
  `<html>` and inserts the `<style>`; it never reads the page.

## Look & feel (like the Instagram app)

- **No toolbar**: the page starts right under the status bar; the dark theme uses
  Instagram's background colour (#0C1014).
- **Floating navigation pill** with only **Messages** and **Profile**
  (`lib/nav_bar.dart`, logic in `lib/nav_tabs.dart`): translucent blurred capsule,
  own paper-plane icon (outlined / filled) and your profile picture (ring when
  active). The highlight slides to the tapped item and stretches on the way, like
  liquid glass. Hidden inside an open chat, on login pages and while the keyboard
  is open.
- **Tabs stay loaded** (`lib/instagram_tab.dart`): Messages and Profile each have
  their own WebView that stays alive, so switching is instant and keeps the
  scroll position. The Profile tab is loaded in the background as soon as your
  username is known. Tapping the active tab again goes back to its start. Both
  WebViews share the login.
- **Settings**: long-press Profile in the pill (a one-time tip explains it); also
  reachable from the error screen.
- **Inbox scrolling** (`lib/cosmetic_css.dart`, `lib/header_reveal.dart`): the
  header, search bar, notes and chats scroll together as one native page (the
  web version only scrolls the chat list box).
  - Near the top the search bar slides under the username on a blurred
    backdrop while the username fades out with the scroll.
  - Further down the username fades back in as you scroll up, following the
    finger, and settles (eased) when scrolling stops.
  - On iPhone the inbox reaches under the status bar, where the content passes
    beneath a blurred, tinted band (CSS `backdrop-filter` with a mask).
  - The app reads the WebView's native scroll position and only writes two CSS
    variables and a few `data-nofeed-*` attributes; the injected JavaScript
    never reads the page for this.

### Profile button and picture

Profile opens the account you are logged in with. Instagram has no "my
profile" URL, so `lib/viewer_account.dart` reads **only the username** (inbox
header) and **only the address of your profile picture** – the single,
documented exception to "JS is cosmetic only" (CLAUDE.md §4, approved 29 Sep
2026). The name is validated, stored on the device and deleted on logout; the
picture URL must be HTTPS from Instagram's/Facebook's CDN, the image is loaded
from there and kept in memory only. If Instagram changes its page, the app asks
for the name and shows a person icon instead.

## Features (phase 2)

- **Photos & videos** (`<input type="file">`, Android): the system Photo Picker
  opens (Android 11+ with the Photo Picker update, otherwise the system file
  picker). No storage permission is requested; the picked `content://` URIs are
  handed straight to the WebView (`MainActivity.kt` → `pickMedia`).
- **Camera & microphone** (Android): only when the page on instagram.com asks for
  them and you allow it in the Android system dialog; everything else is denied.
- **Settings** (gear icon): allow shared reels (`/reel/…`), allow stories,
  hide content in recent apps (Android `FLAG_SECURE`, also blocks screenshots),
  and **Log out and delete data** (cookies, cache, web storage).
- Settings are stored locally with `shared_preferences`.

## Project structure

| File | Purpose |
|---|---|
| `lib/url_policy.dart` | all navigation rules |
| `lib/redirect_guard.dart` | redirect-loop protection |
| `lib/dm_screen.dart` | app shell: the two tabs, navigation pill, settings, back button |
| `lib/instagram_tab.dart` | one Instagram WebView: URL rules, errors, cosmetics, picker & permissions |
| `lib/settings.dart`, `lib/settings_screen.dart` | settings model, storage and UI |
| `lib/media_pick_request.dart` | maps `accept="…"` to the right system picker |
| `lib/nav_bar.dart`, `lib/nav_tabs.dart`, `lib/username_dialog.dart` | bottom navigation |
| `lib/viewer_account.dart` | reads only the logged-in username and profile-picture URL (the one JS exception) |
| `lib/header_reveal.dart` | hide/show the inbox header on scroll |
| `lib/native_bridge.dart` + `MainActivity.kt` | small Android platform channel |
| `assets/icon/icon.svg` | app icon source |

Only Android and iOS are supported (the desktop/web folders were removed).

## Tools

1. Flutter (stable) – `brew install --cask flutter` or https://docs.flutter.dev/get-started/install
2. Android Studio (Android SDK, platform 36, build-tools)
3. `flutter doctor` – fix everything it reports for Android

## Run & test

```bash
flutter pub get
flutter analyze
flutter test
flutter devices                  # list connected phones / simulators
flutter run -d android           # Android phone connected via USB
flutter run -d "iPhone 17"       # iOS Simulator
```

On an Android phone enable Developer options → USB debugging first.

## Release APK

### 1. Create your own release key (once)

```bash
keytool -genkeypair -v -keystore ~/keys/nofeed-release.jks -alias nofeed \
  -keyalg RSA -keysize 4096 -validity 10000
```

Keep the `.jks` file and its password safe (password manager + backup).
If you lose it, you can't install updates over the existing app.

### 2. Create `android/key.properties` (ignored by git)

```properties
storePassword=<your password>
keyPassword=<your password>
keyAlias=nofeed
storeFile=/Users/<you>/keys/nofeed-release.jks
```

### 3. Build and install

```bash
flutter build apk --release
flutter install --release
```

The APK is in `build/app/outputs/flutter-apk/app-release.apk`. Without
`key.properties` the release build stops with an error – it never falls back
to the debug key. An AAB for Google Play is only relevant with Meta's permission
(see `COMPLIANCE.md`).

## iPhone (free, via Xcode)

Requirements: Mac with Xcode 26+, an Apple ID, iPhone with a cable.

1. On the iPhone: Settings → Privacy & Security → **Developer Mode** → on (restart).
2. Open the project in Xcode and set your team once:
   ```bash
   open ios/Runner.xcworkspace
   ```
   Runner target → Signing & Capabilities → Team: your Apple ID (Personal Team).
   If Xcode says the bundle ID `com.martinbartko.nofeed` is unavailable, add a
   suffix (e.g. `com.martinbartko.nofeed.dev`).
3. Build and install a release build:
   ```bash
   flutter run --release -d <your iPhone name>
   ```
4. First launch only: Settings → General → VPN & Device Management → trust
   your developer certificate.

With a free Apple ID the app **expires after 7 days** – just run step 3 again.
A paid Apple Developer Program membership (99 $/year) extends this to one year.

### iOS specifics

- WebKit (WKWebView) is used, as required by App Store guideline 2.5.6.
- Swipe from the left edge to go back (there is no Back button on iOS).
- Photos/videos: WebKit shows its own menu (photo library, camera, files).
  The photo library uses the system picker without photo permission.
- Camera/microphone: WebKit asks "instagram.com wants to use…", then iOS asks
  once for the app permission (texts in `ios/Runner/Info.plist`).
- Privacy manifest: `ios/Runner/PrivacyInfo.xcprivacy` (no tracking, no data
  collected); Flutter and all plugins ship their own manifests.

## App icon

The icon (petrol square with a chat bubble) is our own design, deliberately
unlike Instagram's logo. Android uses a vector adaptive icon
(`res/drawable/ic_launcher_foreground.xml`, also used as the Android 13 themed
icon). PNGs for older Android and iOS were rendered from `assets/icon/icon.svg`
with ImageMagick, e.g.:

```bash
magick -background none -density 72 assets/icon/icon.svg -resize 1024x1024 -alpha remove -alpha off icon-1024.png
```

## Known limitations

- **Instagram can change its website at any time.** Then the URL filter or
  the cosmetic CSS may stop working; update `lib/url_policy.dart` /
  `lib/cosmetic_css.dart`. Changing the look of someone else's website is a
  grey zone.
- "Log in with Facebook" opens in the system browser (facebook.com is not on
  the allow-list), so log in with your Instagram username and password.
- No push notifications (out of scope by design).
- Camera/microphone access is decided by the main-frame URL, because neither
  `webview_flutter_android` nor `webview_flutter_wkwebview` exposes the
  requesting origin. The main frame is always Instagram (`UrlPolicy`).
- iOS: "hide content in recent apps" is Android-only (`FLAG_SECURE`).
- iOS: `target="_blank"` links first arrive as a non-main-frame request and
  are then re-checked as a main-frame load, so they still follow `UrlPolicy`;
  plain `http://` links of that kind are ignored instead of opening in Safari.
- "Log out and delete data" logs you out on this device only. To end the
  session everywhere use Instagram → Accounts Center → Where you're logged in.
- Not intended for Google Play / App Store without Meta's written permission –
  see `COMPLIANCE.md`.
