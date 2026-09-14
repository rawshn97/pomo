import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/pages/tracker/view/time_log_history_view.dart';
import 'package:pomo/pages/tracker/view/tracker_shell_page.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TrackerShellPage', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    testWidgets('renders Time Log history view', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrackerShellPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Time Log'), findsOneWidget);
      expect(find.byType(TimeLogHistoryView), findsOneWidget);
      expect(find.text('Total Focus'), findsOneWidget);
    });

    testWidgets('shows Notion AppBar action when sync enabled', (tester) async {
      Prefs.enableNotionSync = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: TrackerShellPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Open Notion Hourly Timeline'), findsOneWidget);
    });

    testWidgets('Notion action snackbars when hourly DB id is empty',
        (tester) async {
      Prefs.enableNotionSync = true;
      Prefs.notionHourlyTimelineDatabaseId = '';

      await tester.pumpWidget(
        const MaterialApp(
          home: TrackerShellPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open Notion Hourly Timeline'));
      await tester.pumpAndSettle();

      expect(
        find.text('Set Hourly Timeline Database ID in Settings'),
        findsOneWidget,
      );
    });
  });
}
