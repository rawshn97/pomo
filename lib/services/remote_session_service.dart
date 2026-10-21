import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pomo/models/remote_session.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/services/android_notification_service.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// Service coordinating cross-device focus presence.
/// Broadcasts local focus sessions and queries active sessions on linked
/// devices.
class RemoteSessionService {
  factory RemoteSessionService() => _instance;
  RemoteSessionService._internal() : _dio = Dio();

  static final RemoteSessionService _instance =
      RemoteSessionService._internal();

  final Dio _dio;
  Timer? _pollingTimer;
  Timer? _broadcastTimer;

  /// Holds the current active session reported by a remote device, if any.
  final ValueNotifier<RemoteSession?> remoteSessionNotifier =
      ValueNotifier<RemoteSession?>(null);

  /// Resolves the presence endpoint URL from the configured Notion proxy.
  @visibleForTesting
  String get sessionEndpoint {
    final base = NotionService().getBaseUrl();
    if (base.contains('/api/notion/')) {
      return base.replaceAll('/api/notion/', '/api/session');
    }
    final uri = Uri.parse(base);
    return '${uri.origin}/api/session';
  }

  /// Platform-specific display name for this client.
  @visibleForTesting
  String get deviceName {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Mobile';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Device';
  }

  Map<String, String> _headers(String apiKey) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  /// Starts polling for remote focus sessions every 10 seconds.
  /// Used when the local device is idle/stopped.
  void startPolling() {
    _pollingTimer?.cancel();
    fetchRemoteSession();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => fetchRemoteSession(),
    );
  }

  /// Stops polling for remote sessions.
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Queries the relay endpoint for active remote sessions.
  Future<void> fetchRemoteSession() async {
    final apiKey = Prefs.notionApiKey;
    if (apiKey.isEmpty) {
      remoteSessionNotifier.value = null;
      return;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        sessionEndpoint,
        options: Options(
          headers: _headers(apiKey),
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      final data = response.data;
      if (data != null && data['active'] == true && data['session'] != null) {
        final session = RemoteSession.fromJson(
          data['session'] as Map<String, dynamic>,
        );
        // Ignore sessions originating from this exact device
        if (session.deviceId != Prefs.deviceId) {
          remoteSessionNotifier.value = session;
          if (!kIsWeb && Platform.isAndroid && session.isRunning) {
            _syncAndroidNotification(session);
          }
          return;
        }
      }
      if (!kIsWeb &&
          Platform.isAndroid &&
          remoteSessionNotifier.value != null) {
        unawaited(AndroidNotificationService().stopForeground());
      }
      remoteSessionNotifier.value = null;
    } catch (e) {
      // Non-blocking presence probe failure
      Logger().d('RemoteSessionService fetch failed: $e');
    }
  }

  void _syncAndroidNotification(RemoteSession session) {
    try {
      final tagText = session.tagName ?? 'Focus Session';
      final taskText = session.taskTitle;
      final displayContent =
          taskText != null ? '$tagText • $taskText' : tagText;
      AndroidNotificationService().updateNotificationRaw(
        title: session.formattedRemaining,
        text: '${session.deviceName} is focusing: $displayContent',
        isRunning: session.isRunning,
        subText: 'Remote Focus • Lap #${session.lapNumber}',
        bigText: 'Remote focus active on ${session.deviceName}\n'
            'Remaining: ${session.formattedRemaining}\n'
            'Activity: ${session.tagIcon ?? ''} ${session.tagName ?? 'None'}\n'
            'Task: ${session.taskTitle ?? 'No task selected'}',
      );
    } catch (_) {
      // Non-blocking notification sync
    }
  }

  /// Broadcasts local focus session state to the relay.
  Future<void> broadcastSession({
    required TimerState timerState,
    required SettingsState settingsState,
  }) async {
    final apiKey = Prefs.notionApiKey;
    if (apiKey.isEmpty) return;

    final lapMins = timerState.lap == TimerLap.work
        ? settingsState.workMinutes
        : (timerState.lap == TimerLap.shortBreak
            ? settingsState.shortBreakMinutes
            : settingsState.longBreakMinutes);
    final totalSecs = lapMins * 60;
    final remainingSecs = (totalSecs - timerState.duration.inSeconds).clamp(
      0,
      totalSecs,
    );

    final payload = {
      'deviceId': Prefs.deviceId,
      'deviceName': deviceName,
      'status': timerState.status == TimerStatus.running ? 'running' : 'paused',
      'lap': timerState.lap.name,
      'lapNumber': timerState.lapNumber > 0 ? timerState.lapNumber : 1,
      'remainingSeconds': remainingSecs,
      'totalSeconds': totalSecs,
      'tagName': timerState.activeTags.isNotEmpty
          ? timerState.activeTags.first.name
          : null,
      'tagIcon': timerState.activeTags.isNotEmpty
          ? timerState.activeTags.first.icon
          : null,
      'taskTitle': (timerState.activeTask?.title.isNotEmpty ?? false)
          ? timerState.activeTask!.title
          : null,
    };

    try {
      await _dio.post<Map<String, dynamic>>(
        sessionEndpoint,
        data: payload,
        options: Options(
          headers: _headers(apiKey),
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      Logger().d('RemoteSessionService broadcast failed: $e');
    }
  }

  /// Reports that the local session has ended or stopped.
  Future<void> reportStopped() async {
    final apiKey = Prefs.notionApiKey;
    if (apiKey.isEmpty) return;

    try {
      await _dio.post<Map<String, dynamic>>(
        sessionEndpoint,
        data: {
          'deviceId': Prefs.deviceId,
          'status': 'stopped',
        },
        options: Options(
          headers: _headers(apiKey),
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      Logger().d('RemoteSessionService stop report failed: $e');
    }
  }

  /// Starts repeating broadcasts every 10 seconds while local timer is active.
  void startRepeatingBroadcast({
    required TimerState timerState,
    required SettingsState settingsState,
  }) {
    _broadcastTimer?.cancel();
    unawaited(
      broadcastSession(
        timerState: timerState,
        settingsState: settingsState,
      ),
    );
    _broadcastTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        unawaited(
          broadcastSession(
            timerState: timerState,
            settingsState: settingsState,
          ),
        );
      },
    );
  }

  /// Stops repeating broadcasts.
  void stopRepeatingBroadcast() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    unawaited(reportStopped());
  }

  void dispose() {
    stopPolling();
    stopRepeatingBroadcast();
    remoteSessionNotifier.dispose();
  }
}
