import 'package:dropit_app/widget/dropit_connection_help.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Dropit help opens, explains local network, and closes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDropitConnectionHelp(context),
              child: const Text('Help'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    expect(find.text('Connect your devices'), findsOneWidget);
    expect(find.textContaining('same Wi-Fi'), findsOneWidget);
    expect(find.textContaining('53318'), findsOneWidget);
    expect(find.textContaining('224.0.0.168'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Connect your devices'), findsNothing);
  });
}
