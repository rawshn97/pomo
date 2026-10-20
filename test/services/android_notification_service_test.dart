import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/notification_helper.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/services/android_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidNotificationService notification tap', () {
    test('onNotificationTap routes hourly payload via parsePayload', () {
      final action = AndroidNotificationService.actionFromNotificationTap(
        'hourly:14:2026-08-12',
      );
      expect(action, isA<HourlyLogAction>());
      final hourly = action! as HourlyLogAction;
      expect(hourly.hour, 14);
      expect(hourly.date, DateTime(2026, 8, 12));
    });

    test('actionFromNotificationTap returns null for empty payload', () {
      expect(
        AndroidNotificationService.actionFromNotificationTap(null),
        isNull,
      );
      expect(AndroidNotificationService.actionFromNotificationTap(''), isNull);
    });

    test('onNotificationTap routes hourly action suffixes', () {
      expect(
        AndroidNotificationService.actionFromNotificationTap(
          'hourly:14:2026-08-12:log_work',
        ),
        isA<HourlyInstantWriteAction>(),
      );
      expect(
        AndroidNotificationService.actionFromNotificationTap(
          'hourly:14:2026-08-12:switch_tag',
        ),
        isA<HourlyLogAction>(),
      );
      expect(
        AndroidNotificationService.actionFromNotificationTap(
          'hourly:14:2026-08-12:open_grid',
        ),
        isA<OpenTrackerAction>(),
      );
    });
  });

  group('AndroidNotificationService pending pull', () {
    const channel = MethodChannel('com.recoskyler.pomo/timer_notification');

    late List<String> channelCalls;
    String? pendingPayload;

    setUp(() {
      channelCalls = [];
      pendingPayload = 'hourly:14:2026-08-12';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        channelCalls.add(call.method);
        if (call.method == 'getPendingNotificationPayload') {
          final value = pendingPayload;
          pendingPayload = null;
          return value;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('actionFromPendingPull routes and clears pending payload', () async {
      final action =
          await AndroidNotificationService.actionFromPendingPull(channel);
      expect(action, isA<HourlyLogAction>());
      final hourly = action! as HourlyLogAction;
      expect(hourly.hour, 14);
      expect(hourly.date, DateTime(2026, 8, 12));
      expect(
        channelCalls,
        contains('getPendingNotificationPayload'),
      );

      final second =
          await AndroidNotificationService.actionFromPendingPull(channel);
      expect(second, isNull);
    });

    test('actionFromPendingPull returns null when native has none', () async {
      pendingPayload = null;
      final action =
          await AndroidNotificationService.actionFromPendingPull(channel);
      expect(action, isNull);
    });

    test('pullPendingInstantHourlyWrites drains queued log_work payloads',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        channelCalls.add(call.method);
        if (call.method == 'getPendingInstantHourlyWrites') {
          return ['hourly:14:2026-08-12:log_work'];
        }
        return null;
      });

      final payloads =
          await AndroidNotificationService.pullPendingInstantHourlyWrites(
        channel,
      );
      expect(payloads, ['hourly:14:2026-08-12:log_work']);
      expect(channelCalls, contains('getPendingInstantHourlyWrites'));
    });
  });

  group('AndroidNotificationService hourly notification args', () {
    test('includes pomo payload for completed hour block', () {
      final args = AndroidNotificationService.hourlyNotificationArgs(
        hour: 14,
        date: DateTime(2026, 8, 12),
      );
      expect(args['payload'], 'hourly:14:2026-08-12');
      expect(args['title'], 'Time Tracker: Check-in Required');
      expect(
        args['text'],
        'Log what you did between 14:00 and 15:00.',
      );
    });

    test('hourlyStartForegroundArgs keeps isHourly for legacy callers', () {
      final args = AndroidNotificationService.hourlyStartForegroundArgs(
        hour: 14,
        date: DateTime(2026, 8, 12),
      );
      expect(args['isHourly'], isTrue);
      expect(args['isRunning'], isFalse);
      expect(args['payload'], 'hourly:14:2026-08-12');
    });
  });

  group('AndroidNotificationService timer notification args', () {
    const settingsState = SettingsState();

    const testTag = TrackerTag(
      id: 'tag_sleep',
      name: 'Sleep & Rest',
      icon: '😴',
      colorHex: '#5C6BC0',
    );

    const testTask = NotionTask(
      id: 'task_123',
      title: 'Design system review',
      timeHours: 1,
      timeMinutes: 30,
    );

    test('formats running timer with active tag and task', () {
      const timerState = TimerState(
        status: TimerStatus.running,
        duration: Duration(seconds: 20),
        lapNumber: 1,
        activeTags: [testTag],
        activeTask: testTask,
      );

      final args = AndroidNotificationService.timerNotificationArgs(
        timerState: timerState,
        settingsState: settingsState,
      );

      expect(args['title'], '😴 Sleep & Rest • Design system review');
      expect(args['text'], '24:40');
      expect(args['subText'], 'Focus Timer • Lap #1');
      expect(args['isRunning'], isTrue);
      expect(args['isHourly'], isFalse);

      final bigText = args['bigText']! as String;
      expect(bigText, contains('Activity: 😴 Sleep & Rest'));
      expect(bigText, contains('Task: Design system review'));
      expect(bigText, contains('Session: Work Session (Lap #1)'));
    });

    test('formats paused timer with tag and no task', () {
      const timerState = TimerState(
        duration: Duration(seconds: 20),
        lapNumber: 2,
        activeTags: [testTag],
      );

      final args = AndroidNotificationService.timerNotificationArgs(
        timerState: timerState,
        settingsState: settingsState,
      );

      expect(args['title'], '😴 Sleep & Rest • Work Session');
      expect(args['text'], '24:40 (Paused)');
      expect(args['subText'], 'Focus Timer • Lap #2');
      expect(args['isRunning'], isFalse);

      final bigText = args['bigText']! as String;
      expect(bigText, contains('Activity: 😴 Sleep & Rest'));
      expect(bigText, contains('Task: No task selected'));
      expect(bigText, contains('Session: Work Session (Lap #2)'));
    });

    test('formats running timer with default fallback when no tag or task', () {
      const timerState = TimerState(
        status: TimerStatus.running,
      );

      final args = AndroidNotificationService.timerNotificationArgs(
        timerState: timerState,
        settingsState: settingsState,
      );

      expect(args['title'], 'Work Session');
      expect(args['text'], '25:00');
      expect(args['subText'], 'Focus Timer');
      expect(args['isRunning'], isTrue);

      final bigText = args['bigText']! as String;
      expect(bigText, contains('Activity: None selected'));
      expect(bigText, contains('Task: No task selected'));
    });
  });
}
