import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pomo/desktop/desktop_window_service.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/helpers/session_helper.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/singletons/prefs.dart';

/// Manages the small floating overlay window on macOS.
class FloatingOverlayController {
  FloatingOverlayController._();

  static final FloatingOverlayController instance =
      FloatingOverlayController._();

  static const _channel = MethodChannel('pomo/overlay');

  WindowController? _controller;
  bool _visible = false;
  int _syncGeneration = 0;

  /// Called when the overlay sub-window registers its IPC handler.
  static Future<void> Function()? onOverlayReady;

  static void initMainWindowHandler() {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'showMainWindow') {
        await DesktopWindowService.showMainWindow();
      } else if (call.method == 'overlayReady') {
        await onOverlayReady?.call();
      }
      return null;
    });
  }

  Future<void> sync(TimerState state) async {
    if (kIsWeb || !Platform.isMacOS || !Prefs.showFloatingTimer) {
      if (_visible) {
        await _hide();
      }
      return;
    }

    final shouldShow = SessionHelper.isSessionActive(state);

    if (shouldShow && !_visible) {
      await _show();
    } else if (!shouldShow && _visible) {
      await _hide();
    }

    if (_visible) {
      final controller = _controller;
      if (controller != null) {
        final syncGeneration = ++_syncGeneration;
        final settings = SettingsState(
          workMinutes: Prefs.workMinutes,
          shortBreakMinutes: Prefs.shortBreakMinutes,
          longBreakMinutes: Prefs.longBreakMinutes,
          colorSeed: Prefs.colorSeed,
        );
        final time = DurationHelper.negativeFormat(
          duration: state.duration,
          lap: state.lap,
          settingsState: settings,
        );
        if (syncGeneration != _syncGeneration) {
          return;
        }
        try {
          await DesktopMultiWindow.invokeMethod(
            controller.windowId,
            'updateTimer',
            {
              'time': time,
              'lap': state.lap.index,
              'status': state.status.index,
              'colorSeed': Prefs.colorSeed?.toARGB32(),
              'timerFont': Prefs.timerFont.name,
              'timerCustomFont': Prefs.timerCustomFont,
            },
          );
        } catch (error, stackTrace) {
          developer.log(
            'Floating overlay updateTimer IPC failed',
            name: 'FloatingOverlayController',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }
  }

  Future<void> _show() async {
    try {
      _controller ??= await DesktopMultiWindow.createWindow(
        jsonEncode({'route': 'overlay'}),
      );

      await _channel.invokeMethod<void>('configureOverlayWindow', {
        'corner': Prefs.overlayCorner,
      });
      // Use native showOverlay instead of desktop_multi_window show().
      // Plugin show() calls makeKeyAndOrderFront + NSApp.activate, which
      // pins the overlay to the main Space and breaks full-screen visibility.
      await _channel.invokeMethod<void>('showOverlay', {
        'corner': Prefs.overlayCorner,
      });
      await _channel.invokeMethod<void>('ensureRegularActivation');
      _visible = true;
    } catch (_) {
      _visible = false;
    }
  }

  Future<void> _hide() async {
    try {
      await _channel.invokeMethod<void>('hideOverlay');
    } catch (_) {
      // Ignore overlay teardown errors.
    }

    _visible = false;
  }

  static Future<void> requestMainWindow() async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    try {
      await DesktopMultiWindow.invokeMethod(0, 'showMainWindow');
    } catch (_) {}

    try {
      await const MethodChannel('pomo/overlay')
          .invokeMethod<void>('showMainWindow');
    } catch (_) {}
  }
}
