import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Prefs.hourlyLogsRevision', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
      Prefs.hourlyLogsRevision.value = 0;
    });

    test('bumps when hourlyLogs is assigned', () {
      final before = Prefs.hourlyLogsRevision.value;
      Prefs.hourlyLogs = [
        HourlyLog(
          id: 'hlog_test',
          dateStr: '2026-09-14',
          hour: 14,
          tagId: 'tag_deep_work',
          tagName: 'Deep Work',
          tagIcon: '🧠',
          tagColorHex: '#34A853',
          durationMinutes: 25,
          loggedAt: DateTime.utc(2026, 9, 14, 14),
        ),
      ];
      expect(Prefs.hourlyLogsRevision.value, before + 1);
      expect(Prefs.hourlyLogs, hasLength(1));
    });

    test('bumps when replaceHourlyLogsForHour writes', () async {
      final before = Prefs.hourlyLogsRevision.value;
      await Prefs.replaceHourlyLogsForHour('2026-09-14', 15, [
        HourlyLog(
          id: 'hlog_replace',
          dateStr: '2026-09-14',
          hour: 15,
          tagId: 'tag_admin',
          tagName: 'Admin & Errands',
          tagIcon: '📝',
          tagColorHex: '#78909C',
          durationMinutes: 10,
          loggedAt: DateTime.utc(2026, 9, 14, 15),
        ),
      ]);
      expect(Prefs.hourlyLogsRevision.value, before + 1);
    });
  });
}
