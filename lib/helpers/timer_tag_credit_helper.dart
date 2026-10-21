import 'package:pomo/helpers/quiet_hours_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/tracker_tag.dart';

/// Minutes attributed to one calendar hour while crediting a Pomodoro.
class HourMinuteSlice {
  const HourMinuteSlice({
    required this.dateStr,
    required this.hour,
    required this.minutes,
  });

  /// ISO date `YYYY-MM-DD`.
  final String dateStr;

  /// Hour index `0..23`.
  final int hour;

  /// Whole minutes in this hour.
  final int minutes;
}

/// Pure split / hour-boundary / merge math for timer-to-hourly credit.
class TimerTagCreditHelper {
  /// Equal split; first bucket receives the remainder.
  ///
  /// Example: 25 minutes and 2 tags → `[13, 12]`.
  static List<int> splitEqually(int totalMinutes, int tagCount) {
    if (totalMinutes < 1 || tagCount < 1) {
      return const [];
    }
    final base = totalMinutes ~/ tagCount;
    final first = totalMinutes - base * (tagCount - 1);
    return [
      first,
      ...List<int>.filled(tagCount - 1, base),
    ];
  }

  /// Walks [from] → [to] allocating [totalMinutes] across hour blocks.
  static List<HourMinuteSlice> sliceByHour({
    required DateTime from,
    required DateTime to,
    required int totalMinutes,
  }) {
    if (totalMinutes < 1) {
      return const [];
    }
    if (!to.isAfter(from)) {
      return [
        HourMinuteSlice(
          dateStr: QuietHoursHelper.dateStr(from),
          hour: from.hour,
          minutes: totalMinutes,
        ),
      ];
    }

    final slices = <HourMinuteSlice>[];
    var remaining = totalMinutes;
    var cursor = from;
    while (remaining > 0) {
      final hourStart = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour,
      );
      final hourEnd = hourStart.add(const Duration(hours: 1));
      final minutesLeftInHour = hourEnd.difference(cursor).inMinutes;
      if (minutesLeftInHour <= 0) {
        cursor = hourEnd;
        continue;
      }
      final chunk =
          remaining < minutesLeftInHour ? remaining : minutesLeftInHour;
      slices.add(
        HourMinuteSlice(
          dateStr: QuietHoursHelper.dateStr(cursor),
          hour: cursor.hour,
          minutes: chunk,
        ),
      );
      remaining -= chunk;
      cursor = hourEnd;
    }
    return slices;
  }

  /// Additive merge: matching tag ids gain minutes; other slot rows stay.
  ///
  /// Auto-fill Resting rows (`notes == Resting`) are dropped when the user
  /// credits Pomodoro minutes into that hour.
  static List<HourlyLog> mergeCredit({
    required List<HourlyLog> existingForHour,
    required String dateStr,
    required int hour,
    required List<TrackerTag> tags,
    required List<int> minutesPerTag,
    required DateTime loggedAt,
  }) {
    var slot = List<HourlyLog>.from(existingForHour);
    if (slot.isNotEmpty && slot.every(_isAutoFillResting)) {
      slot = [];
    }

    final result = List<HourlyLog>.from(slot);
    final count =
        tags.length < minutesPerTag.length ? tags.length : minutesPerTag.length;
    for (var i = 0; i < count; i++) {
      final mins = minutesPerTag[i];
      if (mins < 1) {
        continue;
      }
      final tag = tags[i];
      final id = QuietHoursHelper.logId(
        dateStr: dateStr,
        hour: hour,
        tagId: tag.id,
      );
      final idx = result.indexWhere((row) => row.id == id);
      if (idx == -1) {
        result.add(
          HourlyLog(
            id: id,
            dateStr: dateStr,
            hour: hour,
            tagId: tag.id,
            tagName: tag.name,
            tagIcon: tag.icon,
            tagColorHex: tag.colorHex,
            durationMinutes: mins,
            loggedAt: loggedAt,
          ),
        );
      } else {
        final current = result[idx];
        result[idx] = current.copyWith(
          durationMinutes: current.durationMinutes + mins,
          loggedAt: loggedAt,
        );
      }
    }
    return capHourAt60Minutes(result);
  }

  /// Clamps and distributes minutes so the total in a given hour across all
  /// tags never exceeds 60 minutes, splitting overlapping excess equally across
  /// all active tags in the hour to prevent double counting.
  static List<HourlyLog> capHourAt60Minutes(List<HourlyLog> logs) {
    if (logs.isEmpty) return logs;
    final total = logs.fold<int>(0, (sum, log) => sum + log.durationMinutes);
    if (total <= 60) return logs;

    final excess = total - 60;
    final n = logs.length;
    final baseDeduction = excess ~/ n;
    var remainder = excess % n;

    final updated = <HourlyLog>[];
    for (var i = 0; i < n; i++) {
      final log = logs[i];
      final deduction = baseDeduction + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      final newMins = (log.durationMinutes - deduction).clamp(1, 60);
      updated.add(log.copyWith(durationMinutes: newMins));
    }

    final newTotal =
        updated.fold<int>(0, (sum, log) => sum + log.durationMinutes);
    if (newTotal > 60) {
      final diff = newTotal - 60;
      final maxIdx = updated.indexWhere((l) => l.durationMinutes > diff);
      if (maxIdx != -1) {
        updated[maxIdx] = updated[maxIdx].copyWith(
          durationMinutes: updated[maxIdx].durationMinutes - diff,
        );
      }
    } else if (newTotal < 60) {
      final diff = 60 - newTotal;
      updated[0] = updated[0].copyWith(
        durationMinutes: updated[0].durationMinutes + diff,
      );
    }
    return updated;
  }

  static bool _isAutoFillResting(HourlyLog log) {
    return log.notes.trim() == 'Resting';
  }
}
