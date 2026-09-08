import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/tracker_tag.dart';

/// Quiet-hours window checks for missed-hour scans and Resting auto-logs.
///
/// Kept free of `BuildContext` so unit tests can cover enable/disable and
/// overnight wrap without a widget tree.
class QuietHoursHelper {
  /// Built-in Sleep & Rest tag used for DESIGN Resting blocks.
  static TrackerTag get restingTag => TrackerTag.defaults.firstWhere(
        (tag) => tag.id == 'tag_sleep',
      );

  /// Whether hour index `[0, 23]` sits in the configured quiet-hours window.
  ///
  /// When [enableQuietHours] is false, always returns false so those hours
  /// remain visible as missed/untracked.
  static bool isQuietHourIndex({
    required int hour,
    required bool enableQuietHours,
    required String start,
    required String end,
  }) {
    if (!enableQuietHours) {
      return false;
    }
    try {
      final startH = int.parse(start.split(':')[0]);
      final endH = int.parse(end.split(':')[0]);
      if (startH > endH) {
        return hour >= startH || hour < endH;
      }
      return hour >= startH && hour < endH;
    } on FormatException {
      return false;
    }
  }

  /// ISO date `YYYY-MM-DD` for [date].
  static String dateStr(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Hourly log id matching `HourlyLogDialog` (`hlog_<date>_<hour>_<tagId>`).
  static String logId({
    required String dateStr,
    required int hour,
    required String tagId,
  }) {
    return 'hlog_${dateStr}_${hour}_$tagId';
  }

  /// A 60-minute Resting block for [hour] on [date].
  static HourlyLog restingLog({
    required DateTime date,
    required int hour,
    DateTime? loggedAt,
  }) {
    final tag = restingTag;
    final ds = dateStr(date);
    return HourlyLog(
      id: logId(dateStr: ds, hour: hour, tagId: tag.id),
      dateStr: ds,
      hour: hour,
      tagId: tag.id,
      tagName: tag.name,
      tagIcon: tag.icon,
      tagColorHex: tag.colorHex,
      notes: 'Resting',
      loggedAt: loggedAt ?? date,
    );
  }

  /// Quiet-hour blocks in the lookback that have no hourly log yet.
  ///
  /// Only completed hours are considered (`now.hour` exclusive for today).
  static List<HourlyLog> missingRestingLogs({
    required DateTime now,
    required Iterable<HourlyLog> existing,
    required bool enableQuietHours,
    required String start,
    required String end,
    int daysBack = 2,
  }) {
    if (!enableQuietHours) {
      return [];
    }
    final logged = <String>{
      for (final log in existing) '${log.dateStr}_${log.hour}',
    };
    final missing = <HourlyLog>[];
    for (var d = 0; d < daysBack; d++) {
      final targetDate =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: d));
      final maxHour = d == 0 ? now.hour : 24;
      for (var h = 0; h < maxHour; h++) {
        if (!isQuietHourIndex(
          hour: h,
          enableQuietHours: true,
          start: start,
          end: end,
        )) {
          continue;
        }
        final ds = dateStr(targetDate);
        if (logged.contains('${ds}_$h')) {
          continue;
        }
        missing.add(
          restingLog(date: targetDate, hour: h, loggedAt: now),
        );
      }
    }
    return missing;
  }

  /// Auto-written quiet-hour Resting row (`tag_sleep` and/or notes Resting).
  static bool isAutoResting(HourlyLog log) {
    return log.tagId == 'tag_sleep' || log.notes.trim() == 'Resting';
  }
}
