import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/web.dart';
import 'package:pomo/helpers/hourly_log_writer.dart';
import 'package:pomo/helpers/notification_helper.dart';
import 'package:pomo/helpers/sound_helper.dart';
import 'package:pomo/services/android_notification_service.dart';
import 'package:pomo/services/web_pwa_service.dart';
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
  static DateTime? _lastHandledHour;
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static void startHourlyTrackerLoop() {
    _hourlyCheckTimer?.cancel();
    // Anchor to the launch hour so starting the app does not immediately fire
    // a reminder; the first crossing into a new hour does.
    _lastHandledHour = DateTime.now();
    _hourlyCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndTriggerHourlyReminder();
    });
    // Exact AlarmManager is the source of truth when the process is killed;
    // Timer.periodic above is only an in-process backup while alive.
    unawaited(AndroidNotificationService().scheduleNextHourlyAlarm());
  }

  static Future<void> _checkAndTriggerHourlyReminder() async {
    if (!Prefs.enableTimeTracker) return;

    final now = DateTime.now();
    // Catch-up trigger: fires on the first tick of a new hour no matter how
    // late that tick lands (App Nap or sleep can delay it past minute 0-1).
    if (!NotificationHelper.crossedHourBoundary(
      now: now,
      lastHandled: _lastHandledHour,
    )) {
      return;
    }
    // Mark handled before any awaits so slow audio/notification calls cannot
    // double-fire the same hour.
    _lastHandledHour = now;

    if (Prefs.enableQuietHours &&
        SoundHelper.isQuietHours(
          start: Prefs.quietHoursStart,
          end: Prefs.quietHoursEnd,
          now: now,
        )) {
      unawaited(HourlyLogWriter.pullThenReconcileResting(now: now));
      return;
    }

    // Remind the user to log the block that just finished, not the one that
    // just started (at 15:0x that is 14:00-15:00).
    final block = NotificationHelper.completedHourBlock(now);
    Logger().d(
      'HookHelper: Triggering hourly check-in for completed hour '
      '${block.hour} (${block.date})',
    );

    // 1. Show native foreground notification on Android
    try {
      await AndroidNotificationService().showHourlyReminderNotification(
        hour: block.hour,
        date: block.date,
      );
    } catch (e) {
      Logger().w('HookHelper android notification failed: $e');
    }

    // 3. Show browser notification on Web PWA
    if (kIsWeb) {
      try {
        WebPwaService().showNotification(
          NotificationHelper.hourlyNotificationTitle(),
          NotificationHelper.hourlyNotificationBody(block.hour),
        );
      } catch (e) {
        Logger().w('HookHelper web notification failed: $e');
      }
    }

    // 4. Play chime/beep audio
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/digital_beep.wav'));
    } catch (e) {
      Logger().w('HookHelper audio chime failed: $e');
    }

    // 5. Keep exact alarm pointed at the next hour (native also reschedules
    // on fire; this covers the in-process path and settings flips).
    unawaited(AndroidNotificationService().scheduleNextHourlyAlarm(now: now));
  }
}
