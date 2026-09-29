import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'dm_screen.dart';

void main() {
  runApp(const OnlyDmsApp());
}

class OnlyDmsApp extends StatelessWidget {
  const OnlyDmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnlyDMs',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, surface: lightBackground),
        scaffoldBackgroundColor: lightBackground,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
          surface: darkBackground,
        ),
        scaffoldBackgroundColor: darkBackground,
      ),
      home: const DmScreen(),
    );
  }
}
