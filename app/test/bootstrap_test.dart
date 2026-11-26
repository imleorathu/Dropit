import 'dart:async';

import 'package:dropit_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup paints immediately and replaces an endless loader with recovery UI', (tester) async {
    final neverCompletes = Completer<Never>();

    await tester.pumpWidget(
      DropitBootstrap(
        args: const [],
        timeout: const Duration(milliseconds: 100),
        initializer: (_) => neverCompletes.future,
      ),
    );

    expect(find.text('Preparing private sharing…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 101));
    await tester.pump();

    expect(find.text('Dropit couldn’t start'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('within 0 seconds'), findsOneWidget);
  });

  testWidgets('startup exceptions expose diagnostics and retry', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      DropitBootstrap(
        args: const [],
        initializer: (_) async {
          attempts++;
          throw StateError('native bootstrap failed');
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Dropit couldn’t start'), findsOneWidget);
    expect(find.textContaining('native bootstrap failed'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(attempts, 2);
  });

  testWidgets('startup shell fits a 320 px mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final neverCompletes = Completer<Never>();

    await tester.pumpWidget(
      DropitBootstrap(
        args: const [],
        timeout: const Duration(minutes: 1),
        initializer: (_) => neverCompletes.future,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Preparing private sharing…'), findsOneWidget);

    neverCompletes.completeError(StateError('test complete'));
    await tester.pump();
  });
}
