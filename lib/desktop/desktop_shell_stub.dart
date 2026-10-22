import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/services/remote_session_service.dart';
import 'package:pomo/services/timer_tick_service.dart';

/// Web and non-desktop fallback that passes through the main app tree
/// and starts the app-level TimerTickService so the clock ticks cleanly.
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
        final timerCubit = context.read<TimerCubit>();
        RemoteSessionService().attachTimerCubit(timerCubit);
        TimerTickService.start(
          timerCubit: timerCubit,
          settingsCubit: context.read<SettingsCubit>(),
        );
      }
    });
  }

  @override
  void dispose() {
    TimerTickService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
