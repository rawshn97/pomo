import 'dart:async';

import 'package:pomo/helpers/quiet_hours_helper.dart';
import 'package:pomo/helpers/timer_tag_credit_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// Builds and persists hourly logs without a `BuildContext`.
class HourlyLogWriter {
  /// Instant 60-minute log for [hour] on [date] using [tag].
  static HourlyLog build({
    required DateTime date,
    required int hour,
    required TrackerTag tag,
    DateTime? loggedAt,
    String notes = '',
  }) {
    final ds = QuietHoursHelper.dateStr(date);
    return HourlyLog(
      id: QuietHoursHelper.logId(dateStr: ds, hour: hour, tagId: tag.id),
      dateStr: ds,
      hour: hour,
      tagId: tag.id,
      tagName: tag.name,
      tagIcon: tag.icon,
      tagColorHex: tag.colorHex,
      notes: notes,
      loggedAt: loggedAt ?? DateTime.now(),
    );
  }

  /// Saves [logs] locally. Optionally queues Notion sync when enabled.
  ///
  /// Auto-Resting uses replace-slot semantics and never appends beside a
  /// user tag. Resting is not synced to Notion here; callers should pull
  /// first so only empty slots are filled.
  static Future<int> persist(
    Iterable<HourlyLog> logs, {
    bool syncToNotion = true,
  }) async {
    var count = 0;
    for (final log in logs) {
      if (QuietHoursHelper.isAutoResting(log)) {
        if (await _persistRestingIfSlotEmpty(log)) {
          count++;
        }
        continue;
      }
      await Prefs.saveHourlyLog(log);
      count++;
      if (syncToNotion &&
          Prefs.enableNotionSync &&
          Prefs.notionApiKey.isNotEmpty &&
          Prefs.notionHourlyTimelineDatabaseId.isNotEmpty) {
        unawaited(NotionSyncService().syncHourlyLog(log));
      }
    }
    return count;
  }

  static Future<bool> _persistRestingIfSlotEmpty(HourlyLog log) async {
    final slot = Prefs.hourlyLogs
        .where((row) => row.dateStr == log.dateStr && row.hour == log.hour)
        .toList();
    if (slot.any((row) => !QuietHoursHelper.isAutoResting(row))) {
      return false;
    }
    await Prefs.replaceHourlyLogsForHour(log.dateStr, log.hour, [log]);
    return true;
  }

  /// Pulls remote hourly logs, then fills remaining empty quiet-hour slots.
  static Future<int> pullThenReconcileResting({DateTime? now}) async {
    await NotionSyncService().pullHourlyLogs();
    return reconcileResting(now: now);
  }

  /// Writes missing quiet-hour Resting logs for the recent lookback.
  static Future<int> reconcileResting({DateTime? now}) async {
    if (!Prefs.enableTimeTracker) {
      return 0;
    }
    final missing = QuietHoursHelper.missingRestingLogs(
      now: now ?? DateTime.now(),
      existing: Prefs.hourlyLogs,
      enableQuietHours: Prefs.enableQuietHours,
      start: Prefs.quietHoursStart,
      end: Prefs.quietHoursEnd,
    );
    return persist(missing, syncToNotion: false);
  }

  /// Credits Pomodoro minutes onto hourly tag rows (additive, hour-aware).
  static Future<int> creditTimerMinutes({
    required List<TrackerTag> tags,
    required DateTime from,
    required DateTime to,
    required int totalMinutes,
    DateTime? loggedAt,
    bool syncToNotion = true,
  }) async {
    if (tags.isEmpty || totalMinutes < 1) {
      return 0;
    }
    final slices = TimerTagCreditHelper.sliceByHour(
      from: from,
      to: to,
      totalMinutes: totalMinutes,
    );
    final now = loggedAt ?? DateTime.now();
    var count = 0;
    for (final slice in slices) {
      final splits =
          TimerTagCreditHelper.splitEqually(slice.minutes, tags.length);
      if (splits.isEmpty) {
        continue;
      }
      final existing = Prefs.hourlyLogs
          .where(
            (row) => row.dateStr == slice.dateStr && row.hour == slice.hour,
          )
          .toList();
      final merged = TimerTagCreditHelper.mergeCredit(
        existingForHour: existing,
        dateStr: slice.dateStr,
        hour: slice.hour,
        tags: tags,
        minutesPerTag: splits,
        loggedAt: now,
      );
      await Prefs.replaceHourlyLogsForHour(slice.dateStr, slice.hour, merged);
      count += splits.where((mins) => mins > 0).length;
      if (syncToNotion &&
          Prefs.enableNotionSync &&
          Prefs.notionApiKey.isNotEmpty &&
          Prefs.notionHourlyTimelineDatabaseId.isNotEmpty) {
        for (final log in merged) {
          unawaited(NotionSyncService().syncHourlyLog(log));
        }
      }
    }
    return count;
  }
}
