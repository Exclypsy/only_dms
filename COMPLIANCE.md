# Compliance checklist – OnlyDMs

Legend: ✅ done · ⚠️ partially / risk · ❌ not done yet

_State after phase 1 (Android MVP), 29 September 2026._

## Security & privacy (CLAUDE.md §4)

| Item | Status | Note |
|---|---|---|
| No reading/storing/logging of password, cookies, tokens, messages, URL history | ✅ | App code never reads page content; URLs are only evaluated, never stored or logged. |
| No backend, analytics, ad SDKs, crash reporting | ✅ | Dependencies: `webview_flutter`, `webview_flutter_android`, `url_launcher` (all flutter.dev). |
| Injected JS is cosmetic only | ✅ | `lib/cosmetic_css.dart` – inserts a `<style>` element only. |
| No `JavaScriptChannel` / `addJavascriptInterface` | ✅ | |
| No TLS bypass | ✅ | No SSL error handler is set → `webview_flutter_android` cancels on SSL errors. No custom trust manager. |
| Cleartext disabled | ✅ | `android:usesCleartextTraffic="false"`; Instagram over `http` is blocked in `url_policy.dart`. |
| `allowBackup=false` + data extraction rules | ✅ | `res/xml/data_extraction_rules.xml` excludes everything from cloud backup and device transfer. |
| WebView without file/content access | ✅ | `setAllowFileAccess(false)`, `setAllowContentAccess(false)`, geolocation off. |
| Safe Browsing on | ✅ | Manifest meta-data `android.webkit.WebView.EnableSafeBrowsing=true`. |
| WebView debugging only in debug | ✅ | `AndroidWebViewController.enableDebugging(kDebugMode)`. |
| R8 / minification in release | ✅ | `isMinifyEnabled` + `isShrinkResources`. |
| No unnecessary permissions | ✅ | Only `INTERNET` (+ AndroidX-internal `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`). |
| `INTERNET` in main manifest | ✅ | |
| Own release keystore, never debug key | ✅ | Release build fails without `android/key.properties`. You still need to create your key (README). |
| `key.properties`, `*.jks`, `local.properties` in `.gitignore` | ✅ | Verified with `git check-ignore`. |
| User agent unchanged | ✅ | |

## Instagram terms & Meta brand (§5)

| Item | Status | Note |
|---|---|---|
| No automation, scraping, private API, credential collection | ✅ | |
| Name without "Instagram/Insta/Gram/IG" | ✅ | "OnlyDMs", `applicationId` `com.martinbartko.onlydms`. |
| Name – other trademarks | ⚠️ | "Only…" pattern may remind reviewers of the OnlyFans brand. Fine for personal use; reconsider before any store release. |
| No Instagram logo or look-alike icon | ❌ | Still the default Flutter icon – own icon pending (must not resemble Instagram's). |
| Disclaimer "not affiliated with Meta" | ✅ | README, PRIVACY.md. Add to the in-app About/Settings in phase 2. |
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
| 4.1(c) / 5.2.1 (no third-party brand) | ⚠️ | Name OK; icon pending. |
| 5.1.1(i) privacy policy link in app | ❌ | Phase 2/3. |
| 5.1.1(v) way to log out / delete data | ❌ | Phase 2 button "Log out and delete data". |
| 2.5.6 WebKit | ✅ | `webview_flutter_wkwebview` uses WKWebView. |
| iOS privacy manifest, usage descriptions | ❌ | Phase 3. |
