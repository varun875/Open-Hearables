import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:open_hearables/main.dart';
import 'package:open_hearables/services/bluetooth_service.dart';
import 'package:open_hearables/services/equalizer_service.dart';

void main() {
  testWidgets('OpenHearablesApp renders the dashboard shell', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Constructed without init() so no platform channels are touched.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BluetoothService()),
          ChangeNotifierProvider(create: (_) => EqualizerService()),
        ],
        child: const OpenHearablesApp(),
      ),
    );

    expect(find.text('Open Hearables'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Equalizer'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
  });

  testWidgets('switching to the Privacy destination shows the about screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BluetoothService()),
          ChangeNotifierProvider(create: (_) => EqualizerService()),
        ],
        child: const OpenHearablesApp(),
      ),
    );

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();

    expect(find.text('100% Offline & Private'), findsOneWidget);
  });
}
