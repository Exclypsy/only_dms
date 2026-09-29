# Compliance checklist – NoFeed

Legend: ✅ done · ⚠️ partially / risk · ❌ not done yet

_State after phase 3 (Android + iOS), 29 September 2026._

## Security & privacy (CLAUDE.md §4)

| Item | Status | Note |
|---|---|---|
| No reading/storing/logging of password, cookies, tokens, messages, URL history | ✅ | App code never reads page content; URLs are only evaluated, never stored or logged. |
| No backend, analytics, ad SDKs, crash reporting | ✅ | Dependencies: `webview_flutter`, `webview_flutter_android`, `webview_flutter_wkwebview`, `url_launcher`, `shared_preferences` (all flutter.dev). |
| Injected JS is cosmetic only | ⚠️ | Cosmetic script (`lib/cosmetic_css.dart`) only writes a `<style>` and `data-nofeed-*` attributes. **One approved exception** (CLAUDE.md §4, 29 Sep 2026): `lib/viewer_username.dart` reads only the logged-in username from the inbox header via `runJavaScriptReturningResult` (no JavaScriptChannel), validated, stored locally, deleted on logout. Both scripts are checked by tests for forbidden APIs. |
| No `JavaScriptChannel` / `addJavascriptInterface` | ✅ | The platform channel (`MethodChannel`) is Flutter ↔ Android only; web content cannot reach it. |
| No TLS bypass | ✅ | No SSL error handler is set → both plugins reject invalid certificates. No custom trust manager, no `NSAllowsArbitraryLoads` / `NSAppTransportSecurity` exceptions. |
| Cleartext disabled | ✅ | `android:usesCleartextTraffic="false"`; Instagram over `http` is blocked in `url_policy.dart`. |
| `allowBackup=false` + data extraction rules | ✅ | `res/xml/data_extraction_rules.xml` excludes everything from cloud backup and device transfer. |
| WebView without file/content access | ✅ | `setAllowFileAccess(false)`, `setAllowContentAccess(false)`, geolocation off. File upload uses picker URIs, not file access. |
| Safe Browsing on | ✅ | Manifest meta-data `android.webkit.WebView.EnableSafeBrowsing=true`. |
| WebView debugging only in debug | ✅ | Android `enableDebugging(kDebugMode)`, iOS `setInspectable(kDebugMode)`. |
| R8 / minification in release | ✅ | `isMinifyEnabled` + `isShrinkResources`. |
| No unnecessary permissions | ✅ | `INTERNET`, `CAMERA`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS` (WebRTC audio, no dialog). No storage, location, contacts, `QUERY_ALL_PACKAGES`. |
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
| No automation, scraping, private API, credential collection | ✅ | |
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
| Privacy manifest (`PrivacyInfo.xcprivacy`) | ✅ | App: no tracking, no collected data, no required-reason APIs in own code. Included in the bundle together with manifests of Flutter, `webview_flutter_wkwebview`, `url_launcher_ios`, `shared_preferences_foundation` (UserDefaults, reason 1C8F.1). |
| App Privacy label ("Data Not Collected") | ⚠️ | True for the app itself. Before a real submission, re-check Apple's guidance on data entered into third-party web content inside a web view. |
| Xcode 26 / iOS 26 SDK builds | ✅ | Built with Xcode 27 (iOS deployment target 15.0). |
| 2.3.1 no hidden features | ✅ | All settings are visible in the Settings screen. |
| EU trader status (DSA), 99 $/year program | ❌ | Only relevant if publishing. Personal install via Xcode is free (7-day expiry). |
