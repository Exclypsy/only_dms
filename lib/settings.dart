import 'package:shared_preferences/shared_preferences.dart';

import 'url_policy.dart';

/// User settings, stored locally on the device only.
class AppSettings {
  const AppSettings({
    this.allowSharedReels = true,
    this.allowStories = true,
    this.hideInRecents = false,
    this.username,
  });

  final bool allowSharedReels;
  final bool allowStories;

  /// Android FLAG_SECURE: hides the app content in the recent-apps overview
  /// (and also blocks screenshots).
  final bool hideInRecents;

  /// The user's own Instagram username, typed in by the user, used only to
  /// build the Profile button URL. Never read from the page.
  final String? username;

  UrlPolicy get urlPolicy =>
      UrlPolicy(allowSharedReels: allowSharedReels, allowStories: allowStories);

  AppSettings copyWith({
    bool? allowSharedReels,
    bool? allowStories,
    bool? hideInRecents,
    String? username,
    bool clearUsername = false,
  }) => AppSettings(
    allowSharedReels: allowSharedReels ?? this.allowSharedReels,
    allowStories: allowStories ?? this.allowStories,
    hideInRecents: hideInRecents ?? this.hideInRecents,
    username: clearUsername ? null : (username ?? this.username),
  );
}

class SettingsStore {
  SettingsStore({SharedPreferencesAsync? prefs}) : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _allowSharedReels = 'allow_shared_reels';
  static const _allowStories = 'allow_stories';
  static const _hideInRecents = 'hide_in_recents';
  static const _username = 'profile_username';

  Future<AppSettings> load() async {
    const defaults = AppSettings();
    return AppSettings(
      allowSharedReels: await _prefs.getBool(_allowSharedReels) ?? defaults.allowSharedReels,
      allowStories: await _prefs.getBool(_allowStories) ?? defaults.allowStories,
      hideInRecents: await _prefs.getBool(_hideInRecents) ?? defaults.hideInRecents,
      username: await _prefs.getString(_username),
    );
  }

  static const _settingsHintShown = 'settings_hint_shown';

  /// Whether the one-time "long-press Profile for settings" tip was shown.
  Future<bool> settingsHintShown() async => await _prefs.getBool(_settingsHintShown) ?? false;

  Future<void> markSettingsHintShown() => _prefs.setBool(_settingsHintShown, true);

  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_allowSharedReels, settings.allowSharedReels);
    await _prefs.setBool(_allowStories, settings.allowStories);
    await _prefs.setBool(_hideInRecents, settings.hideInRecents);
    final username = settings.username;
    if (username == null) {
      await _prefs.remove(_username);
    } else {
      await _prefs.setString(_username, username);
    }
  }
}
