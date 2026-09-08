import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/app/view/home_shell.dart';
import 'package:pomo/desktop/desktop_shell_stub.dart'
    if (dart.library.io) 'package:pomo/desktop/desktop_shell.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/pages/about/view/about_page.dart';
import 'package:pomo/pages/deniz/deniz.dart';
import 'package:pomo/pages/settings/settings.dart';
import 'package:pomo/pages/timer/timer.dart';
import 'package:pomo/widgets/app_update_listener.dart';

class App extends StatelessWidget {
  const App({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: colorScheme,
    );
    final textTheme = base.textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        foregroundColor: colorScheme.onSurface,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        textColor: colorScheme.onSurface,
        collapsedTextColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurface,
        collapsedIconColor: colorScheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle:
            textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      listTileTheme: ListTileThemeData(
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TimerCubit>(
          create: (context) => TimerCubit(),
        ),
        BlocProvider<SettingsCubit>(
          create: (context) => SettingsCubit()..loadSettings(),
        ),
      ],
      child: AppUpdateListener(
        child: DesktopShell(
          child: BlocBuilder<SettingsCubit, SettingsState>(
            buildWhen: (previous, current) =>
                previous.themeMode != current.themeMode ||
                previous.colorSeed != current.colorSeed ||
                previous.locale != current.locale,
            builder: (context, state) {
              final lightScheme = ColorScheme.fromSeed(
                seedColor: state.colorSeed ?? Colors.redAccent,
              );
              final darkScheme = ColorScheme.fromSeed(
                seedColor: state.colorSeed ?? Colors.redAccent,
                brightness: Brightness.dark,
              );

              return MaterialApp(
                navigatorKey: navigatorKey,
                theme: _buildTheme(colorScheme: lightScheme),
                darkTheme: _buildTheme(colorScheme: darkScheme),
                themeMode: state.themeMode,
                locale: state.locale,
                debugShowCheckedModeBanner: false,
                localizationsDelegates: S.localizationsDelegates,
                supportedLocales: S.supportedLocales,
                routes: {
                  '/': (context) => const HomeShell(),
                  '/focus': (context) => const HomeShell(),
                  '/tracker': (context) => const HomeShell(initialIndex: 1),
                  '/settings': (context) => const SettingsPage(),
                  '/about': (context) => const AboutPage(),
                  '/deniz': (context) => const DenizPage(),
                },
                onGenerateInitialRoutes: (initialRoute) {
                  final uri = Uri.tryParse(initialRoute);
                  final path = uri?.path ?? initialRoute;
                  if (path == '/tracker') {
                    return [
                      MaterialPageRoute<dynamic>(
                        builder: (context) => const HomeShell(initialIndex: 1),
                        settings: const RouteSettings(name: '/tracker'),
                      ),
                    ];
                  }
                  if (path == '/settings') {
                    return [
                      MaterialPageRoute<dynamic>(
                        builder: (context) => const HomeShell(initialIndex: 2),
                        settings: const RouteSettings(name: '/settings'),
                      ),
                    ];
                  }
                  return [
                    MaterialPageRoute<dynamic>(
                      builder: (context) => const HomeShell(),
                      settings: const RouteSettings(name: '/'),
                    ),
                  ];
                },
                initialRoute: '/',
              );
            },
          ),
        ),
      ),
    );
  }
}
