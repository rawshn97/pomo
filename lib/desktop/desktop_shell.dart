import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/desktop/desktop_window_service.dart';
import 'package:pomo/desktop/floating_overlay_controller.dart';
import 'package:pomo/desktop/macos_menu_bar_service.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/services/local_notification_service.dart';
import 'package:pomo/services/timer_tick_service.dart';

/// Hosts macOS-only desktop integrations around the main app.
class DesktopShell extends StatefulWidget {
  const DesktopShell({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        TimerTickService.start(
          timerCubit: context.read<TimerCubit>(),
          settingsCubit: context.read<SettingsCubit>(),
        );
        _initDesktop();
      }
    });
  }

  @override
  void dispose() {
    TimerTickService.stop();
    super.dispose();
  }

  Future<void> _initDesktop() async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    if (!mounted) {
      return;
    }

    developer.log('_initDesktop starting...', name: 'DesktopShell');
    // Create the menu bar status item before other desktop integrations so a
    // tray channel failure cannot be masked by unrelated setup work.
    await MacosMenuBarService.init(context);
    developer.log('MacosMenuBarService.init completed', name: 'DesktopShell');

    await DesktopWindowService.init();
    await LocalNotificationService.instance.init();
    FloatingOverlayController.onOverlayReady = () async {
      if (!mounted) {
        return;
      }
      await FloatingOverlayController.instance.sync(
        context.read<TimerCubit>().state,
      );
    };
    FloatingOverlayController.initMainWindowHandler();

    if (!mounted) {
      return;
    }

    final timerCubit = context.read<TimerCubit>();
    final settingsCubit = context.read<SettingsCubit>();

    await MacosMenuBarService.instance.updateFromState(
      timerState: timerCubit.state,
      settingsState: settingsCubit.state,
    );
    await FloatingOverlayController.instance.sync(timerCubit.state);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isMacOS) {
      return widget.child;
    }

    MacosMenuBarService.attachContext(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<TimerCubit, TimerState>(
          listener: (context, state) async {
            final settings = context.read<SettingsCubit>().state;
            await FloatingOverlayController.instance.sync(state);
            await MacosMenuBarService.instance.updateFromState(
              timerState: state,
              settingsState: settings,
            );
          },
        ),
        BlocListener<SettingsCubit, SettingsState>(
          listenWhen: (previous, current) =>
              previous.showFloatingTimer != current.showFloatingTimer ||
              previous.overlayCorner != current.overlayCorner,
          listener: (context, state) async {
            final timerState = context.read<TimerCubit>().state;
            await FloatingOverlayController.instance.sync(timerState);
            if (Platform.isMacOS) {
              await const MethodChannel('pomo/overlay').invokeMethod<void>(
                'positionOverlay',
                {'corner': state.overlayCorner},
              );
            }
          },
        ),
      ],
      child: widget.child,
    );
  }
}
