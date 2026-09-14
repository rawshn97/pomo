import 'package:flutter/foundation.dart';
import 'package:pomo/helpers/notification_helper.dart';

/// App-level navigation requests from desktop notification taps, etc.
class AppNavigationController {
  AppNavigationController._();

  static final AppNavigationController instance = AppNavigationController._();

  final ValueNotifier<int?> tabIndex = ValueNotifier<int?>(null);

  /// Handle a parsed notification action: show UI and route as needed.
  Future<void> handleNotificationAction(NotificationAction? action) async {
    if (action == null) {
      return;
    }

    switch (action) {
      case FocusMainWindowAction():
        tabIndex.value = 0;
      case OpenTrackerAction():
        tabIndex.value = 1;
      case HourlyInstantWriteAction():
        tabIndex.value = 1;
      case HourlyLogAction():
        tabIndex.value = 1;
    }
  }
}
