import 'package:flutter/material.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';

/// Visual tokens aligned to rawshn.com (see DESIGN.md Visual Brand System).
abstract final class RawshnBrand {
  static const Color bg = Color(0xFF0A0C10);
  static const Color mantle = Color(0xFF10131A);
  static const Color crust = Color(0xFF06080C);
  static const Color card = Color(0xFF141822);
  static const Color border = Color(0xFF223048);
  static const Color ink = Color(0xFFF6F7F8);
  static const Color muted = Color(0xFF94A3B8);
  static const Color cyan = Color(0xFF00F0FF);
  static const Color magenta = Color(0xFFFF00AA);
  static const Color orange = Color(0xFFFF6B35);
  static const Color lime = Color(0xFF39FF14);
  static const Color amber = Color(0xFFFACC15);
  static const Color violet = Color(0xFFA855F7);
  static const Color danger = Color(0xFFFF4D6D);

  /// Light-mode secondary palette (portfolio `html.light` tokens).
  static const Color lightBg = Color(0xFFF2F5EC);
  static const Color lightMantle = Color(0xFFE6EBE4);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFF7CADFF);
  static const Color lightInk = Color(0xFF353538);
  static const Color lightMuted = Color(0xFF64748B);
  static const Color lightAccent = Color(0xFF1158D1);

  static const String fontSans = 'Space Grotesk';
  static const String fontMono = 'JetBrains Mono';

  static const String memorableLine = 'Protect the hour. Prove the day.';

  /// Default accent when the user has not set a color seed.
  static const Color defaultSeed = cyan;

  static Color lapAccent(TimerLap lap) {
    switch (lap) {
      case TimerLap.work:
        return cyan;
      case TimerLap.shortBreak:
        return magenta;
      case TimerLap.longBreak:
        return orange;
    }
  }

  static String statusPath({
    required int tabIndex,
    TimerLap? lap,
  }) {
    switch (tabIndex) {
      case 1:
        return '~/day/prove';
      case 2:
        return '~/settings';
      default:
        switch (lap) {
          case TimerLap.shortBreak:
            return '~/break/short';
          case TimerLap.longBreak:
            return '~/break/long';
          case TimerLap.work:
          case null:
            return '~/work';
        }
    }
  }

  static ColorScheme colorScheme({
    required Brightness brightness,
    Color? seed,
  }) {
    final accent = seed ?? defaultSeed;
    if (brightness == Brightness.dark) {
      return ColorScheme.dark(
        primary: accent,
        onPrimary: crust,
        primaryContainer: Color.alphaBlend(
          accent.withValues(alpha: 0.22),
          card,
        ),
        onPrimaryContainer: ink,
        secondary: magenta,
        onSecondary: crust,
        secondaryContainer: Color.alphaBlend(
          magenta.withValues(alpha: 0.18),
          card,
        ),
        onSecondaryContainer: ink,
        tertiary: orange,
        onTertiary: crust,
        tertiaryContainer: Color.alphaBlend(
          orange.withValues(alpha: 0.18),
          card,
        ),
        onTertiaryContainer: ink,
        error: danger,
        onError: crust,
        surface: bg,
        onSurface: ink,
        onSurfaceVariant: muted,
        surfaceContainerHighest: mantle,
        surfaceContainerHigh: card,
        surfaceContainer: card,
        surfaceContainerLow: mantle,
        surfaceContainerLowest: crust,
        outline: border,
        outlineVariant: border.withValues(alpha: 0.7),
      );
    }

    return ColorScheme.light(
      primary: seed ?? lightAccent,
      primaryContainer: const Color(0xFFDBE5FF),
      onPrimaryContainer: lightInk,
      secondary: magenta,
      onSecondary: Colors.white,
      tertiary: orange,
      onTertiary: Colors.white,
      error: danger,
      surface: lightBg,
      onSurface: lightInk,
      onSurfaceVariant: lightMuted,
      surfaceContainerHighest: lightMantle,
      surfaceContainerHigh: lightCard,
      surfaceContainer: lightCard,
      outline: lightBorder,
      outlineVariant: lightBorder.withValues(alpha: 0.6),
    );
  }

  static ThemeData buildTheme({
    required Brightness brightness,
    Color? seed,
  }) {
    final colorScheme = RawshnBrand.colorScheme(
      brightness: brightness,
      seed: seed,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontSans,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardColor: brightness == Brightness.dark ? card : lightCard,
    );

    final textTheme = base.textTheme
        .apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
          fontFamily: fontSans,
        )
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(
            fontFamily: fontMono,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
          ),
          labelSmall: base.textTheme.labelSmall?.copyWith(
            fontFamily: fontMono,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: brightness == Brightness.dark ? card : lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.7)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brightness == Brightness.dark ? mantle : lightMantle,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontMono,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color:
                selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: brightness == Brightness.dark ? mantle : lightMantle,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          fontFamily: fontMono,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colorScheme.primary,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: fontMono,
          fontSize: 11,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark ? card : lightCard,
        labelStyle:
            textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        textColor: colorScheme.onSurface,
        collapsedTextColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurface,
        collapsedIconColor: colorScheme.onSurface,
      ),
      listTileTheme: ListTileThemeData(
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.6),
      ),
    );
  }
}
