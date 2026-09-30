import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/chat_wallpaper.dart';
import 'package:nofeed/chat_wallpaper_store.dart';
import 'package:nofeed/chat_wallpaper_tile.dart';
import 'package:nofeed/settings.dart';
import 'package:nofeed/settings_screen.dart';

/// Store without the native side: picking "saves" a photo at once.
class FakeWallpaperStore extends ChatWallpaperStore {
  FakeWallpaperStore([Set<String> saved = const {}]) : _saved = {...saved};

  final Set<String> _saved;
  final List<String> picked = [];
  final List<String> removed = [];
  bool pickSucceeds = true;

  @override
  Set<String> get keys => _saved;

  @override
  Future<bool> pick(String key) async {
    picked.add(key);
    if (!pickSucceeds) return false;
    _saved.add(key);
    notifyListeners();
    return true;
  }

  @override
  Future<void> remove(String key) async {
    removed.add(key);
    _saved.remove(key);
    notifyListeners();
  }

  @override
  Future<Uint8List?> bytes(String key) async => null;
}

void main() {
  const ig = 'https://www.instagram.com';

  group('chatWallpaperKey', () {
    test('is the chat id', () {
      expect(chatWallpaperKey('$ig/direct/t/1234567890/'), '1234567890');
      expect(chatWallpaperKey('$ig/direct/t/abc_DEF-1?x=1'), 'abc_DEF-1');
    });

    test('null for other pages and for unsafe ids', () {
      expect(chatWallpaperKey('$ig/direct/inbox/'), isNull);
      expect(chatWallpaperKey('$ig/direct/t/'), isNull);
      expect(chatWallpaperKey(null), isNull);
      expect(chatWallpaperKey('$ig/direct/t/..%2F..%2Fx/'), isNull);
      expect(chatWallpaperKey('$ig/direct/t/a"b/'), isNull);
      expect(chatWallpaperKey('$ig/direct/t/${'1' * 65}/'), isNull);
    });

    test('a chat can never take the key of the default background', () {
      expect(chatWallpaperKey('$ig/direct/t/default/'), isNull);
    });
  });

  group('resolveWallpaperKey', () {
    const chat = '$ig/direct/t/42/';

    test('the own background of a chat wins over the default', () {
      expect(resolveWallpaperKey(chat, {'42', defaultWallpaperKey}), '42');
    });

    test('falls back to the default, then to none', () {
      expect(resolveWallpaperKey(chat, {defaultWallpaperKey, '7'}), defaultWallpaperKey);
      expect(resolveWallpaperKey(chat, {'7'}), isNull);
      expect(resolveWallpaperKey(chat, const {}), isNull);
    });

    test('only chats have a background', () {
      expect(resolveWallpaperKey('$ig/direct/inbox/', {defaultWallpaperKey}), isNull);
      expect(resolveWallpaperKey('$ig/martin/', {defaultWallpaperKey}), isNull);
      expect(resolveWallpaperKey(null, {defaultWallpaperKey}), isNull);
    });
  });

  group('scripts', () {
    const photo = 'QUJDRA==';

    test('install puts the photo behind the message list of that key only', () {
      final script = installWallpaperScript('42', photo);
      expect(script, contains('nofeed-wallpaper-42'));
      expect(script, contains('html[data-nofeed-wallpaper="42"] [data-pagelet="IGDMessagesList"]'));
      expect(script, contains('url(data:image/jpeg;base64,$photo)'));
    });

    test('install rejects anything that could break out of the CSS', () {
      expect(() => installWallpaperScript('4"2', photo), throwsArgumentError);
      expect(() => installWallpaperScript('42', "x');alert(1);('"), throwsArgumentError);
      expect(() => installWallpaperScript('42', ''), throwsArgumentError);
    });

    test('select sets the key and the dim colour', () {
      final script = selectWallpaperScript('default', background: '#0c1014', dim: 0.35);
      expect(script, contains("setAttribute('data-nofeed-wallpaper', 'default')"));
      expect(script, contains('rgba(12,16,20,0.35)'));
    });

    test('select clamps the dimming and validates its input', () {
      expect(
        selectWallpaperScript('42', background: '#ffffff', dim: 5),
        contains('rgba(255,255,255,0.80)'),
      );
      expect(
        selectWallpaperScript('42', background: '#ffffff', dim: -1),
        contains('rgba(255,255,255,0.00)'),
      );
      expect(() => selectWallpaperScript('42', background: 'red;x', dim: 0.3), throwsArgumentError);
      expect(
        () => selectWallpaperScript("4'2", background: '#ffffff', dim: 0.3),
        throwsArgumentError,
      );
    });

    test('select sets black or white text, or leaves Instagram\'s colour', () {
      String script(bool? dark) =>
          selectWallpaperScript('42', background: '#0c1014', dim: 0.2, darkText: dark);
      expect(script(true), contains("setProperty('--nofeed-wallpaper-text', '0, 0, 0')"));
      expect(script(false), contains("setProperty('--nofeed-wallpaper-text', '255, 255, 255')"));
      expect(script(null), contains("removeProperty('--nofeed-wallpaper-text')"));
    });

    test('select without a key removes the background', () {
      expect(
        selectWallpaperScript(null, background: '#000000', dim: 0),
        contains("removeAttribute('data-nofeed-wallpaper')"),
      );
    });

    test('the scripts only write: they read nothing from the page', () {
      final scripts = [
        installWallpaperScript('42', photo),
        selectWallpaperScript('42', background: '#0c1014', dim: 0.3),
        selectWallpaperScript(null, background: '#0c1014', dim: 0.3),
      ];
      for (final script in scripts) {
        for (final forbidden in [
          'innerText',
          'innerHTML',
          'cookie',
          'localStorage',
          'fetch(',
          'XMLHttpRequest',
          'postMessage',
          'querySelector',
        ]) {
          expect(script.contains(forbidden), isFalse, reason: forbidden);
        }
      }
    });
  });

  group('wallpaperNeedsDarkText', () {
    const dark = '#0c1014';
    const light = '#ffffff';

    test('black text on a light photo, white text on a dark one', () {
      expect(
        wallpaperNeedsDarkText(photo: (r: 240, g: 230, b: 220), background: dark, dim: 0),
        isTrue,
      );
      expect(
        wallpaperNeedsDarkText(photo: (r: 20, g: 30, b: 40), background: dark, dim: 0),
        isFalse,
      );
    });

    test('picks the colour with the higher contrast for mid-tones', () {
      // Mid grey: black text has a higher contrast than white.
      expect(
        wallpaperNeedsDarkText(photo: (r: 128, g: 128, b: 128), background: dark, dim: 0),
        isTrue,
      );
      expect(
        wallpaperNeedsDarkText(photo: (r: 90, g: 90, b: 90), background: dark, dim: 0),
        isFalse,
      );
    });

    test('dimming counts: a light photo dimmed with the dark page colour needs white text', () {
      const photo = (r: 200, g: 190, b: 180);
      expect(wallpaperNeedsDarkText(photo: photo, background: dark, dim: 0.2), isTrue);
      expect(wallpaperNeedsDarkText(photo: photo, background: dark, dim: 0.8), isFalse);
    });

    test('in the light theme dimming makes the background lighter', () {
      const photo = (r: 60, g: 60, b: 60);
      expect(wallpaperNeedsDarkText(photo: photo, background: light, dim: 0), isFalse);
      expect(wallpaperNeedsDarkText(photo: photo, background: light, dim: 0.8), isTrue);
    });

    test('rejects a malformed page colour', () {
      expect(
        () => wallpaperNeedsDarkText(photo: (r: 0, g: 0, b: 0), background: 'red', dim: 0),
        throwsArgumentError,
      );
    });
  });

  group('averageColorOf', () {
    // 4×4 PNGs filled with rgb(240,230,220) and rgb(10,20,30).
    const lightPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAEAQMAAACTPww9AAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAAGUExURfDm3P///3tdspoAAAABYktHRAH/Ai3eAAAAB3RJTUUH6gkeCAsVRue8AQAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAyNi0wOS0zMFQwODoxMToyMSswMDowMGOpkXEAAAAldEVYdGRhdGU6bW9kaWZ5ADIwMjYtMDktMzBUMDg6MTE6MjErMDA6MDAS9CnNAAAAKHRFWHRkYXRlOnRpbWVzdGFtcAAyMDI2LTA5LTMwVDA4OjExOjIxKzAwOjAwReEIEgAAAAtJREFUCNdjYIAAAAAIAAEvIN0xAAAAAElFTkSuQmCC';
    const darkPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAEAQMAAACTPww9AAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAAGUExURQoUHv///yHkrVUAAAABYktHRAH/Ai3eAAAAB3RJTUUH6gkeCAsVRue8AQAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAyNi0wOS0zMFQwODoxMToyMSswMDowMGOpkXEAAAAldEVYdGRhdGU6bW9kaWZ5ADIwMjYtMDktMzBUMDg6MTE6MjErMDA6MDAS9CnNAAAAKHRFWHRkYXRlOnRpbWVzdGFtcAAyMDI2LTA5LTMwVDA4OjExOjIxKzAwOjAwReEIEgAAAAtJREFUCNdjYIAAAAAIAAEvIN0xAAAAAElFTkSuQmCC';

    testWidgets('reads the average colour of a photo', (tester) async {
      final light = await tester.runAsync(
        () => ChatWallpaperStore.averageColorOf(base64Decode(lightPng)),
      );
      final dark = await tester.runAsync(
        () => ChatWallpaperStore.averageColorOf(base64Decode(darkPng)),
      );
      expect(light, (r: 240, g: 230, b: 220));
      expect(dark, (r: 10, g: 20, b: 30));
    });

    testWidgets('null for something that is not an image', (tester) async {
      final result = await tester.runAsync(
        () => ChatWallpaperStore.averageColorOf(Uint8List.fromList([1, 2, 3, 4])),
      );
      expect(result, isNull);
    });
  });

  group('ChatWallpaperTile', () {
    Future<void> pump(WidgetTester tester, ChatWallpaperStore store, {VoidCallback? onPicked}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatWallpaperTile(
              store: store,
              wallpaperKey: defaultWallpaperKey,
              title: 'Pozadie chatov',
              emptySubtitle: 'Vyber fotku.',
              onPicked: onPicked,
            ),
          ),
        ),
      );
    }

    testWidgets('tap picks a photo, then the bin removes it', (tester) async {
      final store = FakeWallpaperStore();
      var pickedCalls = 0;
      await pump(tester, store, onPicked: () => pickedCalls++);
      expect(find.text('Vyber fotku.'), findsOneWidget);
      expect(find.byTooltip('Odstrániť pozadie'), findsNothing);

      await tester.tap(find.text('Pozadie chatov'));
      await tester.pumpAndSettle();
      expect(store.picked, [defaultWallpaperKey]);
      expect(pickedCalls, 1);
      expect(find.textContaining('Vlastná fotka'), findsOneWidget);

      await tester.tap(find.byTooltip('Odstrániť pozadie'));
      await tester.pumpAndSettle();
      expect(store.removed, [defaultWallpaperKey]);
      expect(find.text('Vyber fotku.'), findsOneWidget);
    });

    testWidgets('a cancelled picker changes nothing', (tester) async {
      final store = FakeWallpaperStore()..pickSucceeds = false;
      var pickedCalls = 0;
      await pump(tester, store, onPicked: () => pickedCalls++);
      await tester.tap(find.text('Pozadie chatov'));
      await tester.pumpAndSettle();
      expect(pickedCalls, 0);
      expect(find.text('Vyber fotku.'), findsOneWidget);
    });
  });

  group('settings', () {
    testWidgets('the dimming slider appears once a background exists and is saved', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = FakeWallpaperStore();
      AppSettings? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            initial: const AppSettings(),
            onChanged: (s) => changed = s,
            onLogout: () async {},
            wallpapers: store,
          ),
        ),
      );
      expect(find.text('Pozadie chatov'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);

      await tester.tap(find.text('Pozadie chatov'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);

      await tester.drag(find.byType(Slider), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(changed, isNotNull);
      expect(changed!.wallpaperDim, greaterThan(defaultWallpaperDim));
      expect(changed!.wallpaperDim, lessThanOrEqualTo(maxWallpaperDim));
    });

    test('dimming is part of the settings', () {
      expect(const AppSettings().wallpaperDim, defaultWallpaperDim);
      expect(const AppSettings().copyWith(wallpaperDim: 0.6).wallpaperDim, 0.6);
      expect(
        const AppSettings().copyWith(wallpaperDim: 0.6).copyWith(allowStories: false).wallpaperDim,
        0.6,
      );
    });
  });
}
