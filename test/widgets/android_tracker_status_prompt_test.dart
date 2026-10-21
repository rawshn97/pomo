import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/android_background_prompt.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:pomo/widgets/android_tracker_status_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().init();
    AndroidBackgroundPrompt.dismissedThisSession = false;
  });

  testWidgets('prompts when battery is optimized on Android', (tester) async {
    var requestedBattery = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AndroidTrackerStatusPrompt(
          isAndroidOverride: true,
          trackerEnabled: true,
          isIgnoringBatteryOptimizations: () async => false,
          areNotificationsEnabled: () async => true,
          requestIgnoreBatteryOptimizations: () async {
            requestedBattery = true;
            return true;
          },
          requestNotificationPermission: () async => true,
          child: const Scaffold(body: Text('tracker')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keep focus timer countdowns reliable'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(requestedBattery, isTrue);
    expect(find.text('Keep focus timer countdowns reliable'), findsNothing);
  });

  testWidgets('does not prompt when unrestricted and notifications on',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AndroidTrackerStatusPrompt(
          isAndroidOverride: true,
          trackerEnabled: true,
          isIgnoringBatteryOptimizations: () async => true,
          areNotificationsEnabled: () async => true,
          child: const Scaffold(body: Text('tracker')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keep focus timer countdowns reliable'), findsNothing);
  });
}
