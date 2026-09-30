import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/nav_bar.dart';
import 'package:nofeed/nav_tabs.dart';
import 'package:nofeed/username_dialog.dart';

void main() {
  testWidgets('bar has Home, Messages and Profile and reports taps', (tester) async {
    final taps = <NavTab>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NoFeedNavBar(active: NavTab.messages, onTap: taps.add),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Domov'), findsOneWidget);
    expect(find.bySemanticsLabel('Správy'), findsOneWidget);
    expect(find.bySemanticsLabel('Profil'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Správy')),
      isSemantics(label: 'Správy', isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Profil')),
      isSemantics(label: 'Profil', isSelected: false),
    );
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Profil'));
    await tester.tap(find.bySemanticsLabel('Domov'));
    await tester.tap(find.bySemanticsLabel('Správy'));
    await tester.pumpAndSettle(); // let the highlight animation finish
    expect(taps, [NavTab.profile, NavTab.home, NavTab.messages]);
  });

  testWidgets('the highlight can be dragged to another item', (tester) async {
    final taps = <NavTab>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NoFeedNavBar(active: NavTab.home, onTap: taps.add),
          ),
        ),
      ),
    );
    final from = tester.getCenter(find.bySemanticsLabel('Domov'));
    final to = tester.getCenter(find.bySemanticsLabel('Profil'));
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveTo(to);
    await tester.pump();
    expect(taps, isEmpty); // only chosen when the finger lifts
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, [NavTab.profile]);
  });

  test('positionAt maps the finger to the nearest items', () {
    const w = NoFeedNavBar.itemWidth;
    expect(NoFeedNavBar.positionAt(0), 0);
    expect(NoFeedNavBar.positionAt(w / 2), 0);
    expect(NoFeedNavBar.positionAt(NoFeedNavBar.contentWidth - w / 2), 2);
    expect(NoFeedNavBar.positionAt(10000), 2);
    expect(NoFeedNavBar.positionAt(NoFeedNavBar.contentWidth / 2), closeTo(1, 0.001));
  });

  testWidgets('long-press on Profile opens settings', (tester) async {
    var longPresses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NoFeedNavBar(
              active: NavTab.messages,
              onTap: (_) {},
              onLongPressProfile: () => longPresses++,
            ),
          ),
        ),
      ),
    );
    await tester.longPress(find.bySemanticsLabel('Profil'));
    expect(longPresses, 1);
  });

  testWidgets('profile picture falls back to an icon if it fails to load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NoFeedNavBar(
              active: NavTab.profile,
              onTap: (_) {},
              // Tests have no network: the image fails and the icon is shown.
              avatarUrl: Uri.parse('https://scontent.cdninstagram.com/a.jpg'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.account_circle), findsOneWidget);
  });

  group('username dialog', () {
    Future<void> openDialog(WidgetTester tester, void Function(String?) onResult) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(await showUsernameDialog(context)),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('rejects an invalid name and accepts a valid one', (tester) async {
      String? result;
      await openDialog(tester, (r) => result = r);

      await tester.enterText(find.byType(TextField), 'bad name!');
      await tester.tap(find.text('Uložiť'));
      await tester.pump();
      expect(find.textContaining('Len písmená'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '@Martin.B');
      await tester.tap(find.text('Uložiť'));
      await tester.pumpAndSettle();
      expect(result, 'martin.b');
    });

    testWidgets('cancel returns null', (tester) async {
      var closed = false;
      String? result = 'unset';
      await openDialog(tester, (r) {
        closed = true;
        result = r;
      });
      await tester.tap(find.text('Zrušiť'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNull);
    });
  });
}
