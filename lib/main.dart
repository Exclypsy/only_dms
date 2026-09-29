import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'dm_screen.dart';
import 'native_bridge.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SettingsStore();
  // Fall back to defaults if local storage can't be read.
  final settings = await store.load().catchError((Object _) => const AppSettings());
  // Apply before the first frame so the content is never visible in recents.
  await NativeBridge.setSecure(settings.hideInRecents);
  runApp(NoFeedApp(settings: settings, store: store));
}

class NoFeedApp extends StatelessWidget {
  const NoFeedApp({super.key, required this.settings, required this.store});

  final AppSettings settings;
  final SettingsStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoFeed',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brandColor, surface: lightBackground),
        scaffoldBackgroundColor: lightBackground,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandColor,
          brightness: Brightness.dark,
          surface: darkBackground,
        ),
        scaffoldBackgroundColor: darkBackground,
      ),
      home: DmScreen(initialSettings: settings, store: store),
    );
  }
}
