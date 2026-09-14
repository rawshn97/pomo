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
            notes: 'Resting'),
        _log(
            dateStr: '2026-09-14',
            hour: 10,
            tagId: 'tag_deep_work',
            minutes: 50),
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
            minutes: 60),
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
        _log(dateStr: '2026-09-14', hour: 9, tagId: 'tag_coding', minutes: 25),
        _log(dateStr: '2026-09-15', hour: 9, tagId: 'tag_coding', minutes: 25),
        _log(
            dateStr: '2026-09-14',
            hour: 14,
            tagId: 'tag_deep_work',
            minutes: 50),
      ];

      final totals = TimeLogAnalyticsHelper.hourTotals(logs);
      expect(totals[9], 50);
      expect(totals[14], 50);
    });

    test('computeStreak counts consecutive days with focus time', () {
      final logs = [
        _log(dateStr: '2026-09-12', hour: 9, tagId: 'tag_coding', minutes: 25),
        _log(dateStr: '2026-09-13', hour: 9, tagId: 'tag_coding', minutes: 25),
        _log(dateStr: '2026-09-14', hour: 9, tagId: 'tag_coding', minutes: 25),
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
            minutes: 30),
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
  });
}
