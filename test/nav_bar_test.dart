import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/nav_bar.dart';
import 'package:nofeed/nav_tabs.dart';
import 'package:nofeed/username_dialog.dart';

void main() {
  testWidgets('bar has only Messages and Profile and reports taps', (tester) async {
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
    expect(find.bySemanticsLabel('Správy'), findsOneWidget);
    expect(find.bySemanticsLabel('Profil'), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget); // active = filled
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Profil'));
    await tester.tap(find.bySemanticsLabel('Správy'));
    expect(taps, [NavTab.profile, NavTab.messages]);
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
