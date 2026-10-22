import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pomo/models/remote_session.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/pages/timer/view/remote_session_presence_banner.dart';
import 'package:pomo/services/remote_session_service.dart';

class MockTimerCubit extends MockCubit<TimerState> implements TimerCubit {}

void main() {
  group('RemoteSessionPresenceBanner', () {
    late TimerCubit timerCubit;

    setUp(() {
      timerCubit = MockTimerCubit();
      when(() => timerCubit.state).thenReturn(const TimerState());
      RemoteSessionService().remoteSessionNotifier.value = null;
    });

    testWidgets('renders nothing when no remote session exists',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: timerCubit,
            child: const Scaffold(
              body: RemoteSessionPresenceBanner(),
            ),
          ),
        ),
      );

      expect(find.textContaining('is focusing'), findsNothing);
    });

    testWidgets('renders device name and time when remote session is active',
        (tester) async {
      RemoteSessionService().remoteSessionNotifier.value = RemoteSession(
        deviceId: 'dev_remote_1',
        deviceName: 'Mobile',
        status: 'running',
        lap: 'work',
        lapNumber: 1,
        remainingSeconds: 1440,
        totalSeconds: 1500,
        tagName: 'Sleep & Rest',
        tagIcon: '😴',
        taskTitle: 'Relaxation',
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: timerCubit,
            child: const Scaffold(
              body: RemoteSessionPresenceBanner(),
            ),
          ),
        ),
      );

      expect(find.text('Mobile is focusing'), findsOneWidget);
      expect(find.text('24:00'), findsOneWidget);
      expect(
        find.textContaining('😴 Sleep & Rest • Relaxation'),
        findsOneWidget,
      );
    });

    testWidgets('hides banner when local timer is running', (tester) async {
      when(() => timerCubit.state).thenReturn(
        const TimerState(
          status: TimerStatus.running,
          duration: Duration(seconds: 15),
        ),
      );

      RemoteSessionService().remoteSessionNotifier.value = RemoteSession(
        deviceId: 'dev_remote_1',
        deviceName: 'Mobile',
        status: 'running',
        lap: 'work',
        lapNumber: 1,
        remainingSeconds: 1440,
        totalSeconds: 1500,
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: timerCubit,
            child: const Scaffold(
              body: RemoteSessionPresenceBanner(),
            ),
          ),
        ),
      );

      expect(find.textContaining('is focusing'), findsNothing);
    });

    testWidgets('shows Take Over Back when local timer has paused progress',
        (tester) async {
      when(() => timerCubit.state).thenReturn(
        const TimerState(
          duration: Duration(seconds: 120),
        ),
      );

      final session = RemoteSession(
        deviceId: 'dev_remote_1',
        deviceName: 'Mobile',
        status: 'running',
        lap: 'work',
        lapNumber: 1,
        remainingSeconds: 1380,
        totalSeconds: 1500,
        updatedAt: DateTime.now(),
      );
      RemoteSessionService().remoteSessionNotifier.value = session;

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: timerCubit,
            child: const Scaffold(
              body: RemoteSessionPresenceBanner(),
            ),
          ),
        ),
      );

      expect(find.text('Take Over Back'), findsOneWidget);

      await tester.tap(find.text('Take Over Back'));
      verify(() => timerCubit.adoptRemoteSession(session)).called(1);
    });
  });
}
