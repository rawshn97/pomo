import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pomo/helpers/quiet_hours_helper.dart';
import 'package:pomo/helpers/tag_reassign_helper.dart';
import 'package:pomo/helpers/tag_registry_writer.dart';
import 'package:pomo/helpers/tracker_tag_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/singletons/prefs.dart';

class NotionSyncService {
  factory NotionSyncService() => _instance;
  NotionSyncService._internal();

  static final NotionSyncService _instance = NotionSyncService._internal();

  /// Minutes to ADD to the parent task for a session update.
  /// [totalMinutes] is absolute elapsed; [alreadySynced] is prior credit.
  static int sessionCreditMinutes({
    required int totalMinutes,
    required int alreadySynced,
  }) {
    if (totalMinutes < 1) return 0;
    return totalMinutes > alreadySynced ? totalMinutes - alreadySynced : 0;
  }

  /// Synchronizes a completed or partial focus session to Notion if sync is
  /// enabled and the duration is at least 1 minute.
  Future<({bool success, String? logPageId})> syncSession({
    required NotionTask? task,
    required Duration duration,
    Duration? totalDuration,
    String? existingLogPageId,
    DateTime? endedAt,
  }) async {
    if (task == null || task.id.isEmpty) {
      Logger().d('NotionSyncService: No active NotionTask assigned.');
      return (success: false, logPageId: null);
    }

    if (!Prefs.enableNotionSync) {
      Logger().d('NotionSyncService: Notion sync disabled in Settings.');
      return (success: false, logPageId: null);
    }

    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) {
      Logger().w('NotionSyncService: Notion API Key is empty.');
      return (success: false, logPageId: null);
    }

    final minutes = duration.inMinutes;
    if (minutes < 1) {
      Logger().i(
        'NotionSyncService: Session duration ($minutes m) under threshold.',
      );
      return (success: false, logPageId: null);
    }

    final totalMinutes = (totalDuration ?? duration).inMinutes;
    final timestamp = endedAt ?? DateTime.now();
    Logger().i(
      'NotionSyncService: Syncing ${minutes}m increment '
      '(${totalMinutes}m total) on "${task.title}" to Notion...',
    );

