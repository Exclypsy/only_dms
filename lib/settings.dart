import 'package:shared_preferences/shared_preferences.dart';

import 'url_policy.dart';

/// User settings, stored locally on the device only.
class AppSettings {
  const AppSettings({
    this.allowSharedReels = true,
    this.allowStories = true,
    this.hideInRecents = false,
  });

  final bool allowSharedReels;
  final bool allowStories;

  /// Android FLAG_SECURE: hides the app content in the recent-apps overview
  /// (and also blocks screenshots).
  final bool hideInRecents;

  UrlPolicy get urlPolicy =>
      UrlPolicy(allowSharedReels: allowSharedReels, allowStories: allowStories);

  AppSettings copyWith({bool? allowSharedReels, bool? allowStories, bool? hideInRecents}) =>
      AppSettings(
        allowSharedReels: allowSharedReels ?? this.allowSharedReels,
        allowStories: allowStories ?? this.allowStories,
        hideInRecents: hideInRecents ?? this.hideInRecents,
      );
}

class SettingsStore {
  SettingsStore({SharedPreferencesAsync? prefs}) : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _allowSharedReels = 'allow_shared_reels';
  static const _allowStories = 'allow_stories';
  static const _hideInRecents = 'hide_in_recents';

  Future<AppSettings> load() async {
    const defaults = AppSettings();
    return AppSettings(
      allowSharedReels: await _prefs.getBool(_allowSharedReels) ?? defaults.allowSharedReels,
      allowStories: await _prefs.getBool(_allowStories) ?? defaults.allowStories,
      hideInRecents: await _prefs.getBool(_hideInRecents) ?? defaults.hideInRecents,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_allowSharedReels, settings.allowSharedReels);
    await _prefs.setBool(_allowStories, settings.allowStories);
    await _prefs.setBool(_hideInRecents, settings.hideInRecents);
  }
}
