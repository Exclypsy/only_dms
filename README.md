# OnlyDMs

A minimal Android/iOS app that shows only your Instagram direct messages –
no feed, no Reels, no Explore. It is a WebView around `https://www.instagram.com`;
you log in directly on instagram.com and the app never sees your password.

> **Disclaimer:** OnlyDMs is an independent project for Instagram and is not
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
- `lib/cosmetic_css.dart` only hides the Home/Explore/Reels buttons with CSS.

## Tools

1. Flutter (stable) – `brew install --cask flutter` or https://docs.flutter.dev/get-started/install
2. Android Studio (Android SDK, platform 36, build-tools)
3. `flutter doctor` – fix everything it reports for Android

## Run & test

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # debug build on a connected phone / emulator
```

## Release APK

### 1. Create your own release key (once)

```bash
keytool -genkeypair -v -keystore ~/keys/onlydms-release.jks -alias onlydms \
  -keyalg RSA -keysize 4096 -validity 10000
```

Keep the `.jks` file and its password safe (password manager + backup).
If you lose it, you can't install updates over the existing app.

### 2. Create `android/key.properties` (ignored by git)

```properties
storePassword=<your password>
keyPassword=<your password>
keyAlias=onlydms
storeFile=/Users/<you>/keys/onlydms-release.jks
```

### 3. Build and install

```bash
flutter build apk --release
flutter install --release
```

The APK is in `build/app/outputs/flutter-apk/app-release.apk`. Without
`key.properties` the release build stops with an error – it never falls back
to the debug key. AAB (Play) and iOS builds will be documented in later phases.

## Known limitations

- **Instagram can change its website at any time.** Then the URL filter or
  the cosmetic CSS may stop working; update `lib/url_policy.dart` /
  `lib/cosmetic_css.dart`. Changing the look of someone else's website is a
  grey zone.
- "Log in with Facebook" opens in the system browser (facebook.com is not on
  the allow-list), so log in with your Instagram username and password.
- No push notifications (out of scope by design).
- Photo/video upload, camera and microphone come in phase 2.
- Not intended for Google Play / App Store without Meta's written permission –
  see `COMPLIANCE.md`.
