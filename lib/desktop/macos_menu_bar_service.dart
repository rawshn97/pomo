import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/app/view/app.dart';
import 'package:pomo/desktop/desktop_window_service.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/helpers/session_helper.dart';
import 'package:pomo/models/remote_session.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/services/remote_session_service.dart';

class MacosMenuBarService {
  MacosMenuBarService._();

  static final MacosMenuBarService instance = MacosMenuBarService._();

  static const _channel = MethodChannel('pomo/menu_bar');
  static const _trayIconAsset = 'assets/images/pomo_splash_64.png';
  static const _idleTrayTitle = 'Pomo';

  static bool _iconReady = false;
  static bool _listenerAttached = false;
  TimerCubit? _timerCubit;
  bool? _menuIsRunning;
  bool? _menuSessionActive;

  static Future<void> init(BuildContext context) async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    // Always reset on every init() call. When flutter run re-attaches to an
    // already-running process (hot-reload reconnect, Dart VM resume, or
    // DesktopShell remount) the static _iconReady flag from the previous
    // session is still true, which silently skips sending setIcon/setTitle to
    // the native layer even though the NSStatusItem button title was cleared.
    _iconReady = false;
    _listenerAttached = false;

    final timerCubit = context.read<TimerCubit>();

    try {
      if (!_listenerAttached) {
        _channel.setMethodCallHandler(_handleNativeCallback);
        _listenerAttached = true;
      }

      await _channel.invokeMethod<void>('install');

      final imageData = await rootBundle.load(_trayIconAsset);
      await _channel.invokeMethod<void>('setIcon', {
        'base64Icon': base64Encode(imageData.buffer.asUint8List()),
        'iconSize': 22,
        'isTemplate': false,
      });
      await _channel.invokeMethod<void>('setTitle', {'title': _idleTrayTitle});
      await _channel.invokeMethod<void>('setToolTip', {
        'toolTip': 'Pomo - Pomodoro timer',
      });

      final bounds = await _getBounds();
      _iconReady = true;
      developer.log(
        'Menu bar ready: ${bounds?.width ?? 0}x${bounds?.height ?? 0}',
        name: 'MacosMenuBarService',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Menu bar setup failed: $error',
        name: 'MacosMenuBarService',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    try {
      instance._timerCubit = timerCubit;
      RemoteSessionService()
          .remoteSessionNotifier
          .removeListener(instance._onRemoteSessionChanged);
      RemoteSessionService()
          .remoteSessionNotifier
          .addListener(instance._onRemoteSessionChanged);
      await instance._syncMenuIfNeeded(force: true);
    } catch (error, stackTrace) {
      developer.log(
        'Menu bar menu setup failed: $error',
        name: 'MacosMenuBarService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onTrayIconMouseDown':
        await instance._popUpContextMenu();
      case 'onTrayIconRightMouseDown':
        unawaited(DesktopWindowService.showMainWindow());
      case 'onTrayMenuItemClick':
        final args = call.arguments as Map<dynamic, dynamic>?;
        final key = args?['key'] as String?;
        if (key != null) {
          instance._handleMenuItemClick(key);
        }
    }
  }

  static Future<Rect?> _getBounds() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getBounds',
    );
    if (result == null) {
      return null;
    }

    return Rect.fromLTWH(
      (result['x'] as num).toDouble(),
      (result['y'] as num).toDouble(),
      (result['width'] as num).toDouble(),
      (result['height'] as num).toDouble(),
    );
  }

  static void attachContext(BuildContext context) {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    instance._timerCubit = context.read<TimerCubit>();
  }

  void _onRemoteSessionChanged() {
    final timerCubit = _timerCubit;
    if (timerCubit != null && SessionHelper.isSessionActive(timerCubit.state)) {
      // Local timer takes precedence
      return;
    }
    final remoteSession = RemoteSessionService().remoteSessionNotifier.value;
    unawaited(_syncRemoteSessionToMenuBar(remoteSession));
  }

