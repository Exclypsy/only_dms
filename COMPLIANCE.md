# Compliance checklist – NoFeed

Legend: ✅ done · ⚠️ partially / risk · ❌ not done yet

_State after phase 3 (Android + iOS) plus Home tab, notifications with text, instant chats and chat keyboard, 30 September 2026._

## Security & privacy (CLAUDE.md §4)

| Item | Status | Note |
|---|---|---|
| No reading/storing/logging of password, cookies, tokens, messages, URL history | ⚠️ | Password, cookies and tokens are never touched; URLs are only evaluated, never stored or logged. **Approved exceptions for message content** (CLAUDE.md §3/§4, 30 Sep 2026): previews of unread chats for notifications (memory only) and pictures of opened chats for instant opening (private cache folder). Nothing leaves the device. |
| No backend, analytics, ad SDKs, crash reporting | ✅ | Dependencies: `webview_flutter`, `webview_flutter_android`, `webview_flutter_wkwebview`, `url_launcher`, `shared_preferences` (all flutter.dev). |
| Injected JS is cosmetic only | ⚠️ | Cosmetic script (`lib/cosmetic_css.dart`) only writes a `<style>` and `data-nofeed-*` attributes. **Approved read-only exceptions** (CLAUDE.md §4), all via `runJavaScriptReturningResult`, no JavaScriptChannel: (1) 29 Sep 2026, `lib/viewer_account.dart`: the logged-in username (inbox header) and the profile-picture URL – username validated, stored locally, deleted on logout; picture URL accepted only from Instagram's/Facebook's CDN over HTTPS, image kept in memory only. (2) 30 Sep 2026, `lib/unread_notifier.dart`: name and preview of unread chats in the inbox list (max. 10 rows), only with notifications on, memory only. (3) 30 Sep 2026, `lib/chat_snapshot.dart` and `lib/page_placeholder.dart`: a number describing whether the inbox, a chat or the Following feed is drawn (and, for a chat, scrolled to its newest message) – no text; a test checks these scripts for text/storage/network APIs. Scroll behaviour uses the native WebView scroll position, not page JS. |
| No `JavaScriptChannel` / `addJavascriptInterface` | ✅ | The platform channel (`MethodChannel`) is Flutter ↔ Android only; web content cannot reach it. |
| No TLS bypass | ✅ | No SSL error handler is set → both plugins reject invalid certificates. No custom trust manager, no `NSAllowsArbitraryLoads` / `NSAppTransportSecurity` exceptions. |
| Cleartext disabled | ✅ | `android:usesCleartextTraffic="false"`; Instagram over `http` is blocked in `url_policy.dart`. |
| `allowBackup=false` + data extraction rules | ✅ | `res/xml/data_extraction_rules.xml` excludes everything from cloud backup and device transfer. |
| WebView without file/content access | ✅ | `setAllowFileAccess(false)`, `setAllowContentAccess(false)`, geolocation off. File upload uses picker URIs, not file access. |
| Safe Browsing on | ✅ | Manifest meta-data `android.webkit.WebView.EnableSafeBrowsing=true`. |
| WebView debugging only in debug | ✅ | Android `enableDebugging(kDebugMode)`, iOS `setInspectable(kDebugMode)`. |
| R8 / minification in release | ✅ | `isMinifyEnabled` + `isShrinkResources`. |
| No unnecessary permissions | ✅ | `INTERNET`, `CAMERA`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS` (WebRTC audio, no dialog), `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_REMOTE_MESSAGING` (only used when notifications are turned on). No storage, location, contacts, `QUERY_ALL_PACKAGES`. |
| Notifications (CLAUDE.md §3, approved 29/30 Sep 2026) | ⚠️ | Local only, with sender and text read from the unread rows of Instagram's chat list (the title counter of the first version does not exist in the inbox). Memory only, nothing sent anywhere; no background fetching, unofficial API or server; opened conversations are not read. Android: foreground service keeps the page open; lock screen uses `VISIBILITY_PRIVATE` with a neutral public version. iOS: only while the app is open. Depends on Instagram's page layout. A store release would need to justify the foreground service type. |
| Instant chats – pictures of opened chats (CLAUDE.md §3, approved 30 Sep 2026) | ⚠️ | Screenshot of the WebView of a chat the user opened, max. 30 chats, in the private cache folder (`Library/Caches` with complete file protection on iOS, `cacheDir` on Android; never backed up), deleted on logout or when the setting is turned off. File names are validated chat ids (`[A-Za-z0-9_-]`). Chats are never opened in the background. Message content at rest on the device is a deliberate trade-off for speed. |
| Custom chat backgrounds (30 Sep 2026) | ✅ | Photo from the system photo picker (PHPicker / Android Photo Picker, no permission), scaled down, stored only in the app's private folder (`Application Support` excluded from backup on iOS, `filesDir` on Android). Shown as a CSS background; the scripts only write (checked by a test). File names of per-chat backgrounds and chat pictures contain the chat id from the URL; they are deleted on logout. |
| Anonymous mode (30 Sep 2026) | ✅ | CSS only (`anonymousCss`): names get `opacity: 0`, profile pictures a built-in neutral icon; rules apply only while `data-nofeed-anon="1"`. Nothing is read, stored or sent; notifications omit the sender's name while it is on. Not a security boundary – it hides names from people looking at the screen, and depends on Instagram's page structure. |
| Chat keyboard (30 Sep 2026) | ⚠️ | Native only, no JS. iOS: WKWebView's keyboard observers are removed and `inputAccessoryView` of WebKit's content view class (`WKContentView`, looked up by name) is overridden with the public Objective-C runtime API – the same technique as common WebView frameworks, but it relies on WebKit internals and would need to be mentioned in a store review. |
| Camera/mic only for instagram.com + system dialog | ⚠️ | Android: runtime permission dialog; iOS: WebKit prompt + iOS permission dialog. Neither plugin exposes the requesting origin, so the main-frame URL is checked (always Instagram thanks to `UrlPolicy`). If Instagram mobile web never asks for camera/mic, remove these permissions. |
| Photo Picker, no storage permission | ✅ | `ACTION_PICK_IMAGES` (Android 11+ via SDK extension) or `ACTION_OPEN_DOCUMENT`. |
| `FLAG_SECURE` via own platform channel | ✅ | `MainActivity.kt` → `setSecure`; toggle in Settings. |
| `INTERNET` in main manifest | ✅ | |
| Own release keystore, never debug key | ✅ | Release build fails without `android/key.properties`. You still need to create your key (README). |
| `key.properties`, `*.jks`, `local.properties` in `.gitignore` | ✅ | Verified with `git check-ignore`. |
| User agent unchanged | ✅ | |

## Instagram terms & Meta brand (§5)

| Item | Status | Note |
|---|---|---|
| No automation, scraping, private API, credential collection | ⚠️ | No automation, no private API, no extra requests, no credential collection. Reading the previews of unread chats for notifications and keeping pictures of opened chats use only what Instagram already displayed to the user and stay on the device, but they are on the edge of "collecting information" – risk accepted by the owner (CLAUDE.md §5, 30 Sep 2026). |
| Feed, Reels, Explore blocked | ⚠️ | `/reels*`, `/explore*` and the normal home feed stay blocked. The Home tab opens only the "Following" feed `/?variant=following` (approved 30 Sep 2026). |
| Name without "Instagram/Insta/Gram/IG" | ✅ | "NoFeed", `applicationId` / bundle ID `com.martinbartko.nofeed`. |
| No Instagram logo or look-alike icon | ✅ | Own icon: petrol square + white chat bubble (`assets/icon/icon.svg`), no gradient, no camera shape. |
| Disclaimer "not affiliated with Meta" | ✅ | README, PRIVACY.md, in-app Settings → O aplikácii. |
| Grey-zone risk of restyling Instagram documented | ✅ | README → Known limitations. |

## Google Play (§6)

| Item | Status | Note |
|---|---|---|
| "Webviews and Affiliate Spam" policy | ❌ | Blocker. No written permission from Meta → do **not** publish to Play. |
| `targetSdk` ≥ 36 | ✅ | Set explicitly to 36. |
| Closed test 12 testers / 14 days | ❌ | Only relevant if publishing. |
| Privacy policy URL | ⚠️ | Draft in `PRIVACY.md`, not yet published on martinbartko.com. |
| Data safety, content rating, target audience | ❌ | Only relevant if publishing. |
| Sideload distribution (main path) | ✅ | Signed release APK, see README. |

## Apple App Store (§7)

| Item | Status | Note |
|---|---|---|
| 4.2 / 4.2.2 (not just a repackaged website) | ❌ | High risk of rejection – the app is essentially a filtered website. |
| 5.2.2 (third-party service permission) | ❌ | Blocker without Meta's permission. |
| 4.1(c) / 5.2.1 (no third-party brand) | ✅ | Own name and icon. |
| 5.1.1(i) privacy policy link in app | ⚠️ | Privacy summary in Settings; link once PRIVACY.md is published. |
| 5.1.1(v) way to log out / delete data | ✅ | Settings → "Odhlásiť a vymazať dáta". |
| 2.5.6 WebKit | ✅ | `webview_flutter_wkwebview` uses WKWebView. |
| Usage descriptions only for what is used | ✅ | `NSCameraUsageDescription` (photo/video for a message, video calls), `NSMicrophoneUsageDescription` (voice messages, calls, video sound). No photo-library key: WebKit uses the system picker. |
| Privacy manifest (`PrivacyInfo.xcprivacy`) | ✅ | App: no tracking, no collected data; one required-reason API in own code: file timestamps (reason C617.1, pruning old chat pictures inside the app container). Included in the bundle together with manifests of Flutter, `webview_flutter_wkwebview`, `url_launcher_ios`, `shared_preferences_foundation` (UserDefaults, reason 1C8F.1). |
| App Privacy label ("Data Not Collected") | ⚠️ | True for the app itself. Before a real submission, re-check Apple's guidance on data entered into third-party web content inside a web view. |
| Xcode 26 / iOS 26 SDK builds | ✅ | Built with Xcode 27 (iOS deployment target 15.0). |
| 2.3.1 no hidden features | ✅ | All settings are visible in the Settings screen (long-press Profile; a one-time tip explains it). |
| EU trader status (DSA), 99 $/year program | ❌ | Only relevant if publishing. Personal install via Xcode is free (7-day expiry). |
