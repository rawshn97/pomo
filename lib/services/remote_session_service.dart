import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pomo/models/remote_session.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/services/android_notification_service.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service coordinating cross-device focus presence.
/// Broadcasts local focus sessions and queries active sessions on linked
/// devices via Cloudflare Edge Worker WebSockets and HTTP REST relay.
class RemoteSessionService {
  factory RemoteSessionService() => _instance;
  RemoteSessionService._internal() : _dio = Dio();

  static final RemoteSessionService _instance =
      RemoteSessionService._internal();

  final Dio _dio;
  Timer? _pollingTimer;
  Timer? _broadcastTimer;
  Timer? _remoteTickTimer;
  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSubscription;
  bool _isWsConnected = false;

  /// Holds the current active session reported by a remote device, if any.
  final ValueNotifier<RemoteSession?> remoteSessionNotifier =
      ValueNotifier<RemoteSession?>(null);

  /// Whether a WebSocket connection to the sync relay is active.
  bool get isWebSocketConnected => _isWsConnected;

  /// Default live Cloudflare Edge Worker sync relay endpoint.
  static const String defaultCloudflareSyncEndpoint =
      'https://pomo-sync.mishra-roshanraj.workers.dev/api/session';

  /// Resolves the presence endpoint URL.
  /// Priority:
  /// 1. Explicitly configured Prefs.syncRelayUrl
  /// 2. Deployed Cloudflare Edge Worker (sub-20ms WebSocket + Durable Objects)
  /// 3. Notion proxy / Vercel relay fallback
  @visibleForTesting
  String get sessionEndpoint {
    if (Prefs.syncRelayUrl.isNotEmpty) {
      return Prefs.syncRelayUrl;
    }
    return defaultCloudflareSyncEndpoint;
  }

  /// Resolves the WebSocket presence endpoint URL from the session endpoint.
  @visibleForTesting
  String get wsEndpoint {
    final endpoint = sessionEndpoint;
    final uri = Uri.parse(endpoint);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$wsScheme://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/ws';
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

  /// Connects to the Cloudflare Edge Worker WebSocket endpoint.
  Future<void> connectWebSocket() async {
    try {
      await disconnectWebSocket();
      final uri = Uri.parse(wsEndpoint);
      final apiKey = Prefs.notionApiKey;
      final authUri = apiKey.isNotEmpty
          ? uri.replace(queryParameters: {'token': apiKey})
          : uri;
      _wsChannel = WebSocketChannel.connect(authUri);
      _wsSubscription = _wsChannel!.stream.listen(
        (message) {
          _isWsConnected = true;
          _handleWsMessage(message);
        },
        onError: (dynamic error) {
          _isWsConnected = false;
          Logger().d('RemoteSessionService WS error: $error');
        },
        onDone: () {
          _isWsConnected = false;
        },
      );
    } catch (e) {
      _isWsConnected = false;
      Logger().d('RemoteSessionService WS connect failed: $e');
    }
  }

  /// Disconnects the active WebSocket connection.
  Future<void> disconnectWebSocket() async {
    _isWsConnected = false;
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void _handleWsMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type == 'SESSION_UPDATE' && data['session'] != null) {
        final session = RemoteSession.fromJson(
          data['session'] as Map<String, dynamic>,
        );
        if (session.deviceId != Prefs.deviceId) {
          remoteSessionNotifier.value = session;
          if (session.isRunning) {
            _startRemoteTick(session);
            if (!kIsWeb && Platform.isAndroid) {
              _syncAndroidNotification(session);
            }
          } else {
            _stopRemoteTick();
            if (!kIsWeb && Platform.isAndroid) {
              unawaited(AndroidNotificationService().stopForeground());
            }
          }
          return;
        }
      } else if (type == 'SESSION_IDLE') {
        _stopRemoteTick();
        if (!kIsWeb &&
            Platform.isAndroid &&
            remoteSessionNotifier.value != null) {
          unawaited(AndroidNotificationService().stopForeground());
        }
        remoteSessionNotifier.value = null;
      }
    } catch (e) {
      Logger().d('Error decoding WS message: $e');
    }
  }

  /// Starts polling for remote focus sessions every 10 seconds and establishes
  /// a WebSocket connection to the Cloudflare Edge Worker.
  /// Used when the local device is idle/stopped.
  void startPolling() {
    _pollingTimer?.cancel();
    unawaited(connectWebSocket());
    fetchRemoteSession();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => fetchRemoteSession(),
    );
  }

  /// Stops polling for remote sessions and disconnects the WebSocket.
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _stopRemoteTick();
    unawaited(disconnectWebSocket());
  }

  /// Queries the relay endpoint for active remote sessions.
  Future<void> fetchRemoteSession() async {
    final apiKey = Prefs.notionApiKey;

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
          if (session.isRunning) {
            _startRemoteTick(session);
            if (!kIsWeb && Platform.isAndroid) {
              _syncAndroidNotification(session);
            }
          } else {
            _stopRemoteTick();
            if (!kIsWeb && Platform.isAndroid) {
              unawaited(AndroidNotificationService().stopForeground());
            }
          }
          return;
        }
      }
      _stopRemoteTick();
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

  void _startRemoteTick(RemoteSession session) {
    _remoteTickTimer?.cancel();
    if (!session.isRunning || session.remainingSeconds <= 0) return;

    _remoteTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = remoteSessionNotifier.value;
      if (current == null ||
          !current.isRunning ||
          current.remainingSeconds <= 0) {
        _stopRemoteTick();
        return;
      }
      final updated = current.copyWith(
        remainingSeconds: current.remainingSeconds - 1,
      );
      remoteSessionNotifier.value = updated;
      if (!kIsWeb && Platform.isAndroid) {
        _syncAndroidNotification(updated);
      }
    });
  }

  void _stopRemoteTick() {
    _remoteTickTimer?.cancel();
    _remoteTickTimer = null;
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

    // Push immediately over WebSocket if connected (<20ms edge broadcast)
    if (_isWsConnected && _wsChannel != null) {
      try {
        _wsChannel!.sink.add(
          jsonEncode({
            'type': 'BROADCAST_SESSION',
            'payload': payload,
          }),
        );
      } catch (_) {}
    }

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

    // Push immediately over WebSocket if connected (<20ms edge broadcast)
    if (_isWsConnected && _wsChannel != null) {
      try {
        _wsChannel!.sink.add(
          jsonEncode({
            'type': 'STOP_SESSION',
          }),
        );
      } catch (_) {}
    }

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