    try {
      await moveToInProgressIfNeeded(task);

      final result = await NotionService().logSession(
        task: task,
        creditMinutes: minutes,
        totalDurationMinutes: totalMinutes,
        endedAt: timestamp,
        existingLogPageId: existingLogPageId,
      );

      if (result.success) {
        // Update active task local state if it's the currently selected task
        final currentActive = Prefs.activeTask;
        if (currentActive != null && currentActive.id == task.id) {
          final newMath = NotionService.addDuration(
            currentHours: currentActive.timeHours,
            currentMinutes: currentActive.timeMinutes,
            addMin: minutes,
          );
          Prefs.activeTask = currentActive.copyWith(
            timeHours: () => newMath.hours,
            timeMinutes: () => newMath.minutes,
          );
        }
        if (Prefs.pendingTimeLogs.isNotEmpty) {
          unawaited(flushPendingLogs());
        }
      }

      return (success: result.success, logPageId: result.pageId);
    } catch (e, st) {
      Logger().e(
        'NotionSyncService: Sync failed ($e)',
        error: e,
        stackTrace: st,
      );
      _enqueuePendingLog(
        task: task,
        durationMinutes: minutes,
        totalDurationMinutes: totalMinutes,
        endedAt: timestamp,
        existingLogPageId: existingLogPageId,
      );
      return (success: false, logPageId: null);
    }
  }

  /// Creates a brand-new Time Log row in Notion for a freshly started session.
  /// Returns the Notion page ID of the created row, or null on failure.
  /// Fires-and-forgets the move-to-in-progress call if a task is present.
  ///
  /// Persists a stable [Prefs.activeSessionExternalId] so retries do not create
  /// duplicate rows. Does not credit task cumulative time (credit = 0).
  Future<String?> createSessionRecord({
    required DateTime startedAt,
    NotionTask? task,
    TrackerTag? primaryTag,
  }) async {
    if (!Prefs.enableNotionSync) return null;
    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) return null;

    final taskId =
        task?.id ?? (primaryTag != null ? primaryTag.id : 'untasked');
    final title = task?.title ??
        (primaryTag != null
            ? '${primaryTag.icon} ${primaryTag.name}'
            : 'Focus Session');

    final externalId = Prefs.activeSessionExternalId ??
        'sess_${taskId}_${startedAt.millisecondsSinceEpoch}';
    Prefs.activeSessionExternalId = externalId;
    Prefs.syncedMinutes = 0;

    Logger().i(
      'NotionSyncService: Creating session record for '
      '"$title" ($taskId) externalId=$externalId...',
    );

    try {
      if (task != null && task.id.isNotEmpty) {
        unawaited(moveToInProgressIfNeeded(task));
      }

      final result = await NotionService().logSession(
        task: task,
        sessionTitle: title,
        creditMinutes: 0,
        totalDurationMinutes: 0,
        endedAt: startedAt,
        customExternalId: externalId,
      );

      if (result.success && result.pageId != null) {
        Logger().i(
          'NotionSyncService: Created session record ${result.pageId}',
        );
        return result.pageId;
      }
    } catch (e, st) {
      Logger().e(
        'NotionSyncService: Failed to create session record ($e)',
        error: e,
        stackTrace: st,
      );
    }
    return null;
  }

  /// Updates an existing Time Log row with the latest elapsed time.
  /// If [existingLogPageId] is null, falls back to creating a new record.
  ///
  /// Task cumulative time receives only the delta
  /// (`totalElapsed.inMinutes - previouslySyncedMinutes`).
  /// Pass [previouslySyncedMinutes] when clearing Prefs before the async call
  /// completes (e.g. task switch).
  Future<({bool success, String? logPageId})> updateSessionRecord({
    required Duration totalElapsed,
    required String? existingLogPageId,
    NotionTask? task,
    TrackerTag? primaryTag,
    DateTime? endedAt,
    int? previouslySyncedMinutes,
  }) async {
    if (!Prefs.enableNotionSync) {
      return (success: false, logPageId: null);
    }
    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) {
      return (success: false, logPageId: null);
    }

    final totalMinutes = totalElapsed.inMinutes;
    if (totalMinutes < 1) {
      return (success: false, logPageId: existingLogPageId);
    }

    final alreadySynced = previouslySyncedMinutes ?? Prefs.syncedMinutes;
    final creditMinutes = sessionCreditMinutes(
      totalMinutes: totalMinutes,
      alreadySynced: alreadySynced,
    );
    final timestamp = endedAt ?? DateTime.now();
    final title = task?.title ??
        (primaryTag != null
            ? '${primaryTag.icon} ${primaryTag.name}'
            : 'Focus Session');

    Logger().i(
      'NotionSyncService: Updating session record '
      '(${totalMinutes}m total, +${creditMinutes}m credit) '
      'for "$title"...',
    );

    try {
      final result = await NotionService().logSession(
        task: task,
        sessionTitle: title,
        creditMinutes: creditMinutes,
        totalDurationMinutes: totalMinutes,
        endedAt: timestamp,
        existingLogPageId: existingLogPageId,
        customExternalId: Prefs.activeSessionExternalId,
      );

      if (result.success) {
        // Only advance the baseline when this is still the same open session.
        if (Prefs.activeLogPageId == existingLogPageId ||
            existingLogPageId == null) {
          Prefs.syncedMinutes = totalMinutes;
        }
        final currentActive = Prefs.activeTask;
        if (task != null &&
            currentActive != null &&
            currentActive.id == task.id &&
            creditMinutes > 0) {
          final newMath = NotionService.addDuration(
            currentHours: currentActive.timeHours,
            currentMinutes: currentActive.timeMinutes,
            addMin: creditMinutes,
          );
          Prefs.activeTask = currentActive.copyWith(
            timeHours: () => newMath.hours,
            timeMinutes: () => newMath.minutes,
          );
        }
        if (Prefs.pendingTimeLogs.isNotEmpty) {
          unawaited(flushPendingLogs());
        }
      }

      return (success: result.success, logPageId: result.pageId);
    } catch (e, st) {
      Logger().e(
        'NotionSyncService: Update session failed ($e)',
        error: e,
        stackTrace: st,
      );
      if (task != null) {
        _enqueuePendingLog(
          task: task,
          durationMinutes: creditMinutes,
          totalDurationMinutes: totalMinutes,
          endedAt: timestamp,
          existingLogPageId: existingLogPageId,
        );
      }
      return (success: false, logPageId: null);
    }
  }

  /// Deletes a Time Log record in Notion.
  Future<bool> deleteSessionRecord(String pageId) async {
    if (pageId.isEmpty) return false;
    if (!Prefs.enableNotionSync) return false;
    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) return false;

    Logger().i('NotionSyncService: Deleting session record $pageId...');
    try {
      return await NotionService().deletePage(pageId);
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Failed to delete session record $pageId: $e',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Synchronizes a single [HourlyLog] to the separate Hourly Timeline Notion
  /// DB. Respects [Prefs.enableNotionSync], the API key guard, and enqueues to
  /// a pending queue on failure.
  Future<({bool success, String? pageId, HourlyLog log})> syncHourlyLog(
    HourlyLog log,
  ) async {
    if (!Prefs.enableNotionSync) {
      Logger().d('NotionSyncService: Notion sync disabled in Settings.');
      return (success: false, pageId: null, log: log);
    }

    if (Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty) {
      Logger().w(
        'NotionSyncService: Hourly Timeline Database ID is empty.',
      );
      return (success: false, pageId: null, log: log);
    }

    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) {
      Logger().w('NotionSyncService: Notion API Key is empty.');
      return (success: false, pageId: null, log: log);
    }

    try {
      final result = await NotionService().syncHourlyLog(log);
      if (result.success) {
        if (Prefs.pendingHourlyLogs.isNotEmpty) {
          unawaited(flushPendingHourlyLogs());
        }
      }
      return (
        success: result.success,
        pageId: result.pageId,
        log: result.log,
      );
    } catch (e, st) {
      Logger().e(
        'NotionSyncService: Hourly sync failed ($e)',
        error: e,
        stackTrace: st,
      );
      _enqueuePendingHourlyLog(log);
      return (success: false, pageId: null, log: log);
    }
  }

  /// Returns the latest complete revision of a date-hour slot.
  ///
  /// Multi-tag saves total at most 60 minutes. Reading newest-first until the
  /// hour is allocated recovers older clients that timestamped each tag
  /// separately, while preventing two device writes from turning one hour
  /// into 120 minutes.
  ///
  /// When a user (non-`tag_sleep` / non-auto-Resting) row and an auto-Resting
  /// row both claim a full hour, the user row wins even if Resting is newer.
  static List<HourlyLog> currentHourlySlotRevision(List<HourlyLog> logs) {
    if (logs.isEmpty) return [];
    var candidates = List<HourlyLog>.from(logs);
    final hasUserFullHour = candidates.any(
      (log) =>
          !QuietHoursHelper.isAutoResting(log) &&
          log.durationMinutes.clamp(0, 60) == 60,
    );
    final hasRestingFullHour = candidates.any(
      (log) =>
          QuietHoursHelper.isAutoResting(log) &&
          log.durationMinutes.clamp(0, 60) == 60,
    );
    if (hasUserFullHour && hasRestingFullHour) {
      candidates = candidates
          .where((log) => !QuietHoursHelper.isAutoResting(log))
          .toList();
    }
    final sorted = candidates..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final result = <HourlyLog>[];
    final selectedTags = <String>{};
    var allocatedMinutes = 0;

    for (final log in sorted) {
      final minutes = log.durationMinutes.clamp(0, 60);
      final tagKey = log.tagId.isEmpty || log.tagId == 'tag_imported'
          ? log.tagName.trim().toLowerCase()
          : log.tagId;
      if (minutes == 0 ||
          selectedTags.contains(tagKey) ||
          allocatedMinutes + minutes > 60) {
        continue;
      }
      result.add(log);
      selectedTags.add(tagKey);
      allocatedMinutes += minutes;
    }
    return result;
  }

  /// Replaces one date-hour slot locally and in Notion.
  ///
  /// New rows are written before superseded rows are archived. This prevents
  /// edits from briefly deleting the only remote copy and makes a save an
  /// authoritative replacement instead of an append.
  Future<({bool success, List<HourlyLog> logs})> replaceHourlyLogsForHour({
    required String dateStr,
    required int hour,
    required List<HourlyLog> logs,
  }) async {
    _removePendingHourlyLogsForHour(dateStr, hour);

    if (!Prefs.enableNotionSync ||
        Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty ||
        Prefs.notionApiKey.isEmpty) {
      await Prefs.replaceHourlyLogsForHour(dateStr, hour, logs);
      return (success: true, logs: logs);
    }

    List<HourlyLog> remoteBefore;
    try {
      remoteBefore =
          await NotionService().fetchHourlyLogsForHour(dateStr, hour);
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Failed to read slot before replacement ($e)',
        error: e,
        stackTrace: st,
      );
      for (final log in logs) {
        _enqueuePendingHourlyLog(log);
      }
      await Prefs.replaceHourlyLogsForHour(dateStr, hour, logs);
      return (success: false, logs: logs);
    }

    final synced = <HourlyLog>[];
    var allWritesSucceeded = true;
    for (final log in logs) {
      final result = await syncHourlyLog(log);
      synced.add(result.success ? result.log : log);
      allWritesSucceeded = allWritesSucceeded && result.success;
    }

    if (!allWritesSucceeded) {
      await Prefs.replaceHourlyLogsForHour(dateStr, hour, synced);
      return (success: false, logs: synced);
    }

    final retainedPageIds = synced
        .map((log) => log.notionPageId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    var allDeletesSucceeded = true;
    for (final oldLog in remoteBefore) {
      final pageId = oldLog.notionPageId;
      if (pageId == null ||
          pageId.isEmpty ||
          retainedPageIds.contains(pageId)) {
        continue;
      }
      final deleted = await NotionService().deletePage(pageId);
      allDeletesSucceeded = allDeletesSucceeded && deleted;
    }

    await Prefs.replaceHourlyLogsForHour(dateStr, hour, synced);
    return (success: allDeletesSucceeded, logs: synced);
  }

  /// Refreshes one slot from Notion, treating the remote slot as authoritative.
  Future<List<HourlyLog>> refreshHourlyLogsForHour(
    String dateStr,
    int hour,
  ) async {
    if (!Prefs.enableNotionSync ||
        Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty ||
        Prefs.notionApiKey.isEmpty) {
      return Prefs.hourlyLogs
          .where((log) => log.dateStr == dateStr && log.hour == hour)
          .toList();
    }

    final remote = await NotionService().fetchHourlyLogsForHour(dateStr, hour);
    final local = Prefs.hourlyLogs
        .where((log) => log.dateStr == dateStr && log.hour == hour)
        .toList();
    if (remote.isEmpty && local.any((log) => log.notionPageId == null)) {
      final result = await replaceHourlyLogsForHour(
        dateStr: dateStr,
        hour: hour,
        logs: local,
      );
      return result.logs;
    }
    final current = currentHourlySlotRevision(remote);
    await Prefs.replaceHourlyLogsForHour(dateStr, hour, current);
    return current;
  }

  /// Pulls hourly logs from the Notion Hourly Timeline DB and merges them
  /// into local storage. This is how logs created on other devices (e.g. the
  /// PWA) appear on this install. A remote slot revision replaces the local
  /// slot unless that slot still has a pending upload. Returns the number of
  /// slots added or updated.
  Future<int> pullHourlyLogs({int daysBack = 90}) async {
    if (!Prefs.enableNotionSync) {
      return 0;
    }
    if (Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty) {
      return 0;
    }
    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) {
      return 0;
    }

    try {
      final remote = await NotionService().fetchHourlyLogs(daysBack: daysBack);
      if (remote.isEmpty) {
        return 0;
      }

      final local = List<HourlyLog>.from(Prefs.hourlyLogs);
      final pendingSlots = <String>{};
      for (final item in Prefs.pendingHourlyLogs) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          final dateStr = data['dateStr'] as String? ?? '';
          final hour = data['hour'] as int?;
          if (dateStr.isNotEmpty && hour != null) {
            pendingSlots.add('$dateStr:$hour');
          }
        } catch (_) {}
      }

      final remoteBySlot = <String, List<HourlyLog>>{};
      for (final log in remote) {
        remoteBySlot
            .putIfAbsent('${log.dateStr}:${log.hour}', () => [])
            .add(log);
      }
      var changed = 0;

      for (final entry in remoteBySlot.entries) {
        final firstRemote = entry.value.first;
        final existing = local
            .where(
              (log) =>
                  log.dateStr == firstRemote.dateStr &&
                  log.hour == firstRemote.hour,
            )
            .toList();
        final remoteHasUser = entry.value.any(
          (log) => !QuietHoursHelper.isAutoResting(log),
        );
        if (pendingSlots.contains(entry.key) && !remoteHasUser) {
          continue;
        }

        final remoteRevision = currentHourlySlotRevision([
          ...existing,
          ...entry.value,
        ]);
        final first = remoteRevision.firstOrNull;
        if (first == null) {
          continue;
        }
        final existingById = {for (final log in existing) log.id: log};
        final mergedRevision = remoteRevision.map((remoteLog) {
          final previous = existingById[remoteLog.id];
          if (previous == null ||
              previous.tagName.toLowerCase() !=
                  remoteLog.tagName.toLowerCase()) {
            return remoteLog;
          }
          return remoteLog.copyWith(
            tagId: previous.tagId,
            tagColorHex: previous.tagColorHex,
            projectId: previous.projectId,
          );
        }).toList();

        final existingSorted = List<HourlyLog>.from(existing)
          ..sort((a, b) => a.id.compareTo(b.id));
        final mergedSorted = List<HourlyLog>.from(mergedRevision)
          ..sort((a, b) => a.id.compareTo(b.id));
        if (!listEquals(existingSorted, mergedSorted)) {
          local
            ..removeWhere(
              (log) => log.dateStr == first.dateStr && log.hour == first.hour,
            )
            ..addAll(mergedRevision);
          changed++;
        }
      }

      if (changed > 0) {
        Prefs.hourlyLogs = local;
      }
      Logger().i(
        'NotionSyncService: Pulled ${remote.length} hourly logs from Notion '
        '($changed added/updated locally).',
      );
      return changed;
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Hourly pull failed ($e)',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }

  /// Reconciles custom activity tags with the Notion-backed registry.
  ///
  /// Existing local tags that predate tag sync are uploaded as a migration.
  /// Remote tags and deletion tombstones are then applied locally.
  Future<int> syncActivityTags() async {
    if (!Prefs.enableNotionSync ||
        Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty ||
        Prefs.notionApiKey.isEmpty) {
      return 0;
    }

    try {
      final remote = await NotionService().fetchActivityTagRecords();
      final latestRemote =
          <String, ({TrackerTag tag, bool deleted, DateTime updatedAt})>{};
      for (final record in remote) {
        final existing = latestRemote[record.tag.id];
        if (existing == null || record.updatedAt.isAfter(existing.updatedAt)) {
          latestRemote[record.tag.id] = record;
        }
      }

      final local = List<TrackerTag>.from(Prefs.trackerTags);
      final localCustom = local.where((tag) => !tag.isDefault).toList();
      var changed = 0;

      // Upload legacy local-only custom tags before applying remote state.
      for (final tag in localCustom) {
        if (!latestRemote.containsKey(tag.id)) {
          if (await NotionService().syncActivityTag(tag)) {
            changed++;
          }
        }
      }

      for (final record in latestRemote.values) {
        final index = local.indexWhere((tag) => tag.id == record.tag.id);
        if (record.deleted) {
          if (index != -1 && !local[index].isDefault) {
            local.removeAt(index);
            changed++;
          }
          continue;
        }

        if (index == -1) {
          local.add(record.tag);
          changed++;
        } else if (!local[index].isDefault && local[index] != record.tag) {
          local[index] = record.tag;
          changed++;
        }
      }

      changed += await _recoverTagsFromHourlyLogs(
        local: local,
        registry: latestRemote.values.toList(),
      );

      Prefs.trackerTags = local;
      if (changed > 0) {
        await TagRegistryWriter.writeIfPossible();
      }
      Logger().i(
        'NotionSyncService: Reconciled activity tags '
        '(${latestRemote.length} remote, $changed changes).',
      );
      return changed;
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Activity tag sync failed ($e)',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }

  static const List<String> _recoveredTagPalette = [
    '#4285F4',
    '#EA4335',
    '#FBBC05',
    '#34A853',
    '#AB47BC',
    '#26A69A',
    '#FF7043',
    '#5C6BC0',
  ];

  /// Recovers custom tags that predate the registry.
  ///
  /// Tags created before tag sync shipped (e.g. in the PWA) exist only inside
  /// hourly-log rows, so a fresh install pulls an empty registry and loses
  /// them. Any tag name used by a local hourly log that has no local tag and
  /// no newer deletion tombstone is re-created with a deterministic id and
  /// republished to the registry so every device converges.
  Future<int> _recoverTagsFromHourlyLogs({
    required List<TrackerTag> local,
    required List<({TrackerTag tag, bool deleted, DateTime updatedAt})>
        registry,
  }) async {
    final tombstonedAt = <String, DateTime>{};
    for (final record in registry) {
      if (!record.deleted) continue;
      final key = record.tag.name.trim().toLowerCase();
      final existing = tombstonedAt[key];
      if (existing == null || record.updatedAt.isAfter(existing)) {
        tombstonedAt[key] = record.updatedAt;
      }
    }

    final knownNames = local.map((t) => t.name.trim().toLowerCase()).toSet();
    final candidates = <String, ({String name, String icon, DateTime used})>{};
    for (final log in Prefs.hourlyLogs) {
      final name = log.tagName.trim();
      if (name.isEmpty || name.toLowerCase() == 'activity') continue;
      final key = name.toLowerCase();
      final existing = candidates[key];
      if (existing == null || log.loggedAt.isAfter(existing.used)) {
        candidates[key] = (name: name, icon: log.tagIcon, used: log.loggedAt);
      }
    }

    var recovered = 0;
    for (final entry in candidates.entries) {
      if (knownNames.contains(entry.key)) {
        final canonical = TrackerTagHelper.findDuplicate(
          entry.value.name,
          existing: local,
        );
        if (canonical != null) {
          recovered += await TagReassignHelper.rewriteOrphanLogsToCanonical(
            canonical: canonical,
            notionSync: this,
          );
        }
        continue;
      }
      final deletedAt = tombstonedAt[entry.key];
      // A deletion newer than the tag's last use wins; the user removed it
      // on purpose and we must not resurrect it on every sync.
      if (deletedAt != null && deletedAt.isAfter(entry.value.used)) {
        continue;
      }

      final slug = entry.key.replaceAll(RegExp('[^a-z0-9]'), '_');
      final colorIndex = slug.codeUnits.fold<int>(0, (sum, c) => sum + c) %
          _recoveredTagPalette.length;
      final tag = TrackerTag(
        id: 'tag_custom_recovered_$slug',
        name: entry.value.name,
        icon: entry.value.icon.isNotEmpty ? entry.value.icon : '⏱️',
        colorHex: _recoveredTagPalette[colorIndex],
      );

      local.add(tag);
      knownNames.add(entry.key);
      recovered++;
      Logger().i(
        'NotionSyncService: Recovered legacy activity tag '
        '"${tag.icon} ${tag.name}" from hourly logs.',
      );
      try {
        await NotionService().syncActivityTag(tag);
      } catch (e) {
        Logger().w(
          'NotionSyncService: Failed to publish recovered tag '
          '"${tag.name}" ($e)',
        );
      }
    }
    return recovered;
  }

  /// Saves a custom tag locally and publishes it to the shared registry.
  Future<void> saveActivityTag(TrackerTag tag) async {
    await Prefs.saveTrackerTag(tag);
    if (!Prefs.enableNotionSync ||
        Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty ||
        Prefs.notionApiKey.isEmpty) {
      await TagRegistryWriter.writeIfPossible();
      return;
    }
    try {
      await NotionService().syncActivityTag(tag);
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Failed to publish activity tag ($e)',
        error: e,
        stackTrace: st,
      );
    }
    await TagRegistryWriter.writeIfPossible();
  }

  /// Reassigns hourly logs then deletes a custom tag.
  Future<int> reassignAndDeleteActivityTag({
    required TrackerTag from,
    required TrackerTag to,
  }) async {
    final count = await TagReassignHelper.reassignTagId(
      fromId: from.id,
      toTag: to,
      notionSync: this,
    );
    await deleteActivityTag(from);
    await TagRegistryWriter.writeIfPossible();
    return count;
  }

  /// Deletes a custom tag locally and publishes a tombstone to all devices.
  Future<void> deleteActivityTag(TrackerTag tag) async {
    await Prefs.deleteTrackerTag(tag.id);
    if (!Prefs.enableNotionSync ||
        Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty ||
        Prefs.notionApiKey.isEmpty) {
      await TagRegistryWriter.writeIfPossible();
      return;
    }
    try {
      await NotionService().syncActivityTag(tag, deleted: true);
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Failed to publish activity tag deletion ($e)',
        error: e,
        stackTrace: st,
      );
    }
    await TagRegistryWriter.writeIfPossible();
  }

  void _removePendingHourlyLogsForHour(String dateStr, int hour) {
    final remaining = <String>[];
    for (final item in Prefs.pendingHourlyLogs) {
      try {
        final data = jsonDecode(item) as Map<String, dynamic>;
        if (data['dateStr'] == dateStr && data['hour'] == hour) {
          continue;
        }
      } catch (_) {
        // Preserve malformed entries so the normal flush path can report them.
      }
      remaining.add(item);
    }
    Prefs.pendingHourlyLogs = remaining;
  }

  void _enqueuePendingHourlyLog(HourlyLog log) {
    try {
      final payload = jsonEncode(log.toJson());
      final queue = List<String>.from(Prefs.pendingHourlyLogs)..add(payload);
      Prefs.pendingHourlyLogs = queue;
      Logger().i(
        'NotionSyncService: Enqueued pending hourly log offline '
        '(${queue.length} items).',
      );
    } catch (e) {
      Logger().e('NotionSyncService: Failed to enqueue pending hourly log: $e');
    }
  }

  /// Attempts to retry syncing all offline pending hourly logs stored in
  /// [Prefs.pendingHourlyLogs].
  Future<int> flushPendingHourlyLogs() async {
    if (!Prefs.enableNotionSync || Prefs.notionApiKey.isEmpty) {
      return 0;
    }

    if (Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty) {
      return 0;
    }

    final queue = List<String>.from(Prefs.pendingHourlyLogs);
    if (queue.isEmpty) return 0;

    Logger().i(
      'NotionSyncService: Flushing ${queue.length} pending hourly logs...',
    );
    final remainingQueue = <String>[];
    var flushedCount = 0;

    for (final item in queue) {
      try {
        final data = jsonDecode(item) as Map<String, dynamic>;
        final log = HourlyLog.fromJson(data);

        final result = await NotionService().syncHourlyLog(log);
        if (result.success) {
          flushedCount++;
          if (result.log.notionPageId != null) {
            await Prefs.saveHourlyLog(result.log);
          }
        } else {
          remainingQueue.add(item);
        }
      } catch (e) {
        Logger()
            .w('NotionSyncService: Failed to flush pending hourly log ($e)');
        remainingQueue.add(item);
      }
    }

    Prefs.pendingHourlyLogs = remainingQueue;
    Logger().i(
      'NotionSyncService: Flushed $flushedCount pending hourly logs '
      '(${remainingQueue.length} remaining).',
    );
    return flushedCount;
  }

  void _enqueuePendingLog({
    required NotionTask task,
    required int durationMinutes,
    required int totalDurationMinutes,
    required DateTime endedAt,
    String? existingLogPageId,
  }) {
    try {
      final payload = jsonEncode({
        'taskId': task.id,
        'taskTitle': task.title,
        'durationMinutes': durationMinutes,
        'totalDurationMinutes': totalDurationMinutes,
        'endedAt': endedAt.toUtc().toIso8601String(),
        'existingLogPageId': existingLogPageId,
      });
      final queue = List<String>.from(Prefs.pendingTimeLogs)..add(payload);
      Prefs.pendingTimeLogs = queue;
      Logger().i(
        'NotionSyncService: Enqueued pending time log offline '
        '(${queue.length} items).',
      );
    } catch (e) {
      Logger().e('NotionSyncService: Failed to enqueue pending time log: $e');
    }
  }

  /// Attempts to retry logging all offline pending time logs stored in
  /// [Prefs.pendingTimeLogs].
  Future<int> flushPendingLogs() async {
    if (!Prefs.enableNotionSync || Prefs.notionApiKey.isEmpty) {
      return 0;
    }

    final queue = List<String>.from(Prefs.pendingTimeLogs);
    if (queue.isEmpty) return 0;

    Logger()
        .i('NotionSyncService: Flushing ${queue.length} pending time logs...');
    final remainingQueue = <String>[];
    var flushedCount = 0;

    for (final item in queue) {
      try {
        final data = jsonDecode(item) as Map<String, dynamic>;
        final taskId = data['taskId'] as String? ?? '';
        final taskTitle = data['taskTitle'] as String? ?? '';
        final durationMin = data['durationMinutes'] as int? ?? 0;
        final totalMin = data['totalDurationMinutes'] as int? ?? durationMin;
        final endedAtStr = data['endedAt'] as String?;
        final existingPageId = data['existingLogPageId'] as String?;

        if (taskId.isEmpty || durationMin < 1) continue;

        final endedAt = endedAtStr != null
            ? DateTime.tryParse(endedAtStr) ?? DateTime.now()
            : DateTime.now();

        final task = NotionTask(id: taskId, title: taskTitle);

        final result = await NotionService().logSession(
          task: task,
          creditMinutes: durationMin,
          totalDurationMinutes: totalMin,
          endedAt: endedAt,
          existingLogPageId: existingPageId,
        );

        if (result.success) {
          flushedCount++;
          final currentActive = Prefs.activeTask;
          if (currentActive != null && currentActive.id == task.id) {
            final newMath = NotionService.addDuration(
              currentHours: currentActive.timeHours,
              currentMinutes: currentActive.timeMinutes,
              addMin: durationMin,
            );
            Prefs.activeTask = currentActive.copyWith(
              timeHours: () => newMath.hours,
              timeMinutes: () => newMath.minutes,
            );
          }
        } else {
          remainingQueue.add(item);
        }
      } catch (e) {
        Logger().w('NotionSyncService: Failed to flush pending item ($e)');
        remainingQueue.add(item);
      }
    }

    Prefs.pendingTimeLogs = remainingQueue;
    Logger().i(
      'NotionSyncService: Flushed $flushedCount pending logs '
      '(${remainingQueue.length} remaining).',
    );
    return flushedCount;
  }

  /// Moves a task from 'To Do' to 'In Progress' in Notion and updates local
  /// state if needed.
  Future<NotionTask?> moveToInProgressIfNeeded(NotionTask? task) async {
    if (task == null || task.id.isEmpty) return task;
    final currentStatus = task.status.trim().toLowerCase();
    if (currentStatus != 'to do' &&
        currentStatus != 'todo' &&
        currentStatus != 'to-do') {
      return task;
    }

    if (!Prefs.enableNotionSync && !kIsWeb && Prefs.notionApiKey.isEmpty) {
      return task;
    }

    Logger().i(
      'NotionSyncService: Moving task "${task.title}" (${task.id}) '
      'from "${task.status}" to "In Progress"...',
    );

    try {
      final success = await NotionService().updateTaskStatus(
        taskId: task.id,
        newStatus: 'In Progress',
      );

      if (success) {
        final updatedTask = task.copyWith(status: () => 'In Progress');
        final currentActive = Prefs.activeTask;
        if (currentActive != null && currentActive.id == task.id) {
          Prefs.activeTask =
              currentActive.copyWith(status: () => 'In Progress');
        }
        return updatedTask;
      }
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Failed to move task to In Progress ($e)',
        error: e,
        stackTrace: st,
      );
    }

    return task;
  }
}
