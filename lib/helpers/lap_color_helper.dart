import 'package:flutter/material.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/theme/rawshn_brand.dart';

mixin LapColorHelper {
  static Color lapColor({
    required TimerLap lap,
    required TimerStatus status,
    required Color? colorSeed,
    required Brightness brightness,
  }) {
    final seed = colorSeed ?? RawshnBrand.defaultSeed;
    final accent = RawshnBrand.lapAccent(lap);
    final scheme = RawshnBrand.colorScheme(
      brightness: brightness,
      seed: seed,
    );

    if (status == TimerStatus.running) {
      switch (lap) {
        case TimerLap.work:
          return Color.alphaBlend(
            accent.withValues(alpha: 0.28),
            scheme.surfaceContainerHigh,
          );
        case TimerLap.shortBreak:
          return Color.alphaBlend(
            RawshnBrand.magenta.withValues(alpha: 0.28),
            scheme.surfaceContainerHigh,
          );
        case TimerLap.longBreak:
          return Color.alphaBlend(
            RawshnBrand.orange.withValues(alpha: 0.28),
            scheme.surfaceContainerHigh,
          );
      }
    }

    return scheme.surfaceContainerHighest;
  }
}
