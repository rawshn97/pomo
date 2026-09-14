import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/notification_helper.dart';
import 'package:pomo/services/app_navigation_controller.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppNavigationController.handleNotificationAction', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
      AppNavigationController.instance.tabIndex.value = null;
    });

    tearDown(() {
      AppNavigationController.instance.tabIndex.value = null;
    });

    test('OpenTrackerAction sets tabIndex to 1 only', () async {
      await AppNavigationController.instance.handleNotificationAction(
        const OpenTrackerAction(),
      );
      expect(AppNavigationController.instance.tabIndex.value, 1);
    });

    test('FocusMainWindowAction sets tabIndex to 0', () async {
      await AppNavigationController.instance.handleNotificationAction(
        const FocusMainWindowAction(),
      );
      expect(AppNavigationController.instance.tabIndex.value, 0);
    });

    test('HourlyInstantWriteAction opens Time Log tab without writing',
        () async {
      await AppNavigationController.instance.handleNotificationAction(
        HourlyInstantWriteAction(
          hour: 14,
          date: DateTime(2026, 8, 17),
        ),
      );

      expect(AppNavigationController.instance.tabIndex.value, 1);
      expect(Prefs.hourlyLogs, isEmpty);
    });

    test('HourlyLogAction opens Time Log tab without a dialog', () async {
      await AppNavigationController.instance.handleNotificationAction(
        HourlyLogAction(
          hour: 14,
          date: DateTime(2026, 8, 17),
        ),
      );

      expect(AppNavigationController.instance.tabIndex.value, 1);
    });
  });
}
