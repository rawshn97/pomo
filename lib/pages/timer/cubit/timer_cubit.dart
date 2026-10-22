import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/helpers/hourly_log_writer.dart';
import 'package:pomo/helpers/lap_helper.dart';
import 'package:pomo/helpers/sound_helper.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/models/remote_session.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';

part 'timer_state.dart';

class TimerCubit extends Cubit<TimerState> {
  TimerCubit({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(
          TimerState(
            duration: Prefs.duration,
            status: Prefs.timerStatus,
            lap: Prefs.timerLap,
            lapNumber: Prefs.lapNumber,
            activeTask: Prefs.activeTask,
            activeLogPageId: Prefs.activeLogPageId,
            activeTags: Prefs.lastTimerTags,
          ),
        );

  final DateTime Function() _clock;
  bool _isMovingToInProgress = false;
  bool _isCreatingRecord = false;
  DateTime? _tagSegmentStartedAt;
  int _tagCreditedMinutes = 0;

  void _checkAndMoveActiveTaskToInProgress() {
    final currentTask = state.activeTask;
    if (currentTask != null &&
        !_isMovingToInProgress &&
        (currentTask.status.trim().toLowerCase() == 'to do' ||
            currentTask.status.trim().toLowerCase() == 'todo' ||
            currentTask.status.trim().toLowerCase() == 'to-do')) {
      _isMovingToInProgress = true;
      NotionSyncService().moveToInProgressIfNeeded(currentTask).then((updated) {
        _isMovingToInProgress = false;
        if (updated != null &&
            state.activeTask?.id == updated.id &&
            updated.status == 'In Progress') {
          emit(state.copyWith(activeTask: () => updated));
        }
      }).catchError((_) {
        _isMovingToInProgress = false;
      });
    }
  }

  /// Creates a new Notion Time Log record for the current session.
  /// Called when the timer starts for the first time in a work lap.
  void _createNotionRecord() {
    if (!Prefs.enableTimeTracker) return;
    if (state.lap != TimerLap.work) return;
    if (state.activeLogPageId != null) return; // Already has a record
    if (_isCreatingRecord) return;

    _isCreatingRecord = true;
    final taskToSync = state.activeTask;
    final primaryTag =
        state.activeTags.isNotEmpty ? state.activeTags.first : null;
    final startedAt = DateTime.now();

    NotionSyncService()
        .createSessionRecord(
      task: taskToSync,
      primaryTag: primaryTag,
      startedAt: startedAt,
    )
        .then((pageId) {
      _isCreatingRecord = false;
      if (pageId != null && state.activeTask?.id == taskToSync?.id) {
        Prefs.activeLogPageId = pageId;
        Prefs.syncedMinutes = 0;
        emit(state.copyWith(activeLogPageId: () => pageId));
        Logger().i('TimerCubit: Session record created: $pageId');
      }
    }).catchError((Object e) {
      _isCreatingRecord = false;
      Logger().w('TimerCubit: Failed to create session record: $e');
    });
  }

  /// Updates the existing Notion Time Log record with current elapsed time.
  /// Called on pause (stop).
  void _updateNotionRecord() {
    if (!Prefs.enableTimeTracker) return;
    if (state.lap != TimerLap.work) return;

    final totalMinutes = state.duration.inMinutes;
    if (totalMinutes < 1) return; // Skip update if less than 1 minute

    final taskToSync = state.activeTask;
    final primaryTag =
        state.activeTags.isNotEmpty ? state.activeTags.first : null;
    final logPageId = state.activeLogPageId;

    NotionSyncService()
        .updateSessionRecord(
      task: taskToSync,
      primaryTag: primaryTag,
      totalElapsed: state.duration,
      existingLogPageId: logPageId,
      endedAt: DateTime.now(),
    )
        .then((result) {
      if (result.success && state.activeTask?.id == taskToSync?.id) {
        // Update page ID if it was created as a fallback
        if (result.logPageId != null &&
            result.logPageId != state.activeLogPageId) {
          Prefs.activeLogPageId = result.logPageId;
          emit(state.copyWith(activeLogPageId: () => result.logPageId));
        }
        final updated = Prefs.activeTask;
        if (updated != null) {
          emit(state.copyWith(activeTask: () => updated));
        }
      }
    });
  }

  /// Finalizes the current session by either deleting it (if under 1 minute)
  /// or updating it with the final elapsed time (if 1 minute or more).
  /// Called when resetting the timer, changing/clearing tasks, or changing laps.
  ///
  /// When [TimerState.activeLogPageId] is still null (create at start failed
  /// or is in flight), still call [NotionSyncService.updateSessionRecord]
  /// so auto-advance lap changes do not drop completed focus time.
  void _finalizeSession() {
    if (!Prefs.enableTimeTracker) return;
    if (state.lap != TimerLap.work) return;

    final logPageId = state.activeLogPageId;
    final alreadySynced = Prefs.syncedMinutes;
    final totalMinutes = state.duration.inMinutes;

    if (totalMinutes < 1) {
      if (logPageId != null && logPageId.isNotEmpty) {
        NotionSyncService().deleteSessionRecord(logPageId);
      }
      return;
    }

    final taskToSync = state.activeTask;
    final primaryTag =
        state.activeTags.isNotEmpty ? state.activeTags.first : null;

    NotionSyncService().updateSessionRecord(
      task: taskToSync,
      primaryTag: primaryTag,
      totalElapsed: state.duration,
      existingLogPageId: logPageId,
      endedAt: DateTime.now(),
      previouslySyncedMinutes: alreadySynced,
    );
  }

  void _creditActiveTags() {
    if (!Prefs.enableTimeTracker) {
      return;
    }
    if (state.lap != TimerLap.work) {
      return;
    }
    if (state.activeTags.isEmpty) {
      return;
    }
    final uncredited = state.duration.inMinutes - _tagCreditedMinutes;
    if (uncredited < 1) {
      return;
    }
    final endedAt = _clock();
    final startedAt =
        _tagSegmentStartedAt ?? endedAt.subtract(Duration(minutes: uncredited));
    unawaited(
      HourlyLogWriter.creditTimerMinutes(
        tags: List<TrackerTag>.from(state.activeTags),
        from: startedAt,
        to: endedAt,
        totalMinutes: uncredited,
        loggedAt: endedAt,
      ),
    );
    _tagCreditedMinutes += uncredited;
  }

  void _beginTagSegment() {
    if (state.lap == TimerLap.work) {
      _tagSegmentStartedAt = _clock();
    }
  }

  void _persistActiveTags(List<TrackerTag> tags) {
    Prefs.lastTimerTagIds = tags.map((tag) => tag.id).toList();
    emit(state.copyWith(activeTags: () => tags));
  }

  /// Whether activity tags can be added, removed, or toggled.
  ///
  /// Locked while a work lap is running so hourly credit cannot split across
  /// mid-session tag changes.
  bool get canModifyTags =>
      state.status != TimerStatus.running || state.lap != TimerLap.work;

  /// Set active tags on the timer (used e.g. when taking over a session).
  void setActiveTags(List<TrackerTag> tags) {
    if (!canModifyTags) return;
    _persistActiveTags(tags);
  }

  /// Silently stops and resets the local timer when another linked device
  /// takes over the focus session. Does NOT finalize or log partial minutes
  /// to Notion because the active session continues on the destination device.
  void resetForRemoteTakeover() {
    _tagSegmentStartedAt = null;
    _tagCreditedMinutes = 0;
    Prefs.duration = Duration.zero;
    Prefs.timerStatus = TimerStatus.stopped;

    emit(
      state.copyWith(
        status: () => TimerStatus.stopped,
        duration: () => Duration.zero,
      ),
    );
  }

  /// Adopt a remote focus session from another linked device (Take Over).
  /// Synchronizes elapsed lap duration, lap type, lap number, and tag,
  /// then immediately starts the local countdown.
  void adoptRemoteSession(RemoteSession session) {
    final lap = TimerLap.values.firstWhere(
      (l) => l.name == session.lap,
      orElse: () => TimerLap.work,
    );
    final elapsedSecs = (session.totalSeconds - session.remainingSeconds).clamp(
      0,
      session.totalSeconds,
    );
    final newDuration = Duration(seconds: elapsedSecs);
    Prefs.duration = newDuration;
    Prefs.timerLap = lap;
    final lapNumber = session.lapNumber > 0 ? session.lapNumber : 1;
    Prefs.lapNumber = lapNumber;
    Prefs.timerStatus = TimerStatus.running;

    var tags = state.activeTags;
    if (session.tagName != null) {
      final matches = Prefs.trackerTags.where(
        (t) => t.name == session.tagName,
      );
      if (matches.isNotEmpty) {
        tags = [matches.first];
      } else {
        tags = [
          TrackerTag(
            id: 'remote_${session.tagName}',
            name: session.tagName!,
            icon: session.tagIcon ?? '🎯',
            colorHex: '#4285F4',
          ),
        ];
      }
      Prefs.lastTimerTagIds = tags.map((t) => t.id).toList();
    }

    emit(
      state.copyWith(
        status: () => TimerStatus.running,
        duration: () => newDuration,
        lap: () => lap,
        lapNumber: () => lapNumber,
        activeTags: () => tags,
      ),
    );

    _beginTagSegment();
  }

  /// Toggle an activity tag used for hourly credit.
  ///
  /// Returns false when [canModifyTags] is false.
  bool toggleTag(TrackerTag tag) {
    if (!canModifyTags) {
      return false;
    }
    final next = List<TrackerTag>.from(state.activeTags);
    if (next.any((item) => item.id == tag.id)) {
      next.removeWhere((item) => item.id == tag.id);
    } else {
      next.add(tag);
    }
    _persistActiveTags(next);
    return true;
  }

  /// Drop a tag from the timer selection after it is deleted.
  void removeActiveTag(String tagId) {
    final next = state.activeTags.where((tag) => tag.id != tagId).toList();
    _persistActiveTags(next);
  }

  /// Replace a deleted tag with its reassignment target in the selection.
  void replaceActiveTag({
    required String fromId,
    required TrackerTag toTag,
  }) {
    final next = state.activeTags
        .where((tag) => tag.id != fromId)
        .toList(growable: true);
    if (!next.any((tag) => tag.id == toTag.id)) {
      next.add(toTag);
    }
    _persistActiveTags(next);
  }

  void start() {
    emit(
      state.copyWith(
        status: () => TimerStatus.running,
      ),
    );

    Prefs.timerStatus = TimerStatus.running;
    _beginTagSegment();

    if (state.lap == TimerLap.work && state.activeTask != null) {
      _checkAndMoveActiveTaskToInProgress();
      // Create a Notion record on first start of this session
      _createNotionRecord();
    }
  }

  void stop() {
    _creditActiveTags();
    _updateNotionRecord();
    _tagSegmentStartedAt = null;

    emit(
      state.copyWith(
        status: () => TimerStatus.stopped,
      ),
    );

    Prefs.timerStatus = TimerStatus.stopped;
  }

  void reset() {
    _creditActiveTags();
    _finalizeSession();

    final currentTask = state.activeTask;
    final currentTags = state.activeTags;
    emit(TimerState(activeTask: currentTask, activeTags: currentTags));
    _tagCreditedMinutes = 0;
    _tagSegmentStartedAt = null;

    Prefs.resetTimer();
  }

  void selectTask(NotionTask? task) {
    if (state.activeTask?.id != task?.id) {
      final wasRunning = state.status == TimerStatus.running;

      _creditActiveTags();
      _finalizeSession();
      _tagCreditedMinutes = 0;

      Prefs.duration = Duration.zero;
      Prefs.clearSessionSyncState();
      Prefs.activeTask = task;
      emit(
        state.copyWith(
          activeTask: () => task,
          duration: () => Duration.zero,
          activeLogPageId: () => null,
        ),
      );
      if (task != null && state.lap == TimerLap.work) {
        _checkAndMoveActiveTaskToInProgress();
        // D2-A: keep timer running and open a new session for the new task
        if (wasRunning) {
          _beginTagSegment();
          _createNotionRecord();
        }
      }
    }
  }

  void clearTask() {
    _creditActiveTags();
    _finalizeSession();
    _tagCreditedMinutes = 0;

    Prefs.duration = Duration.zero;
    Prefs.clearSessionSyncState();
    Prefs.activeTask = null;
    emit(
      state.copyWith(
        activeTask: () => null,
        duration: () => Duration.zero,
        activeLogPageId: () => null,
      ),
    );
    if (state.status == TimerStatus.running && state.lap == TimerLap.work) {
      _beginTagSegment();
    }
  }

  void lap({required SettingsState settingsState, bool autoAdvance = true}) {
    _creditActiveTags();
    _finalizeSession();
    _tagCreditedMinutes = 0;
    _tagSegmentStartedAt = null;

    final nextLap = LapHelper.getNextLap(
      state.lap,
      state.lapNumber,
      settingsState.lapCount,
    );

    final nextLapNumber = (state.lapNumber + 1) % (settingsState.lapCount * 2);

    emit(
      state.copyWith(
        duration: () => Duration.zero,
        activeLogPageId: () => null,
        lapNumber: () => nextLapNumber,
        lap: () => nextLap,
        status: !autoAdvance ? () => TimerStatus.stopped : null,
      ),
    );

    Prefs.timerLap = nextLap;
    Prefs.duration = Duration.zero;
    Prefs.clearSessionSyncState();
    Prefs.lapNumber = nextLapNumber;
    Prefs.timerStatus = !autoAdvance ? TimerStatus.stopped : state.status;

    // If auto-advancing into a new work lap with a task, create a new record
    if (autoAdvance &&
        nextLap == TimerLap.work &&
        state.activeTask != null &&
        state.status == TimerStatus.running) {
      _createNotionRecord();
    }
    if (autoAdvance &&
        nextLap == TimerLap.work &&
        state.status == TimerStatus.running) {
      _beginTagSegment();
    }
  }

  /// Adds the given [duration] to the current [TimerState.duration].
  /// If no [duration] is provided, it defaults to 1 second.
  void tick(
    SettingsState settingsState, [
    Duration duration = const Duration(seconds: 1),
  ]) {
    if (state.status != TimerStatus.running) {
      return;
    }

    if (state.lap == TimerLap.work && state.activeTask != null) {
      _checkAndMoveActiveTaskToInProgress();
    }

    final newDuration = state.duration + duration;
    emit(state.copyWith(duration: () => newDuration));
    Prefs.duration = newDuration;

    final isLapComplete = DurationHelper.isLapComplete(
      duration: newDuration,
      lap: state.lap,
      settingsState: settingsState,
    );

    if (isLapComplete) {
      if (!settingsState.autoAdvance) {
        stop();
      }
      lap(settingsState: settingsState);
      return;
    }
  }

  void toggle() {
    if (state.status == TimerStatus.running) {
      stop();
    } else {
      start();
    }
  }

  bool checkAndPlaySound({
    required SettingsState settingsState,
    DateTime? now,
  }) {
    if (!settingsState.enableSound) return false;
    if (settingsState.enableQuietHours &&
        SoundHelper.isQuietHours(
          start: settingsState.quietHoursStart,
          end: settingsState.quietHoursEnd,
          now: now,
        )) {
      return false;
    }
    return true;
  }
}
