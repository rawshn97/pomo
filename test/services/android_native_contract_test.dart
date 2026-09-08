import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/services/android_notification_service.dart';

/// Host contract between Dart [AndroidNotificationService] and
/// `MainActivity.kt`. Device integration (Doze / OEM) remains residual QA.
void main() {
  const channelName = 'com.recoskyler.pomo/timer_notification';

  const dartToNativeMethods = <String>[
    'requestPermission',
    'areNotificationsEnabled',
    'isIgnoringBatteryOptimizations',
    'requestIgnoreBatteryOptimizations',
    'getPendingNotificationPayload',
    'getPendingInstantHourlyWrites',
    'startForeground',
    'showHourlyNotification',
    'updateNotification',
    'stopForeground',
    'scheduleNextHourlyAlarm',
    'cancelHourlyAlarms',
  ];

  late String mainActivity;
  late String dartService;
  late String timerService;

  setUpAll(() {
    mainActivity = File(
      'android/app/src/main/kotlin/com/recoskyler/MainActivity.kt',
    ).readAsStringSync();
    dartService = File(
      'lib/services/android_notification_service.dart',
    ).readAsStringSync();
    timerService = File(
      'android/app/src/main/kotlin/com/recoskyler/pomo/TimerForegroundService.kt',
    ).readAsStringSync();
  });

  test('Dart and native share the timer_notification MethodChannel name', () {
    expect(mainActivity, contains('"$channelName"'));
    expect(dartService, contains("'$channelName'"));
  });

  test('MainActivity handles every Dart-invoked MethodChannel method', () {
    final handlerStart = mainActivity.indexOf('setMethodCallHandler');
    expect(handlerStart, greaterThan(0));
    final handler = mainActivity.substring(handlerStart);
    final handled = RegExp(r'"([A-Za-z]+)"\s*->')
        .allMatches(handler)
        .map((match) => match.group(1)!)
        .toSet();
    expect(handled, containsAll(dartToNativeMethods));
  });

  test('Dart AndroidNotificationService invokes the same native methods', () {
    for (final method in dartToNativeMethods) {
      expect(
        dartService,
        contains("'$method'"),
        reason: 'Dart must invoke native `$method`',
      );
    }
  });

  test('timer FGS is 1001 and hourly shade is 1002', () {
    expect(timerService, contains('TIMER_NOTIFICATION_ID = 1001'));
    expect(timerService, contains('HOURLY_NOTIFICATION_ID = 1002'));
    expect(dartService, contains('ID 1002'));
    expect(dartService, contains('ID 1001'));
  });

  test('hourly notification args match native call.argument keys', () {
    final args = AndroidNotificationService.hourlyNotificationArgs(
      hour: 14,
      date: DateTime(2026, 8, 12),
    );
    expect(args.keys, containsAll(<String>['title', 'text', 'payload']));
    expect(mainActivity, contains('call.argument<String>("title")'));
    expect(mainActivity, contains('call.argument<String>("text")'));
    expect(mainActivity, contains('call.argument<String>("payload")'));
  });

  test('hourly alarm args match native call.argument keys', () {
    final args = AndroidNotificationService.scheduleNextHourlyAlarmArgs(
      DateTime(2026, 8, 12, 14, 37),
      enableTimeTracker: true,
      enableQuietHours: true,
      quietHoursStart: '23:00',
      quietHoursEnd: '07:00',
    );
    expect(
      args.keys,
      containsAll(<String>[
        'triggerAtMillis',
        'enableTimeTracker',
        'enableQuietHours',
        'quietHoursStart',
        'quietHoursEnd',
      ]),
    );
    expect(
      mainActivity,
      contains('call.argument<Boolean>("enableTimeTracker")'),
    );
    expect(
      mainActivity,
      contains('call.argument<Boolean>("enableQuietHours")'),
    );
    expect(mainActivity, contains('call.argument<String>("quietHoursStart")'));
    expect(mainActivity, contains('call.argument<String>("quietHoursEnd")'));
    expect(mainActivity, contains('call.argument<Number>("triggerAtMillis")'));
  });

  test('native timer actions still call back onPlay onPause onStop', () {
    expect(dartService, contains("'onPlay'"));
    expect(dartService, contains("'onPause'"));
    expect(dartService, contains("'onStop'"));
    expect(dartService, contains("'onNotificationTap'"));
    expect(mainActivity, contains('invokeMethod(action, null)'));
    expect(mainActivity, contains('invokeMethod("onNotificationTap"'));
  });
}
