import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/app/view/home_shell.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/pages/tracker/view/tracker_shell_page.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().init();
  });

  Widget wrap(Widget child) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => TimerCubit()),
        BlocProvider(create: (_) => SettingsCubit()..loadSettings()),
      ],
      child: MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: child,
      ),
    );
  }

  /// Child pages can overflow at 390px; locks NavigationBar tabs only.
  Future<void> settleIgnoringChildOverflow(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      while (tester.takeException() != null) {}
      if (!tester.binding.hasScheduledFrame) {
        return;
      }
    }
  }

  testWidgets('narrow layout shows three NavigationBar destinations',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const HomeShell()));
    await settleIgnoringChildOverflow(tester);

    expect(find.text('Focus'), findsWidgets);
    expect(find.text('Tracker'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Tracker'));
    await settleIgnoringChildOverflow(tester);
    expect(find.byType(TrackerShellPage), findsOneWidget);
  });
}
