import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/screens/dashboard_screen.dart';
import 'package:walkies/theme/app_theme.dart';

import 'screenshots/fakes.dart';

Future<void> _pumpDashboard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: const Scaffold(body: DashboardScreen()),
  ));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the blocker\'s step count when it is higher', (tester) async {
    // App counted 4,850; the phone's sensor (via the blocker) saw 6,200
    installFakes(nativeSteps: 6200);
    await _pumpDashboard(tester);
    expect(find.text('89% of your goal'), findsOneWidget);
    expect(find.text('800 to unlock'), findsOneWidget);
  });

  testWidgets('warns when locks are set but the blocker is off', (tester) async {
    installFakes(blockerEnabled: false);
    await _pumpDashboard(tester);
    expect(find.text('App locking is switched off'), findsOneWidget);
  });

  testWidgets('no warning when the blocker is on', (tester) async {
    installFakes();
    await _pumpDashboard(tester);
    expect(find.text('App locking is switched off'), findsNothing);
  });
}
