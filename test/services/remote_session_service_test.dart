import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/services/remote_session_service.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RemoteSessionService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    test('deviceName is non-empty string', () {
      final service = RemoteSessionService();
      expect(service.deviceName, isNotEmpty);
    });

    test('sessionEndpoint defaults to Cloudflare Edge Worker', () {
      final service = RemoteSessionService();
      expect(
        service.sessionEndpoint,
        equals(RemoteSessionService.defaultCloudflareSyncEndpoint),
      );
    });

    test('sessionEndpoint uses Prefs.syncRelayUrl when explicitly set', () {
      Prefs.syncRelayUrl = 'https://sync.rawshn.com/api/session';
      final service = RemoteSessionService();
      expect(
        service.sessionEndpoint,
        equals('https://sync.rawshn.com/api/session'),
      );
    });

    test('wsEndpoint derives wss protocol from https session endpoint', () {
      Prefs.syncRelayUrl = 'https://sync.rawshn.com/api/session';
      final service = RemoteSessionService();
      expect(
        service.wsEndpoint,
        equals('wss://sync.rawshn.com/ws'),
      );
    });

    test('wsEndpoint derives ws protocol from http local dev endpoint', () {
      Prefs.syncRelayUrl = 'http://127.0.0.1:8787/api/session';
      final service = RemoteSessionService();
      expect(
        service.wsEndpoint,
        equals('ws://127.0.0.1:8787/ws'),
      );
    });

    test('deviceId is persisted and stable across calls', () {
      final id1 = Prefs.deviceId;
      final id2 = Prefs.deviceId;
      expect(id1, isNotEmpty);
      expect(id1, equals(id2));
    });

    test(
        'startRepeatingBroadcast and pauseRepeatingBroadcast manage timers cleanly',
        () {
      final service = RemoteSessionService();
      // Should not throw or crash when called with callbacks
      service.startRepeatingBroadcast(
        getTimerState: () => const TimerState(),
        getSettingsState: () => const SettingsState(),
      );
      service.pauseRepeatingBroadcast(
        timerState: const TimerState(duration: Duration(seconds: 30)),
        settingsState: const SettingsState(),
      );
      service.stopRepeatingBroadcast();
    });
  });
}
