import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimerCubit', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    tearDown(() {
      Prefs.enableTimeTracker = false;
      Prefs.enableNotionSync = false;
      Prefs.notionApiKey = '';
      Prefs.notionProxyUrl = '';
      Prefs.pendingTimeLogs = [];
    });

    test('initial state has stopped status, zero duration, and work lap', () {
      final cubit = TimerCubit();
      expect(cubit.state, const TimerState());
      cubit.close();
    });

    blocTest<TimerCubit, TimerState>(
      'start emits running status and updates Prefs',
      build: TimerCubit.new,
      act: (cubit) => cubit.start(),
      expect: () => [
        const TimerState(status: TimerStatus.running),
      ],
      verify: (cubit) {
        expect(Prefs.timerStatus, TimerStatus.running);
      },
    );

    blocTest<TimerCubit, TimerState>(
      'stop emits stopped status and updates Prefs',
      build: () {
        final cubit = TimerCubit()..start();
        return cubit;
      },
      act: (cubit) => cubit.stop(),
      expect: () => [
        const TimerState(),
      ],
      verify: (cubit) {
        expect(Prefs.timerStatus, TimerStatus.stopped);
      },
    );

    blocTest<TimerCubit, TimerState>(
      'reset returns state to default TimerState and resets Prefs',
      build: () {
        final cubit = TimerCubit()..start();
        return cubit;
      },
      act: (cubit) => cubit.reset(),
      expect: () => [
        const TimerState(),
      ],
      verify: (cubit) {
        expect(Prefs.duration, Duration.zero);
      },
    );

    blocTest<TimerCubit, TimerState>(
      'toggle switches from stopped to running and back',
      build: TimerCubit.new,
      act: (cubit) => cubit
        ..toggle()
        ..toggle(),
      expect: () => [
        const TimerState(status: TimerStatus.running),
        const TimerState(),
      ],
    );

    blocTest<TimerCubit, TimerState>(
      'tick increments duration when status is running',
      build: () {
        final cubit = TimerCubit()..start();
        return cubit;
      },
      act: (cubit) => cubit.tick(const SettingsState()),
      expect: () => [
        const TimerState(
          status: TimerStatus.running,
          duration: Duration(seconds: 1),
        ),
      ],
    );

    blocTest<TimerCubit, TimerState>(
      'tick emits full duration before lap transition when lap completes '
      '(autoAdvance false)',
      build: () {
        Prefs.duration = const Duration(minutes: 9, seconds: 59);
        Prefs.timerStatus = TimerStatus.running;
        return TimerCubit();
      },
      act: (cubit) => cubit.tick(
        const SettingsState(workMinutes: 10),
      ),
      expect: () => [
        const TimerState(
          status: TimerStatus.running,
          duration: Duration(minutes: 10),
        ),
        const TimerState(
          duration: Duration(minutes: 10),
        ),
        const TimerState(
          lap: TimerLap.shortBreak,
          lapNumber: 1,
        ),
      ],
    );

    blocTest<TimerCubit, TimerState>(
      'tick emits full duration before lap transition when lap completes '
      '(autoAdvance true)',
      build: () {
        Prefs.duration = const Duration(minutes: 9, seconds: 59);
        Prefs.timerStatus = TimerStatus.running;
        return TimerCubit();
      },
      act: (cubit) => cubit.tick(
        const SettingsState(workMinutes: 10, autoAdvance: true),
      ),
      expect: () => [
        const TimerState(
          status: TimerStatus.running,
          duration: Duration(minutes: 10),
        ),
        const TimerState(
          status: TimerStatus.running,
          lap: TimerLap.shortBreak,
          lapNumber: 1,
        ),
      ],
    );

    test('checkAndPlaySound respects enableSound and quiet hours', () {
      final cubit = TimerCubit();
      const disabledSound = SettingsState(enableSound: false);
      expect(
        cubit.checkAndPlaySound(settingsState: disabledSound),
        isFalse,
      );

      const quietState = SettingsState(
        quietHoursStart: '22:00',
        quietHoursEnd: '06:00',
      );
      final nightTime = DateTime(2026, 7, 13, 23, 30);
      expect(
        cubit.checkAndPlaySound(
          settingsState: quietState,
          now: nightTime,
        ),
        isFalse,
      );

      const quietHoursDisabled = SettingsState(
        enableQuietHours: false,
        quietHoursStart: '22:00',
        quietHoursEnd: '06:00',
      );
      expect(
        cubit.checkAndPlaySound(
          settingsState: quietHoursDisabled,
          now: nightTime,
        ),
        isTrue,
      );

      final dayTime = DateTime(2026, 7, 13, 14);
      expect(
        cubit.checkAndPlaySound(
          settingsState: quietState,
          now: dayTime,
        ),
        isTrue,
      );
    });

    test('stop credits selected tags once using duration delta', () async {
      Prefs.enableTimeTracker = true;
      Prefs.enableNotionSync = false;
      const deepWork = TrackerTag(
        id: 'tag_deep_work',
        name: 'Deep Work',
        icon: '🧠',
        colorHex: '#34A853',
        isDefault: true,
      );
      final cubit = TimerCubit(clock: () => DateTime(2026, 9, 3, 14, 30))
        ..toggleTag(deepWork)
        ..start()
        ..tick(
          const SettingsState(workMinutes: 50),
          const Duration(minutes: 25),
        )
        ..stop();
      await Future<void>.delayed(Duration.zero);

      expect(Prefs.hourlyLogs, hasLength(1));
      expect(Prefs.hourlyLogs.single.tagId, 'tag_deep_work');
      expect(Prefs.hourlyLogs.single.durationMinutes, 25);
      expect(Prefs.hourlyLogs.single.hour, 14);

      cubit
        ..start()
        ..tick(
          const SettingsState(workMinutes: 50),
          const Duration(minutes: 10),
        )
        ..stop();
      await Future<void>.delayed(Duration.zero);
      expect(Prefs.hourlyLogs.single.durationMinutes, 35);
      await cubit.close();
    });

    test('stop without tags does not write hourly logs', () async {
      Prefs.enableTimeTracker = true;
      Prefs.enableNotionSync = false;
      final cubit = TimerCubit(clock: () => DateTime(2026, 9, 3, 14, 30))
        ..start()
        ..tick(
          const SettingsState(workMinutes: 50),
          const Duration(minutes: 25),
        )
        ..stop();
      await Future<void>.delayed(Duration.zero);
      expect(Prefs.hourlyLogs, isEmpty);
      await cubit.close();
    });

    test('toggleTag is blocked while work lap is running', () {
      const deepWork = TrackerTag(
        id: 'tag_deep_work',
        name: 'Deep Work',
        icon: '🧠',
        colorHex: '#34A853',
        isDefault: true,
      );
      const reading = TrackerTag(
        id: 'tag_reading',
        name: 'Reading & Learning',
        icon: '📚',
        colorHex: '#AB47BC',
        isDefault: true,
      );
      final cubit = TimerCubit()
        ..toggleTag(deepWork)
        ..start();

      expect(cubit.canModifyTags, isFalse);
      expect(cubit.toggleTag(reading), isFalse);
      expect(cubit.state.activeTags, [deepWork]);
      cubit.close();
    });
  });
}
