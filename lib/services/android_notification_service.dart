import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/helpers/hourly_alarm_schedule.dart';
import 'package:pomo/helpers/notification_helper.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/services/app_navigation_controller.dart';

class AndroidNotificationService {
  factory AndroidNotificationService() => _instance;
  AndroidNotificationService._internal();
  static final AndroidNotificationService _instance =
      AndroidNotificationService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.recoskyler.pomo/timer_notification');
  bool _isServiceActive = false;
  TimerCubit? _timerCubit;

  /// Parses a native `onNotificationTap` argument into a [NotificationAction].
  @visibleForTesting
  static NotificationAction? actionFromNotificationTap(Object? arguments) {
    final payload = arguments as String?;
    return NotificationHelper.parsePayload(payload);
  }

  /// Pulls and clears any cold-start launch payload stored in MainActivity.
  @visibleForTesting
  static Future<String?> pullPendingNotificationPayload(
    MethodChannel channel,
  ) async {
    return channel.invokeMethod<String>('getPendingNotificationPayload');
  }

  /// Pulls queued one-tap shade writes stored natively when Dart was dead.
  @visibleForTesting
  static Future<List<String>> pullPendingInstantHourlyWrites(
    MethodChannel channel,
  ) async {
    final raw = await channel.invokeMethod<List<dynamic>>(
      'getPendingInstantHourlyWrites',
    );
    if (raw == null) {
      return const [];
    }
    return raw.whereType<String>().toList();
  }

  /// Pulls pending payload and parses it (used by init + unit tests).
  @visibleForTesting
  static Future<NotificationAction?> actionFromPendingPull(
    MethodChannel channel,
  ) async {
    final payload = await pullPendingNotificationPayload(channel);
    return actionFromNotificationTap(payload);
  }

  /// Arguments passed to native `showHourlyNotification` for a shade reminder.
  ///
  /// Hourly uses notification ID 1002 / channel `hourly_tracker_v2` and must not
  /// start or replace the timer FGS (ID 1001).
  @visibleForTesting
  static Map<String, Object?> hourlyNotificationArgs({
    required int hour,
    required DateTime date,
  }) {
    return {
      'title': NotificationHelper.hourlyNotificationTitle(),
      'text': NotificationHelper.hourlyNotificationBody(hour),
      'payload': NotificationHelper.hourlyPayload(hour: hour, date: date),
    };
  }

  /// Backward-compatible alias used by older tests / call sites.
  @visibleForTesting
  static Map<String, Object?> hourlyStartForegroundArgs({
    required int hour,
    required DateTime date,
  }) {
    return {
      ...hourlyNotificationArgs(hour: hour, date: date),
      'isRunning': false,
      'isHourly': true,
    };
  }

