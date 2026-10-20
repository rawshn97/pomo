import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/pages/tracker/view/edit_time_log_dialog.dart';
import 'package:pomo/pages/tracker/view/manual_time_entry_dialog.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ManualTimeEntryDialog', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    testWidgets('renders start time, end time, tag chips, and logs time',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManualTimeEntryDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Focus Time'), findsOneWidget);
      expect(find.text('Start Time'), findsOneWidget);
      expect(find.text('End Time'), findsOneWidget);
      expect(find.text('Activity Tag'), findsOneWidget);
      expect(find.text('Log Time'), findsOneWidget);

      await tester.ensureVisible(find.text('Log Time'));
      await tester.tap(find.text('Log Time'));
      await tester.pumpAndSettle();

      // Successfully credited time into Prefs.hourlyLogs
      expect(Prefs.hourlyLogs, isNotEmpty);
    });
  });

  group('EditTimeLogDialog', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    testWidgets('modifies duration and saves changes', (tester) async {
      final log = HourlyLog(
        id: 'hlog_edit_test',
        dateStr: '2026-09-14',
        hour: 14,
        tagId: 'tag_deep_work',
        tagName: 'Deep Work',
        tagIcon: '🧠',
        tagColorHex: '#34A853',
        durationMinutes: 30,
        loggedAt: DateTime.utc(2026, 9, 14, 14),
      );
      await Prefs.saveHourlyLog(log);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditTimeLogDialog(log: log),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Logged Time'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.byTooltip('Delete time log'), findsOneWidget);

      // Adjust duration by +15m
      await tester.tap(find.text('+15m'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated =
          Prefs.hourlyLogs.firstWhere((e) => e.id == 'hlog_edit_test');
      expect(updated.durationMinutes, 45);
    });

    testWidgets('deletes log after confirmation', (tester) async {
      final log = HourlyLog(
        id: 'hlog_delete_test',
        dateStr: '2026-09-14',
        hour: 15,
        tagId: 'tag_coding',
        tagName: 'Coding & Dev',
        tagIcon: '💻',
        tagColorHex: '#4285F4',
        durationMinutes: 25,
        loggedAt: DateTime.utc(2026, 9, 14, 15),
      );
      await Prefs.saveHourlyLog(log);
      expect(Prefs.hourlyLogs, hasLength(1));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditTimeLogDialog(log: log),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteBtn = find.byTooltip('Delete time log');
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Delete Time Log?'), findsOneWidget);
      // Tap Delete in confirmation dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(Prefs.hourlyLogs, isEmpty);
    });
  });
}
