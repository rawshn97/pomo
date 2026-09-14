import 'package:pomo/helpers/quiet_hours_helper.dart';
import 'package:pomo/models/hourly_log.dart';

/// Minutes credited to one activity tag.
class TagMinutes {
  const TagMinutes({
    required this.tagId,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.minutes,
  });

  final String tagId;
  final String name;
  final String icon;
  final String colorHex;
  final int minutes;
}

/// Aggregated focus time for a single calendar day.
class DaySummary {
  const DaySummary({
    required this.dateStr,
    required this.totalMinutes,
    required this.activeHours,
    this.topTagName,
    this.topTagIcon,
    this.topTagColorHex,
  });

  final String dateStr;
  final int totalMinutes;
  final int activeHours;
  final String? topTagName;
  final String? topTagIcon;
  final String? topTagColorHex;
}

/// Period-level rollup used by the Time Log history tab.
class PeriodAnalytics {
  const PeriodAnalytics({
    required this.totalMinutes,
    required this.activeDays,
    required this.periodDays,
    required this.avgDailyMinutes,
    required this.streakDays,
    required this.tagBreakdown,
    required this.hourTotals,
    required this.dailySummaries,
  });

  final int totalMinutes;
  final int activeDays;
  final int periodDays;
  final double avgDailyMinutes;
  final int streakDays;
  final List<TagMinutes> tagBreakdown;
  final List<int> hourTotals;
  final List<DaySummary> dailySummaries;
}

/// Pure aggregation helpers for timer-credited hourly logs.
class TimeLogAnalyticsHelper {
  /// Logs that represent real focus time (excludes auto Resting fill).
  static Iterable<HourlyLog> focusLogs(Iterable<HourlyLog> logs) {
    return logs.where((log) => !QuietHoursHelper.isAutoResting(log));
  }

  static String dateStr(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime parseDateStr(String dateStr) {
    final parts = dateStr.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static int totalMinutes(Iterable<HourlyLog> logs) {
    return focusLogs(logs).fold<int>(
      0,
      (sum, log) => sum + log.durationMinutes,
    );
  }

  static List<TagMinutes> tagBreakdown(Iterable<HourlyLog> logs) {
    final map =
        <String, ({String name, String icon, String color, int minutes})>{};
    for (final log in focusLogs(logs)) {
      final current = map[log.tagId] ??
          (
            name: log.tagName,
            icon: log.tagIcon,
            color: log.tagColorHex,
            minutes: 0
          );
      map[log.tagId] = (
        name: current.name,
        icon: current.icon,
        color: current.color,
        minutes: current.minutes + log.durationMinutes,
      );
    }
    final stats = map.entries
        .map(
          (entry) => TagMinutes(
            tagId: entry.key,
            name: entry.value.name,
            icon: entry.value.icon,
            colorHex: entry.value.color,
            minutes: entry.value.minutes,
          ),
        )
        .toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
    return stats;
  }

  static List<int> hourTotals(Iterable<HourlyLog> logs) {
    final totals = List<int>.filled(24, 0);
    for (final log in focusLogs(logs)) {
      if (log.hour >= 0 && log.hour < 24) {
        totals[log.hour] += log.durationMinutes;
      }
    }
    return totals;
  }

  static List<HourlyLog> logsForDate(Iterable<HourlyLog> logs, String dateStr) {
    return focusLogs(logs).where((log) => log.dateStr == dateStr).toList();
  }

  static Map<int, List<HourlyLog>> logsByHourForDate(
    Iterable<HourlyLog> logs,
    String dateStr,
  ) {
    final map = <int, List<HourlyLog>>{};
    for (final log in logsForDate(logs, dateStr)) {
      map.putIfAbsent(log.hour, () => []).add(log);
    }
    for (final hourLogs in map.values) {
      hourLogs.sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
    }
    return map;
  }

  static int activeHoursForDate(Iterable<HourlyLog> logs, String dateStr) {
    return logsByHourForDate(logs, dateStr).length;
  }

  static DaySummary summarizeDay(Iterable<HourlyLog> logs, String dateStr) {
    final dayLogs = logsForDate(logs, dateStr);
    final total = totalMinutes(dayLogs);
    final tags = tagBreakdown(dayLogs);
    final top = tags.isEmpty ? null : tags.first;
    return DaySummary(
      dateStr: dateStr,
      totalMinutes: total,
      activeHours: logsByHourForDate(logs, dateStr).length,
      topTagName: top?.name,
      topTagIcon: top?.icon,
      topTagColorHex: top?.colorHex,
    );
  }

  static List<DaySummary> dailySummariesForRange({
    required Iterable<HourlyLog> logs,
    required DateTime start,
    required DateTime end,
  }) {
    final summaries = <DaySummary>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(endDay)) {
      final ds = dateStr(cursor);
      summaries.add(summarizeDay(logs, ds));
      cursor = cursor.add(const Duration(days: 1));
    }
    return summaries.reversed.toList();
  }

  /// Consecutive days ending [today] with any focus minutes logged.
  static int computeStreak(
    Iterable<HourlyLog> logs, {
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    var streak = 0;
    var cursor = DateTime(now.year, now.month, now.day);
    while (true) {
      final ds = dateStr(cursor);
      if (totalMinutes(logs.where((log) => log.dateStr == ds)) == 0) {
        break;
      }
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static PeriodAnalytics analyzePeriod({
    required Iterable<HourlyLog> logs,
    required int periodDays,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(Duration(days: periodDays - 1));
    final startStr = dateStr(start);
    final endStr = dateStr(end);

    final periodLogs = focusLogs(logs).where((log) {
      return log.dateStr.compareTo(startStr) >= 0 &&
          log.dateStr.compareTo(endStr) <= 0;
    }).toList();

    final dailySummaries = dailySummariesForRange(
      logs: logs,
      start: start,
      end: end,
    );
    final activeDays =
        dailySummaries.where((day) => day.totalMinutes > 0).length;
    final total = totalMinutes(periodLogs);

    return PeriodAnalytics(
      totalMinutes: total,
      activeDays: activeDays,
      periodDays: periodDays,
      avgDailyMinutes: periodDays > 0 ? total / periodDays : 0,
      streakDays: computeStreak(logs, today: now),
      tagBreakdown: tagBreakdown(periodLogs),
      hourTotals: hourTotals(periodLogs),
      dailySummaries: dailySummaries,
    );
  }

  static String formatHoursMinutes(int minutes) {
    if (minutes <= 0) {
      return '0m';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) {
      return '${mins}m';
    }
    if (mins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${mins}m';
  }

  static String formatHoursDecimal(int minutes) {
    return (minutes / 60.0).toStringAsFixed(1);
  }

  static String formatDateLabel(String dateStr, {DateTime? today}) {
    final now = today ?? DateTime.now();
    final date = parseDateStr(dateStr);
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${date.month}/${date.day}';
  }
}
