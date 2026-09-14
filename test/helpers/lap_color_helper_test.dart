import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/lap_color_helper.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/theme/rawshn_brand.dart';

void main() {
  group('LapColorHelper', () {
    test('lapColor tints with work cyan when work lap is running', () {
      final color = LapColorHelper.lapColor(
        lap: TimerLap.work,
        status: TimerStatus.running,
        colorSeed: RawshnBrand.cyan,
        brightness: Brightness.dark,
      );
      final scheme = RawshnBrand.colorScheme(
        brightness: Brightness.dark,
        seed: RawshnBrand.cyan,
      );
      final expected = Color.alphaBlend(
        RawshnBrand.cyan.withValues(alpha: 0.28),
        scheme.surfaceContainerHigh,
      );
      expect(color, expected);
    });

    test('lapColor returns surface container when timer is stopped', () {
      final color = LapColorHelper.lapColor(
        lap: TimerLap.work,
        status: TimerStatus.stopped,
        colorSeed: RawshnBrand.cyan,
        brightness: Brightness.dark,
      );
      final scheme = RawshnBrand.colorScheme(
        brightness: Brightness.dark,
        seed: RawshnBrand.cyan,
      );
      expect(color, scheme.surfaceContainerHighest);
    });

    test('lapColor uses magenta/orange for break laps when running', () {
      final scheme = RawshnBrand.colorScheme(
        brightness: Brightness.dark,
        seed: RawshnBrand.cyan,
      );

      final shortBreakColor = LapColorHelper.lapColor(
        lap: TimerLap.shortBreak,
        status: TimerStatus.running,
        colorSeed: RawshnBrand.cyan,
        brightness: Brightness.dark,
      );
      expect(
        shortBreakColor,
        Color.alphaBlend(
          RawshnBrand.magenta.withValues(alpha: 0.28),
          scheme.surfaceContainerHigh,
        ),
      );

      final longBreakColor = LapColorHelper.lapColor(
        lap: TimerLap.longBreak,
        status: TimerStatus.running,
        colorSeed: RawshnBrand.cyan,
        brightness: Brightness.dark,
      );
      expect(
        longBreakColor,
        Color.alphaBlend(
          RawshnBrand.orange.withValues(alpha: 0.28),
          scheme.surfaceContainerHigh,
        ),
      );
    });
  });
}