  void init(TimerCubit timerCubit) {
    if (kIsWeb || !Platform.isAndroid) return;
    _timerCubit = timerCubit;
    _channel
      ..invokeMethod<bool>('requestPermission')
      ..setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onPlay':
            if (_timerCubit?.state.status != TimerStatus.running) {
              _timerCubit?.start();
            }
          case 'onPause':
            if (_timerCubit?.state.status == TimerStatus.running) {
              _timerCubit?.stop();
            }
          case 'onStop':
            _timerCubit?.reset();
          case 'onNotificationTap':
            await _routeNotificationPayload(call.arguments);
        }
      });
    // Cold start: pull after the handler is registered (do not rely on a
    // fixed native delay alone).
    unawaited(_consumePendingLaunchPayload());
    unawaited(_consumePendingInstantWrites());
  }

  Future<void> _routeNotificationPayload(Object? arguments) async {
    final action = actionFromNotificationTap(arguments);
    await AppNavigationController.instance.handleNotificationAction(action);
  }

  Future<void> _consumePendingLaunchPayload() async {
    try {
      final payload = await pullPendingNotificationPayload(_channel);
      if (payload == null || payload.isEmpty) {
        return;
      }
      // Give navigator / HomeShell a beat on cold start before dialog.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _routeNotificationPayload(payload);
    } catch (_) {
      // Ignore channel exceptions
    }
  }

  Future<void> _consumePendingInstantWrites() async {
    try {
      final payloads = await pullPendingInstantHourlyWrites(_channel);
      for (final payload in payloads) {
        await _routeNotificationPayload(payload);
      }
    } catch (_) {
      // Ignore channel exceptions
    }
  }

  /// Arguments passed to native `startForeground` / `updateNotification`.
  /// Formatted according to Android Material Notification UX standards.
  @visibleForTesting
  static Map<String, Object?> timerNotificationArgs({
    required TimerState timerState,
    required SettingsState settingsState,
  }) {
    final formattedTime = DurationHelper.negativeFormat(
      duration: timerState.duration,
      lap: timerState.lap,
      settingsState: settingsState,
    );

    final isRunning = timerState.status == TimerStatus.running;
    final lapText = timerState.lap == TimerLap.work
        ? 'Work Session'
        : (timerState.lap == TimerLap.shortBreak
            ? 'Short Break'
            : 'Long Break');

    final primaryTag = timerState.activeTags.isNotEmpty
        ? '${timerState.activeTags.first.icon} '
            '${timerState.activeTags.first.name}'
        : null;

    final taskTitle = (timerState.activeTask?.title.isNotEmpty ?? false)
        ? timerState.activeTask!.title
        : null;

    final contentTitle = isRunning ? formattedTime : '$formattedTime (Paused)';

    final subText = timerState.lapNumber > 0
        ? 'Focus Timer • Lap #${timerState.lapNumber}'
        : 'Focus Timer';

    final String contentText;
    if (primaryTag != null && taskTitle != null) {
      contentText = '$primaryTag • $taskTitle';
    } else if (primaryTag != null) {
      contentText = '$primaryTag • $lapText';
    } else if (taskTitle != null) {
      contentText = '$taskTitle • $lapText';
    } else {
      contentText = lapText;
    }

    final lapSuffix =
        timerState.lapNumber > 0 ? ' (Lap #${timerState.lapNumber})' : '';
    final bigTextLines = [
      'Activity: ${primaryTag ?? "None selected"}',
      'Task: ${taskTitle ?? "No task selected"}',
      'Session: $lapText$lapSuffix',
    ];
    final bigText = bigTextLines.join('\n');

    return {
      'title': contentText,
      'text': contentTitle,
      'subText': subText,
      'bigText': bigText,
      'isRunning': isRunning,
      'isHourly': false,
    };
  }

  Future<void> updateTimerState({
    required TimerState timerState,
    required SettingsState settingsState,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    final isRunning = timerState.status == TimerStatus.running;
    final isZero = timerState.duration == Duration.zero;

    if (!isRunning && isZero) {
      if (_isServiceActive) {
        _isServiceActive = false;
        try {
          await _channel.invokeMethod<bool>('stopForeground');
        } catch (_) {}
      }
      return;
    }

    final args = timerNotificationArgs(
      timerState: timerState,
      settingsState: settingsState,
    );

    try {
      if (!_isServiceActive && (isRunning || !isZero)) {
        _isServiceActive = true;
        await _channel.invokeMethod<bool>('startForeground', args);
      } else if (_isServiceActive) {
        await _channel.invokeMethod<bool>('updateNotification', args);
      }
    } catch (e) {
      // Ignore channel exceptions if native service fails
    }
  }

  /// Updates the notification using raw display strings without requiring cubit state.
  Future<void> updateNotificationRaw({
    required String title,
    required String text,
    required bool isRunning,
    String? subText,
    String? bigText,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final args = {
        'title': title,
        'text': text,
        'isRunning': isRunning,
        'isHourly': false,
        'subText': subText,
        'bigText': bigText,
      };
      if (!_isServiceActive) {
        _isServiceActive = true;
        await _channel.invokeMethod<bool>('startForeground', args);
      } else {
        await _channel.invokeMethod<bool>('updateNotification', args);
      }
    } catch (_) {
      // Ignore channel exceptions
    }
  }

  Future<void> stopForeground() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      _isServiceActive = false;
      await _channel.invokeMethod<bool>('stopForeground');
    } catch (e) {
      // Ignore channel exceptions
    }
  }

  /// Posts the hourly shade notification (native ID 1002). Does not start FGS.
  Future<void> showHourlyReminderNotification({
    required int hour,
    required DateTime date,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>(
        'showHourlyNotification',
        hourlyNotificationArgs(hour: hour, date: date),
      );
    } catch (e) {
      // Ignore channel exceptions
    }
  }

  /// Channel args for scheduling the next exact hourly alarm.
  @visibleForTesting
  static Map<String, Object?> scheduleNextHourlyAlarmArgs(
    DateTime now, {
    required bool enableTimeTracker,
    required bool enableQuietHours,
    required String quietHoursStart,
    required String quietHoursEnd,
  }) {
    final triggerAt = nextHourBoundary(now);
    return {
      'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
      'enableTimeTracker': enableTimeTracker,
      'enableQuietHours': enableQuietHours,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
    };
  }

  /// Decommissioned: hourly reminders are disabled across all devices.
  /// Invokes native scheduleNextHourlyAlarm with enableTimeTracker=false to cancel alarms.
  Future<void> scheduleNextHourlyAlarm({DateTime? now}) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>(
        'scheduleNextHourlyAlarm',
        scheduleNextHourlyAlarmArgs(
          now ?? DateTime.now(),
          enableTimeTracker: false,
          enableQuietHours: false,
          quietHoursStart: '00:00',
          quietHoursEnd: '00:00',
        ),
      );
    } catch (_) {
      // Ignore channel exceptions
    }
  }

  /// Cancels pending exact hourly alarms.
  Future<void> cancelHourlyAlarms() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('cancelHourlyAlarms');
    } catch (_) {
      // Ignore channel exceptions
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final result = await _channel
          .invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
