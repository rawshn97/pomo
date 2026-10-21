import 'package:flutter_test/flutter_test.dart';
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

    test('sessionEndpoint derives correctly from notion proxy', () {
      Prefs.notionProxyUrl = 'https://pomo-focus-sand.vercel.app/api/notion/';
      final service = RemoteSessionService();
      expect(
        service.sessionEndpoint,
        equals('https://pomo-focus-sand.vercel.app/api/session'),
      );
    });

    test('wsEndpoint derives wss protocol from https session endpoint', () {
      Prefs.notionProxyUrl = 'https://sync.rawshn.com/api/notion/';
      final service = RemoteSessionService();
      expect(
        service.wsEndpoint,
        equals('wss://sync.rawshn.com/ws'),
      );
    });

    test('wsEndpoint derives ws protocol from http local dev endpoint', () {
      Prefs.notionProxyUrl = 'http://127.0.0.1:8787/api/notion/';
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
  });
}