  Future<void> _syncRemoteSessionToMenuBar(RemoteSession? remoteSession) async {
    if (kIsWeb || !Platform.isMacOS || !_iconReady) {
      return;
    }

    final timerCubit = _timerCubit;
    if (timerCubit != null && SessionHelper.isSessionActive(timerCubit.state)) {
      return;
    }

    if (remoteSession == null || !remoteSession.isRunning) {
      await _channel.invokeMethod<void>('setTitle', {'title': _idleTrayTitle});
      await _channel.invokeMethod<void>('setToolTip', {
        'toolTip': 'Pomo - Pomodoro timer',
      });
      return;
    }

    final deviceLower = remoteSession.deviceName.toLowerCase();
    final deviceEmoji =
        deviceLower.contains('mobile') || deviceLower.contains('android')
            ? '📱'
            : (deviceLower.contains('web') ? '🌐' : '💻');
    final title = '$deviceEmoji ${remoteSession.formattedRemaining}';
    final tagText = remoteSession.tagName ?? 'Focus';
    final tooltip =
        '${remoteSession.deviceName} is focusing: $tagText (${remoteSession.formattedRemaining})';

    await _channel.invokeMethod<void>('setTitle', {'title': title});
    await _channel.invokeMethod<void>('setToolTip', {'toolTip': tooltip});
  }

  Future<void> updateFromState({
    required TimerState timerState,
    required SettingsState settingsState,
  }) async {
    if (kIsWeb || !Platform.isMacOS || !_iconReady) {
      return;
    }

    final localActive = SessionHelper.isSessionActive(timerState);
    if (!localActive) {
      final remoteSession = RemoteSessionService().remoteSessionNotifier.value;
      if (remoteSession != null && remoteSession.isRunning) {
        await _syncRemoteSessionToMenuBar(remoteSession);
        await _syncMenuIfNeeded(timerState: timerState);
        return;
      }
    }

    final tooltip = _tooltip(timerState, settingsState);
    await _channel.invokeMethod<void>('setToolTip', {'toolTip': tooltip});

    final time = DurationHelper.negativeFormat(
      duration: timerState.duration,
      lap: timerState.lap,
      settingsState: settingsState,
    );
    final title = localActive ? time : _idleTrayTitle;
    await _channel.invokeMethod<void>('setTitle', {'title': title});

    await _syncMenuIfNeeded(timerState: timerState);
  }

  String _tooltip(TimerState timerState, SettingsState settingsState) {
    if (!SessionHelper.isSessionActive(timerState)) {
      return 'Pomo - Pomodoro timer';
    }

    final time = DurationHelper.negativeFormat(
      duration: timerState.duration,
      lap: timerState.lap,
      settingsState: settingsState,
    );
    final emoji = _lapEmoji(timerState.lap);
    final status =
        timerState.status == TimerStatus.running ? 'Running' : 'Paused';

    return '$emoji $time ($status)';
  }

  String _lapEmoji(TimerLap lap) {
    switch (lap) {
      case TimerLap.work:
        return '💼';
      case TimerLap.shortBreak:
        return '☕';
      case TimerLap.longBreak:
        return '🏖';
    }
  }

  Future<void> _syncMenuIfNeeded({
    TimerState? timerState,
    bool force = false,
  }) async {
    final timerCubit = _timerCubit;
    if (timerCubit == null) {
      return;
    }

    final state = timerState ?? timerCubit.state;
    final isRunning = state.status == TimerStatus.running;
    final sessionActive = SessionHelper.isSessionActive(state);

    if (!force &&
        _menuIsRunning == isRunning &&
        _menuSessionActive == sessionActive) {
      return;
    }

    _menuIsRunning = isRunning;
    _menuSessionActive = sessionActive;

    await _channel.invokeMethod<void>('setContextMenu', {
      'items': [
        {
          'key': 'toggle',
          'label': isRunning ? 'Pause timer' : 'Start timer',
          'type': 'normal',
        },
        {
          'key': 'reset',
          'label': 'Reset',
          'type': 'normal',
          'disabled': !sessionActive,
        },
        {'type': 'separator'},
        {
          'key': 'open',
          'label': 'Open Pomo',
          'type': 'normal',
        },
        {
          'key': 'settings',
          'label': 'Settings',
          'type': 'normal',
        },
        {'type': 'separator'},
        {
          'key': 'quit',
          'label': 'Quit',
          'type': 'normal',
        },
      ],
    });
  }

  Future<void> _popUpContextMenu() async {
    await _syncMenuIfNeeded(force: _menuIsRunning == null);
    await _channel.invokeMethod<void>('popUpContextMenu');
  }

  void _handleMenuItemClick(String key) {
    final timerCubit = _timerCubit;
    if (timerCubit == null) {
      return;
    }

    switch (key) {
      case 'toggle':
        timerCubit.toggle();
      case 'reset':
        timerCubit.reset();
      case 'open':
        unawaited(DesktopWindowService.showMainWindow());
      case 'settings':
        unawaited(DesktopWindowService.showMainWindow());
        App.navigatorKey.currentState?.pushNamed('/settings');
      case 'quit':
        unawaited(DesktopWindowService.quit());
    }
  }
}
