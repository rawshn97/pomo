import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pomo/desktop/floating_overlay_controller.dart';
import 'package:pomo/helpers/lap_color_helper.dart';
import 'package:pomo/helpers/timer_helper.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:window_manager/window_manager.dart';

/// Minimal Flutter UI for the floating overlay sub-window.
class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  String _time = '00:00';
  int _lapIndex = 0;
  int _statusIndex = 0;
  Color? _colorSeed;
  TimerFont _timerFont = TimerFont.boldMono;
  String _timerCustomFont = '';

  @override
  void initState() {
    super.initState();
    _initWindow();
    _setupMethodHandler();
  }

  Future<void> _initWindow() async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    // Only initialize window_manager for drag support. Do NOT pass
    // skipTaskbar: true here - that sets NSApplication activation policy to
    // .accessory for the entire process and removes the Dock icon.
    await windowManager.ensureInitialized();
  }

  void _setupMethodHandler() {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'updateTimer') {
        final args = call.arguments as Map<dynamic, dynamic>;
        if (mounted) {
          setState(() => _applyUpdate(args));
        }
      }
      return null;
    });

    // Ask the main window to push the current timer state once this engine
    // can receive IPC. Prefs polling is intentionally avoided here because
    // each Flutter engine caches SharedPreferences independently.
    DesktopMultiWindow.invokeMethod(0, 'overlayReady').catchError((_) {});
  }

  void _applyUpdate(Map<dynamic, dynamic> args) {
    _time = (args['time'] as String?) ?? _time;
    _lapIndex = (args['lap'] as int?) ?? _lapIndex;
    _statusIndex = (args['status'] as int?) ?? _statusIndex;
    final seedArgb = args['colorSeed'] as int?;
    _colorSeed = seedArgb != null ? Color(seedArgb) : _colorSeed;
    final fontName = args['timerFont'] as String?;
    if (fontName != null) {
      _timerFont = TimerFont.values.firstWhere(
        (f) => f.name == fontName,
        orElse: () => TimerFont.boldMono,
      );
    }
    _timerCustomFont = (args['timerCustomFont'] as String?) ?? _timerCustomFont;
  }

  @override
  Widget build(BuildContext context) {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    final lap = TimerLap.values[_lapIndex.clamp(0, TimerLap.values.length - 1)];
    final status = TimerStatus
        .values[_statusIndex.clamp(0, TimerStatus.values.length - 1)];

    final lapColor = LapColorHelper.lapColor(
      lap: lap,
      status: status,
      colorSeed: _colorSeed,
      brightness: brightness,
    );

    final settingsState = SettingsState(
      timerFont: _timerFont,
      timerCustomFont: _timerCustomFont,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: FloatingOverlayController.requestMainWindow,
          onPanStart: (_) => windowManager.startDragging(),
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Center(
              child: _OverlayPill(
                time: _time,
                lapColor: lapColor,
                brightness: brightness,
                settingsState: settingsState,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({
    required this.time,
    required this.lapColor,
    required this.brightness,
    required this.settingsState,
  });

  final String time;
  final Color lapColor;
  final Brightness brightness;
  final SettingsState settingsState;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: lapColor.withValues(alpha: 0.3),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: lapColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: lapColor.withValues(alpha: 0.7),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            TimerHelper.buildTimerText(
              duration: time,
              settingsState: settingsState,
              style: TextStyle(
                fontSize: 20,
                color: textColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
