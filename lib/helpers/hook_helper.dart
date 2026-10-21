import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logger/web.dart';
import 'package:pomo/services/android_notification_service.dart';
import 'package:pomo/singletons/prefs.dart';

enum TriggerMethod {
  get,
  post,
  put,
  patch,
}

mixin HookHelper {
  static Future<void> postWebHook(
    String? urls, {
    TriggerMethod? method = TriggerMethod.post,
    dynamic data,
  }) async {
    if (!Prefs.enableWebhooks) {
      return;
    }
    if (urls == null || urls.isEmpty) {
      return;
    }

    final urlList = urls
        .split(',')
        .where((url) {
          if (url.isEmpty) {
            return false;
          }

          try {
            Uri.parse(url);
            return true;
          } catch (_) {
            return false;
          }
        })
        .map((e) => e.trim())
        .toList();

    for (final url in urlList) {
      try {
        Logger().d('POSTing webhook to $url');

        final dio = Dio();

        final options = RequestOptions(
          method: method.toString().split('.').last.toUpperCase(),
          baseUrl: url,
          data: data,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        );

        await dio.fetch<dynamic>(options);
      } catch (e, s) {
        Logger().e(
          'Failed to ${method.toString().toUpperCase()} webhook to $url',
          error: e,
          stackTrace: s,
        );
      }
    }
  }

  static Timer? _hourlyCheckTimer;

  static void startHourlyTrackerLoop() {
    _hourlyCheckTimer?.cancel();
    _hourlyCheckTimer = null;
    // Decommissioned: hourly check-in reminders have been removed across all
    // platforms. Cancel any active native Android hourly alarms on startup.
    unawaited(AndroidNotificationService().cancelHourlyAlarms());
  }

  static void stopHourlyTrackerLoop() {
    _hourlyCheckTimer?.cancel();
    _hourlyCheckTimer = null;
    unawaited(AndroidNotificationService().cancelHourlyAlarms());
  }
}
