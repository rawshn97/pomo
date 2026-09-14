import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/pages/tracker/view/time_log_history_view.dart';
import 'package:pomo/pages/tracker/view/tracker_shell_page.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().init();
  });

  Future<void> pumpAtPhoneWidth(
    WidgetTester tester,
    Widget home,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('TimeLogHistoryView does not overflow at 390 dp width',
      (tester) async {
    await pumpAtPhoneWidth(
      tester,
      const Scaffold(body: TimeLogHistoryView()),
    );

    expect(find.byType(TimeLogHistoryView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TrackerShellPage does not overflow at 390 dp', (tester) async {
    await pumpAtPhoneWidth(tester, const TrackerShellPage());

    expect(find.byType(TimeLogHistoryView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
