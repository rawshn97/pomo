import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/timer_tag_credit_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/tracker_tag.dart';

void main() {
  const deepWork = TrackerTag(
    id: 'tag_deep_work',
    name: 'Deep Work',
    icon: '🧠',
    colorHex: '#34A853',
    isDefault: true,
  );
  const coding = TrackerTag(
    id: 'tag_coding',
    name: 'Coding & Dev',
    icon: '💻',
    colorHex: '#4285F4',
    isDefault: true,
  );
  const admin = TrackerTag(
    id: 'tag_admin',
    name: 'Admin & Errands',
    icon: '📝',
    colorHex: '#78909C',
    isDefault: true,
  );

  group('TimerTagCreditHelper.splitEqually', () {
    test('gives remainder to the first tag', () {
      expect(TimerTagCreditHelper.splitEqually(25, 1), [25]);
      expect(TimerTagCreditHelper.splitEqually(25, 2), [13, 12]);
      expect(TimerTagCreditHelper.splitEqually(25, 3), [9, 8, 8]);
      expect(TimerTagCreditHelper.splitEqually(60, 2), [30, 30]);
    });

    test('returns empty for invalid input', () {
      expect(TimerTagCreditHelper.splitEqually(0, 2), isEmpty);
      expect(TimerTagCreditHelper.splitEqually(10, 0), isEmpty);
    });
  });

  group('TimerTagCreditHelper.sliceByHour', () {
    test('splits a session that crosses the hour', () {
      final slices = TimerTagCreditHelper.sliceByHour(
        from: DateTime(2026, 9, 3, 14, 52),
        to: DateTime(2026, 9, 3, 15, 17),
        totalMinutes: 25,
      );
      expect(slices, hasLength(2));
      expect(slices[0].dateStr, '2026-09-03');
      expect(slices[0].hour, 14);
      expect(slices[0].minutes, 8);
      expect(slices[1].hour, 15);
      expect(slices[1].minutes, 17);
    });

    test('keeps a session inside one hour', () {
      final slices = TimerTagCreditHelper.sliceByHour(
        from: DateTime(2026, 9, 3, 14, 10),
        to: DateTime(2026, 9, 3, 14, 35),
        totalMinutes: 25,
      );
      expect(slices, hasLength(1));
      expect(slices.single.hour, 14);
      expect(slices.single.minutes, 25);
    });
  });

  group('TimerTagCreditHelper.mergeCredit', () {
    test('adds a new tag beside an existing manual log', () {
      final existing = [
        HourlyLog(
          id: 'hlog_2026-09-03_14_tag_meetings',
          dateStr: '2026-09-03',
          hour: 14,
          tagId: 'tag_meetings',
          tagName: 'Meetings',
          tagIcon: '📞',
          tagColorHex: '#FBBC05',
          loggedAt: DateTime(2026, 9, 3, 14),
        ),
      ];
      final merged = TimerTagCreditHelper.mergeCredit(
        existingForHour: existing,
        dateStr: '2026-09-03',
        hour: 14,
        tags: const [deepWork],
        minutesPerTag: const [25],
        loggedAt: DateTime(2026, 9, 3, 14, 30),
      );
      expect(merged, hasLength(2));
      expect(
        merged.firstWhere((e) => e.tagId == 'tag_meetings').durationMinutes,
        60,
      );
      expect(
        merged.firstWhere((e) => e.tagId == 'tag_deep_work').durationMinutes,
        25,
      );
    });

    test('increments a matching tag and leaves the other', () {
      final existing = [
        HourlyLog(
          id: 'hlog_2026-09-03_14_tag_deep_work',
          dateStr: '2026-09-03',
          hour: 14,
          tagId: 'tag_deep_work',
          tagName: 'Deep Work',
          tagIcon: '🧠',
          tagColorHex: '#34A853',
          durationMinutes: 30,
          loggedAt: DateTime(2026, 9, 3, 14),
        ),
        HourlyLog(
          id: 'hlog_2026-09-03_14_tag_coding',
          dateStr: '2026-09-03',
          hour: 14,
          tagId: 'tag_coding',
          tagName: 'Coding & Dev',
          tagIcon: '💻',
          tagColorHex: '#4285F4',
          durationMinutes: 30,
          loggedAt: DateTime(2026, 9, 3, 14),
        ),
      ];
      final merged = TimerTagCreditHelper.mergeCredit(
        existingForHour: existing,
        dateStr: '2026-09-03',
        hour: 14,
        tags: const [deepWork, admin],
        minutesPerTag: const [10, 10],
        loggedAt: DateTime(2026, 9, 3, 14, 40),
      );
      expect(
        merged.firstWhere((e) => e.tagId == 'tag_deep_work').durationMinutes,
        40,
      );
      expect(
        merged.firstWhere((e) => e.tagId == 'tag_coding').durationMinutes,
        30,
      );
      expect(
        merged.firstWhere((e) => e.tagId == 'tag_admin').durationMinutes,
        10,
      );
    });

    test('replaces auto-fill Resting when the user credits tags', () {
      final existing = [
        HourlyLog(
          id: 'hlog_2026-09-03_23_tag_sleep',
          dateStr: '2026-09-03',
          hour: 23,
          tagId: 'tag_sleep',
          tagName: 'Sleep & Rest',
          tagIcon: '😴',
          tagColorHex: '#5C6BC0',
          notes: 'Resting',
          loggedAt: DateTime(2026, 9, 3, 23),
        ),
      ];
      final merged = TimerTagCreditHelper.mergeCredit(
        existingForHour: existing,
        dateStr: '2026-09-03',
        hour: 23,
        tags: const [coding],
        minutesPerTag: const [20],
        loggedAt: DateTime(2026, 9, 3, 23, 20),
      );
      expect(merged, hasLength(1));
      expect(merged.single.tagId, 'tag_coding');
      expect(merged.single.durationMinutes, 20);
    });
  });
}
