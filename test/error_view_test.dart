import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/error_view.dart';

void main() {
  testWidgets('offline error shows message and retry works', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorView(kind: LoadErrorKind.offline, onRetry: () => retried++),
      ),
    );
    expect(find.text('Si offline'), findsOneWidget);
    await tester.tap(find.text('Skúsiť znova'));
    expect(retried, 1);
  });

  testWidgets('every error kind renders a retry button', (tester) async {
    for (final kind in LoadErrorKind.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: ErrorView(kind: kind, onRetry: () {}),
        ),
      );
      expect(find.text('Skúsiť znova'), findsOneWidget, reason: kind.name);
    }
  });

  testWidgets('settings are reachable from the error screen', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorView(
          kind: LoadErrorKind.generic,
          onRetry: () {},
          onOpenSettings: () => opened++,
        ),
      ),
    );
    await tester.tap(find.text('Nastavenia NoFeed'));
    expect(opened, 1);
  });
}
