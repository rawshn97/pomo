import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/quiet_hours_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/tracker_tag.dart';

void main() {
  group('QuietHoursHelper.isQuietHourIndex', () {
    test('returns false when quiet hours are disabled', () {
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 23,
          enableQuietHours: false,
          start: '23:00',
          end: '07:00',
        ),
        isFalse,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 2,
          enableQuietHours: false,
          start: '23:00',
          end: '07:00',
        ),
        isFalse,
      );
    });

    test('treats overnight window as sleep hours when enabled', () {
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 23,
          enableQuietHours: true,
          start: '23:00',
          end: '07:00',
        ),
        isTrue,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 0,
          enableQuietHours: true,
          start: '23:00',
          end: '07:00',
        ),
        isTrue,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 6,
          enableQuietHours: true,
          start: '23:00',
          end: '07:00',
        ),
        isTrue,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 7,
          enableQuietHours: true,
          start: '23:00',
          end: '07:00',
        ),
        isFalse,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 22,
          enableQuietHours: true,
          start: '23:00',
          end: '07:00',
        ),
        isFalse,
      );
    });

    test('treats same-day window as sleep hours when enabled', () {
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 13,
          enableQuietHours: true,
          start: '12:00',
          end: '14:00',
        ),
        isTrue,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 14,
          enableQuietHours: true,
          start: '12:00',
          end: '14:00',
        ),
        isFalse,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 11,
          enableQuietHours: true,
          start: '12:00',
          end: '14:00',
        ),
        isFalse,
      );
    });
  });

  group('QuietHoursHelper.missingRestingLogs', () {
    const sleep = TrackerTag(
      id: 'tag_sleep',
      name: 'Sleep & Rest',
      icon: '😴',
      colorHex: '#5C6BC0',
      isDefault: true,
    );

    test('returns empty when quiet hours are disabled', () {
      final logs = QuietHoursHelper.missingRestingLogs(
        now: DateTime(2026, 8, 17, 10),
        existing: const [],
        enableQuietHours: false,
        start: '23:00',
        end: '07:00',
      );
      expect(logs, isEmpty);
    });

    test('writes Resting blocks for completed overnight quiet hours', () {
      final logs = QuietHoursHelper.missingRestingLogs(
        now: DateTime(2026, 8, 17, 10),
        existing: const [],
        enableQuietHours: true,
        start: '23:00',
        end: '07:00',
      );
      expect(logs, isNotEmpty);
      expect(
        logs.every((log) => log.tagId == sleep.id && log.tagName == sleep.name),
        isTrue,
      );
      expect(
        logs.map((log) => '${log.dateStr}_${log.hour}'),
        containsAll([
          '2026-08-17_0',
          '2026-08-17_6',
          '2026-08-16_23',
        ]),
      );
      expect(
        logs.map((log) => '${log.dateStr}_${log.hour}'),
        isNot(contains('2026-08-17_7')),
      );
      expect(
        logs.map((log) => '${log.dateStr}_${log.hour}'),
        isNot(contains('2026-08-17_10')),
      );
    });

    test('skips hours that already have a log', () {
      final existing = [
        HourlyLog(
          id: 'hlog_2026-08-17_2_tag_coding',
          dateStr: '2026-08-17',
          hour: 2,
          tagId: 'tag_coding',
          tagName: 'Coding & Dev',
          tagIcon: '💻',
          tagColorHex: '#4285F4',
          loggedAt: DateTime(2026, 8, 17, 2, 5),
        ),
      ];
      final logs = QuietHoursHelper.missingRestingLogs(
        now: DateTime(2026, 8, 17, 10),
        existing: existing,
        enableQuietHours: true,
        start: '23:00',
        end: '07:00',
        daysBack: 1,
      );
      expect(
        logs.map((log) => log.hour),
        isNot(contains(2)),
      );
      expect(logs.map((log) => log.hour), containsAll([0, 1, 3, 6]));
    });
  });
}
