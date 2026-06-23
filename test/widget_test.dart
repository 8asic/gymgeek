import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gymgeek/main.dart';

void main() {
  testWidgets('app renders splash/loading screen on cold start',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const GymGeekApp());

    // _AuthGate FutureBuilder is in waiting state → loading splash
    expect(find.text('GymGeek'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('app navigates to login when not logged in',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'is_logged_in': false});
    await tester.pumpWidget(const GymGeekApp());
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
  });
}
