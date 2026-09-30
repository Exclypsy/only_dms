import 'package:shared_preferences/shared_preferences.dart';

import 'chat_wallpaper.dart';
import 'url_policy.dart';

/// User settings, stored locally on the device only.
class AppSettings {
  const AppSettings({
    this.allowSharedReels = true,
    this.allowStories = true,
    this.hideInRecents = false,
    this.notificationsEnabled = false,
    this.instantChats = true,
    this.wallpaperDim = defaultWallpaperDim,
    this.username,
  });

  final bool allowSharedReels;
  final bool allowStories;

  /// Android FLAG_SECURE: hides the app content in the recent-apps overview
  /// (and also blocks screenshots).
  final bool hideInRecents;

  /// Local notifications about new messages with the sender and the text (see
  /// unread_notifier.dart). Off by default; turning it on asks for permission.
  final bool notificationsEnabled;

  /// Keeps pictures of opened chats on the device so they open instantly the
  /// next time (see chat_snapshot.dart). Turning it off deletes them.
  final bool instantChats;

  /// How strongly a custom chat background is dimmed (see chat_wallpaper.dart).
  final double wallpaperDim;

  /// The user's own Instagram username (detected in the inbox header, see
  /// viewer_account.dart, or typed in), used only for the Profile button.
  final String? username;

  UrlPolicy get urlPolicy =>
      UrlPolicy(allowSharedReels: allowSharedReels, allowStories: allowStories);

  AppSettings copyWith({
    bool? allowSharedReels,
    bool? allowStories,
    bool? hideInRecents,
    bool? notificationsEnabled,
    bool? instantChats,
    double? wallpaperDim,
    String? username,
    bool clearUsername = false,
  }) => AppSettings(
    allowSharedReels: allowSharedReels ?? this.allowSharedReels,
    allowStories: allowStories ?? this.allowStories,
    hideInRecents: hideInRecents ?? this.hideInRecents,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    instantChats: instantChats ?? this.instantChats,
    wallpaperDim: wallpaperDim ?? this.wallpaperDim,
    username: clearUsername ? null : (username ?? this.username),
  );
}

class SettingsStore {
  SettingsStore({SharedPreferencesAsync? prefs}) : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _allowSharedReels = 'allow_shared_reels';
  static const _allowStories = 'allow_stories';
  static const _hideInRecents = 'hide_in_recents';
  static const _notificationsEnabled = 'notifications_enabled';
  static const _instantChats = 'instant_chats';
  static const _wallpaperDim = 'wallpaper_dim';
  static const _username = 'profile_username';

  Future<AppSettings> load() async {
    const defaults = AppSettings();
    return AppSettings(
      allowSharedReels: await _prefs.getBool(_allowSharedReels) ?? defaults.allowSharedReels,
      allowStories: await _prefs.getBool(_allowStories) ?? defaults.allowStories,
      hideInRecents: await _prefs.getBool(_hideInRecents) ?? defaults.hideInRecents,
      notificationsEnabled:
          await _prefs.getBool(_notificationsEnabled) ?? defaults.notificationsEnabled,
      instantChats: await _prefs.getBool(_instantChats) ?? defaults.instantChats,
      wallpaperDim: (await _prefs.getDouble(_wallpaperDim) ?? defaults.wallpaperDim)
          .clamp(0, maxWallpaperDim)
          .toDouble(),
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
    await _prefs.setBool(_notificationsEnabled, settings.notificationsEnabled);
    await _prefs.setBool(_instantChats, settings.instantChats);
    await _prefs.setDouble(_wallpaperDim, settings.wallpaperDim);
    final username = settings.username;
    if (username == null) {
      await _prefs.remove(_username);
    } else {
      await _prefs.setString(_username, username);
    }
  }
}
