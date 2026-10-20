import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/time_log_analytics_helper.dart';
import 'package:pomo/models/hourly_log.dart';

HourlyLog _log({
  required String dateStr,
  required int hour,
  required String tagId,
  int minutes = 25,
  String notes = '',
}) {
  return HourlyLog(
    id: 'hlog_${dateStr}_${hour}_$tagId',
    dateStr: dateStr,
    hour: hour,
    tagId: tagId,
    tagName: tagId,
    tagIcon: '💻',
    tagColorHex: '#4285F4',
    notes: notes,
    loggedAt: DateTime.parse('${dateStr}T12:00:00'),
    durationMinutes: minutes,
  );
}

void main() {
  group('TimeLogAnalyticsHelper', () {
    test('excludes auto Resting logs from focus totals', () {
      final logs = [
        _log(
          dateStr: '2026-09-14',
          hour: 2,
          tagId: 'tag_sleep',
          notes: 'Resting',
        ),
        _log(
          dateStr: '2026-09-14',
          hour: 10,
          tagId: 'tag_deep_work',
          minutes: 50,
        ),
      ];

      expect(TimeLogAnalyticsHelper.totalMinutes(logs), 50);
    });

    test('tagBreakdown sorts by minutes descending', () {
      final logs = [
        _log(dateStr: '2026-09-14', hour: 9, tagId: 'tag_coding', minutes: 30),
        _log(
          dateStr: '2026-09-14',
          hour: 10,
          tagId: 'tag_deep_work',
          minutes: 60,
        ),
        _log(dateStr: '2026-09-14', hour: 11, tagId: 'tag_coding', minutes: 15),
      ];

      final breakdown = TimeLogAnalyticsHelper.tagBreakdown(logs);
      expect(breakdown, hasLength(2));
      expect(breakdown.first.tagId, 'tag_deep_work');
      expect(breakdown.first.minutes, 60);
      expect(breakdown.last.tagId, 'tag_coding');
      expect(breakdown.last.minutes, 45);
    });

    test('hourTotals aggregates across the period', () {
      final logs = [
        _log(dateStr: '2026-09-14', hour: 9, tagId: 'tag_coding'),
        _log(dateStr: '2026-09-15', hour: 9, tagId: 'tag_coding'),
        _log(
          dateStr: '2026-09-14',
          hour: 14,
          tagId: 'tag_deep_work',
          minutes: 50,
        ),
      ];

      final totals = TimeLogAnalyticsHelper.hourTotals(logs);
      expect(totals[9], 50);
      expect(totals[14], 50);
    });

    test('computeStreak counts consecutive days with focus time', () {
      final logs = [
        _log(dateStr: '2026-09-12', hour: 9, tagId: 'tag_coding'),
        _log(dateStr: '2026-09-13', hour: 9, tagId: 'tag_coding'),
        _log(dateStr: '2026-09-14', hour: 9, tagId: 'tag_coding'),
      ];

      final streak = TimeLogAnalyticsHelper.computeStreak(
        logs,
        today: DateTime(2026, 9, 14),
      );
      expect(streak, 3);
    });

    test('analyzePeriod returns daily summaries newest first', () {
      final logs = [
        _log(dateStr: '2026-09-13', hour: 9, tagId: 'tag_coding', minutes: 60),
        _log(
          dateStr: '2026-09-14',
          hour: 10,
          tagId: 'tag_deep_work',
          minutes: 30,
        ),
      ];

      final analytics = TimeLogAnalyticsHelper.analyzePeriod(
        logs: logs,
        periodDays: 2,
        today: DateTime(2026, 9, 14),
      );

      expect(analytics.totalMinutes, 90);
      expect(analytics.activeDays, 2);
      expect(analytics.dailySummaries.first.dateStr, '2026-09-14');
      expect(analytics.dailySummaries.last.dateStr, '2026-09-13');
    });

    test('startOfWeekSunday correctly finds Sunday for any day of week', () {
      // 2026-09-13 is Sunday
      final sunday = DateTime(2026, 9, 13, 14, 30);
      final sundayResult = TimeLogAnalyticsHelper.startOfWeekSunday(sunday);
      expect(sundayResult.year, 2026);
      expect(sundayResult.month, 9);
      expect(sundayResult.day, 13);
      expect(sundayResult.hour, 0);
      expect(sundayResult.minute, 0);

      // 2026-09-16 is Wednesday
      final wednesday = DateTime(2026, 9, 16, 9, 15);
      final wedResult = TimeLogAnalyticsHelper.startOfWeekSunday(wednesday);
      expect(wedResult.day, 13);

      // 2026-09-19 is Saturday
      final saturday = DateTime(2026, 9, 19, 23, 59);
      final satResult = TimeLogAnalyticsHelper.startOfWeekSunday(saturday);
      expect(satResult.day, 13);
    });

    test(
      'analyzeDateRange aggregates accurately across custom date boundaries',
      () {
        final logs = [
          _log(
            dateStr: '2026-09-10',
            hour: 8,
            tagId: 'tag_coding',
            minutes: 30,
          ),
          _log(
            dateStr: '2026-09-13',
            hour: 10,
            tagId: 'tag_deep_work',
            minutes: 60,
          ),
          _log(
            dateStr: '2026-09-15',
            hour: 14,
            tagId: 'tag_coding',
            minutes: 45,
          ),
          _log(
            dateStr: '2026-09-20',
            hour: 16,
            tagId: 'tag_reading',
            minutes: 90,
          ),
        ];

        // Filter from Sunday 2026-09-13 to Wednesday 2026-09-16 (4 days)
        final start = DateTime(2026, 9, 13);
        final end = DateTime(2026, 9, 16);
        final analytics = TimeLogAnalyticsHelper.analyzeDateRange(
          logs: logs,
          start: start,
          end: end,
          today: end,
        );

        expect(analytics.periodDays, 4);
        expect(analytics.totalMinutes, 105);
        expect(analytics.activeDays, 2);
        expect(analytics.dailySummaries, hasLength(4));
        expect(analytics.dailySummaries.first.dateStr, '2026-09-16');
        expect(analytics.dailySummaries.last.dateStr, '2026-09-13');
      },
    );
  });
}
