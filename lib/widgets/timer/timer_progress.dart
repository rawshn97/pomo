import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/helpers/lap_helper.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/theme/rawshn_brand.dart';

class TimerProgress extends StatelessWidget {
  const TimerProgress({super.key});

  static Color getProgressColor({
    required TimerStatus status,
    required TimerLap lap,
    required BuildContext context,
  }) {
    if (status == TimerStatus.running) {
      return RawshnBrand.lapAccent(lap);
    }
    return Theme.of(context).colorScheme.outline;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit the ring inside the space actually available to this widget so
        // it always stays a perfect circle regardless of window shape.
        final dimension = constraints.biggest.shortestSide * 0.9;
        return SizedBox.square(
          dimension: dimension,
          child: BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, settingsState) {
              return BlocBuilder<TimerCubit, TimerState>(
                builder: (context, state) {
                  final beginVal = DurationHelper.getProgress(
                    duration: state.duration - const Duration(seconds: 1),
                    lap: state.lap,
                    settingsState: settingsState,
                  );

                  final endVal = DurationHelper.getProgress(
                    duration: state.duration,
                    lap: state.lap,
                    settingsState: settingsState,
                  );

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: beginVal, end: endVal),
                    curve: Curves.easeOut,
                    duration: Durations.medium3,
                    builder: (context, value, _) {
                      final nextLap = LapHelper.getNextLap(
                        state.lap,
                        state.lapNumber,
                        settingsState.lapCount,
                      );

                      final color = Color.lerp(
                        getProgressColor(
                          lap: nextLap,
                          status: state.status,
                          context: context,
                        ),
                        getProgressColor(
                          lap: state.lap,
                          status: state.status,
                          context: context,
                        ),
                        value,
                      );

                      return CircularProgressIndicator(
                        value: value,
                        color: color,
                        strokeCap: StrokeCap.round,
                        strokeAlign: BorderSide.strokeAlignInside,
                        strokeWidth: dimension * 0.0625,
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
