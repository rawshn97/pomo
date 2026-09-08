import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NotionService.addDuration', () {
    test('normalizes minutes into hours and remaining minutes accurately', () {
      final res1 = NotionService.addDuration(
        currentHours: 1,
        currentMinutes: 45,
        addMin: 30,
      );
      expect(res1.hours, equals(2));
      expect(res1.minutes, equals(15));

      final res2 = NotionService.addDuration(
        currentHours: 0,
        currentMinutes: 10,
        addMin: 120,
      );
      expect(res2.hours, equals(2));
      expect(res2.minutes, equals(10));

      final res3 = NotionService.addDuration(
        currentHours: 3,
        currentMinutes: 59,
        addMin: 1,
      );
      expect(res3.hours, equals(4));
      expect(res3.minutes, equals(0));
    });
  });

  group('NotionSyncService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    tearDown(() {
      Prefs.enableNotionSync = false;
      Prefs.notionApiKey = '';
      Prefs.notionProxyUrl = '';
      Prefs.pendingTimeLogs = [];
      Prefs.pendingHourlyLogs = [];
      NotionService.clearTaskFetchCache();
    });

    test('skips sync when task is null', () async {
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'secret_token';

      final result = await NotionSyncService().syncSession(
        task: null,
        duration: const Duration(minutes: 25),
      );
      expect(result.success, isFalse);
    });

    test('skips sync when enableNotionSync is false', () async {
      Prefs.enableNotionSync = false;
      Prefs.notionApiKey = 'secret_token';

      final result = await NotionSyncService().syncSession(
        task: const NotionTask(id: 'task-1', title: 'Test'),
        duration: const Duration(minutes: 25),
      );
      expect(result.success, isFalse);
    });

    test('skips sync when duration is less than 1 minute', () async {
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'secret_token';

      final result = await NotionSyncService().syncSession(
        task: const NotionTask(id: 'task-1', title: 'Test'),
        duration: const Duration(seconds: 45),
      );
      expect(result.success, isFalse);
    });

    test(
      'moveToInProgressIfNeeded returns unchanged task when already '
      'In Progress or Done',
      () async {
        const task =
            NotionTask(id: 't-1', title: 'Test', status: 'In Progress');
        final res = await NotionSyncService().moveToInProgressIfNeeded(task);
        expect(res, equals(task));
      },
    );

    test('moveToInProgressIfNeeded returns null when task is null', () async {
      final res = await NotionSyncService().moveToInProgressIfNeeded(null);
      expect(res, isNull);
    });

    test('flushPendingLogs returns 0 when enableNotionSync is false', () async {
      Prefs.enableNotionSync = false;
      Prefs.pendingTimeLogs = ['{"taskId":"1","durationMinutes":25}'];
      final flushed = await NotionSyncService().flushPendingLogs();
      expect(flushed, equals(0));
    });

    test('syncActivityTags returns 0 when sync is disabled', () async {
      Prefs.enableNotionSync = false;

      final changed = await NotionSyncService().syncActivityTags();

      expect(changed, 0);
    });

    test('saveActivityTag persists locally when cloud sync is disabled',
        () async {
      Prefs.enableNotionSync = false;
      const tag = TrackerTag(
        id: 'tag_custom_test',
        name: 'Test Tag',
        icon: '🧪',
        colorHex: '#34A853',
      );

      await NotionSyncService().saveActivityTag(tag);

      expect(Prefs.trackerTags, contains(tag));
    });

    test('deleteActivityTag removes locally when cloud sync is disabled',
        () async {
      Prefs.enableNotionSync = false;
      const tag = TrackerTag(
        id: 'tag_custom_delete',
        name: 'Delete Me',
        icon: '🗑️',
        colorHex: '#EA4335',
      );
      await Prefs.saveTrackerTag(tag);

      await NotionSyncService().deleteActivityTag(tag);

      expect(Prefs.trackerTags.any((item) => item.id == tag.id), isFalse);
    });

    test('flushPendingLogs returns 0 when queue is empty', () async {
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'secret_token';
      Prefs.pendingTimeLogs = [];
      final flushed = await NotionSyncService().flushPendingLogs();
      expect(flushed, equals(0));
    });

    test('syncSession queues to Prefs.pendingTimeLogs on network/API failure',
        () async {
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'secret_token';
      Prefs.notionProxyUrl = 'http://invalid.domain.test:12345/api/notion/';
      Prefs.pendingTimeLogs = [];

      final result = await NotionSyncService().syncSession(
        task: const NotionTask(
          id: 'task-fail-1',
          title: 'Network Fail Task',
          status: 'In Progress',
        ),
        duration: const Duration(minutes: 25),
      );

      expect(result.success, isFalse);
      expect(Prefs.pendingTimeLogs, isNotEmpty);
      expect(Prefs.pendingTimeLogs.first, contains('task-fail-1'));
    });

    test(
        'syncHourlyLog queues to Prefs.pendingHourlyLogs on network/API failure',
        () async {
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'secret_token';
      Prefs.notionProxyUrl = 'http://invalid.domain.test:12345/api/notion/';
      Prefs.pendingHourlyLogs = [];

      final log = HourlyLog(
        id: 'hlog-fail-1',
        dateStr: '2026-07-14',
        hour: 10,
        tagId: 'tag_coding',
        tagName: 'Coding',
        tagIcon: '💻',
        tagColorHex: '#4285F4',
        loggedAt: DateTime.now(),
      );

      final result = await NotionSyncService().syncHourlyLog(log);

      expect(result.success, isFalse);
      expect(Prefs.pendingHourlyLogs, isNotEmpty);
      expect(Prefs.pendingHourlyLogs.first, contains('hlog-fail-1'));
    });

    test('flushPendingHourlyLogs returns 0 when enableNotionSync is false',
        () async {
      Prefs.enableNotionSync = false;
      Prefs.pendingHourlyLogs = ['{"id":"1","hour":10}'];
      final flushed = await NotionSyncService().flushPendingHourlyLogs();
      expect(flushed, equals(0));
    });

    test('flushPendingHourlyLogs returns 0 when queue is empty', () async {
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'secret_token';
      Prefs.pendingHourlyLogs = [];
      final flushed = await NotionSyncService().flushPendingHourlyLogs();
      expect(flushed, equals(0));
    });

    test('flushPendingHourlyLogs returns 0 when hourly timeline DB id empty',
        () async {
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'secret_token';
      Prefs.notionHourlyTimelineDatabaseId = '';
      Prefs.pendingHourlyLogs = [
        [
          '{"id":"1","dateStr":"2026-07-18","hour":10,',
          '"tagId":"work","tagName":"Work","tagIcon":"💼",',
          '"tagColor":"#000000","durationMinutes":60,',
          '"loggedAt":"2026-07-18T10:00:00.000"}',
        ].join(),
      ];
      final flushed = await NotionSyncService().flushPendingHourlyLogs();
      expect(flushed, equals(0));
    });

    test('sessionCreditMinutes credits only the unsynced delta', () {
      // Pause at 10m then again at 15m: +10 then +5, not +10 then +15.
      expect(
        NotionSyncService.sessionCreditMinutes(
          totalMinutes: 10,
          alreadySynced: 0,
        ),
        equals(10),
      );
      expect(
        NotionSyncService.sessionCreditMinutes(
          totalMinutes: 15,
          alreadySynced: 10,
        ),
        equals(5),
      );
      expect(
        NotionSyncService.sessionCreditMinutes(
          totalMinutes: 15,
          alreadySynced: 15,
        ),
        equals(0),
      );
      expect(
        NotionSyncService.sessionCreditMinutes(
          totalMinutes: 0,
          alreadySynced: 0,
        ),
        equals(0),
      );
    });

    test('createSessionRecord returns null when sync disabled', () async {
      Prefs.enableNotionSync = false;
      Prefs.notionApiKey = 'secret_token';

      final pageId = await NotionSyncService().createSessionRecord(
        task: const NotionTask(id: 'task-1', title: 'Test'),
        startedAt: DateTime(2026, 7, 18, 12),
      );
      expect(pageId, isNull);
      expect(Prefs.activeSessionExternalId, isNull);
      expect(Prefs.syncedMinutes, equals(0));
    });

    test('updateSessionRecord skips when total elapsed under 1 minute',
        () async {
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'secret_token';
      Prefs.syncedMinutes = 0;

      final result = await NotionSyncService().updateSessionRecord(
        task: const NotionTask(id: 'task-1', title: 'Test'),
        totalElapsed: const Duration(seconds: 45),
        existingLogPageId: 'page-1',
      );
      expect(result.success, isFalse);
      expect(Prefs.syncedMinutes, equals(0));
    });
  });

  group('Prefs session sync state', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    test('clearSessionSyncState clears page id, synced minutes, external id',
        () {
      Prefs.activeLogPageId = 'page-1';
      Prefs.syncedMinutes = 12;
      Prefs.activeSessionExternalId = 'sess_task_1';

      Prefs.clearSessionSyncState();

      expect(Prefs.activeLogPageId, isNull);
      expect(Prefs.syncedMinutes, equals(0));
      expect(Prefs.activeSessionExternalId, isNull);
    });

    test('resetTimer clears session sync state', () {
      Prefs.activeLogPageId = 'page-1';
      Prefs.syncedMinutes = 8;
      Prefs.activeSessionExternalId = 'sess_x';
      Prefs.duration = const Duration(minutes: 5);

      Prefs.resetTimer();

      expect(Prefs.activeLogPageId, isNull);
      expect(Prefs.syncedMinutes, equals(0));
      expect(Prefs.activeSessionExternalId, isNull);
    });
  });

  group('NotionService cache guard and idempotency checks', () {
    test('checkIdempotency returns null when apiKey is empty', () async {
      Prefs.notionApiKey = '';
      final res = await NotionService().checkIdempotency('ext-123');
      expect(res, isNull);
    });

    test('clearTaskFetchCache resets cache without throwing', () {
      expect(NotionService.clearTaskFetchCache, returnsNormally);
    });
  });

  group('NotionService.resolveLogTitles with multiple projects', () {
    setUp(NotionService.clearTaskFetchCache);

    test('splits, resolves, and joins multiple project titles', () async {
      final service = NotionService()
        ..cachePageTitle('proj-1', '📽️ Project Alpha')
        ..cachePageTitle('proj-2', '🏔️ Area Beta');

      final log = HourlyLog(
        id: 'hlog-1',
        dateStr: '2026-07-15',
        hour: 12,
        tagId: 'tag_coding',
        tagName: 'Coding',
        tagIcon: '💻',
        tagColorHex: '#4285F4',
        projectId: 'proj-1,proj-2',
        projectTitle: 'Project Alpha, Project Beta',
        loggedAt: DateTime.now(),
      );

      final resolved = await service.resolveLogTitles([log]);
      expect(
        resolved.first.projectTitle,
        equals('📽️ Project Alpha, 🏔️ Area Beta'),
      );
    });
  });

  group('NotionService.getBaseUrl', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    tearDown(() {
      Prefs.notionProxyUrl = '';
      Prefs.notionApiKey = '';
    });

    test('uses custom absolute proxy url when configured', () {
      Prefs.notionProxyUrl = 'https://my-proxy.com/notion';
      expect(
        NotionService().getBaseUrl(),
        equals('https://my-proxy.com/notion/'),
      );
    });

    test('routes directly to Notion API on native with secret_ token', () {
      Prefs.notionProxyUrl = '';
      Prefs.notionApiKey = 'secret_live_12345';
      expect(
        NotionService().getBaseUrl(),
        equals('https://api.notion.com/v1/'),
      );
    });

    test('routes directly to Notion API on native with ntn_ token', () {
      Prefs.notionProxyUrl = '';
      Prefs.notionApiKey = 'ntn_live_67890';
      expect(
        NotionService().getBaseUrl(),
        equals('https://api.notion.com/v1/'),
      );
    });

    test('routes to default proxy when access code is used on native', () {
      Prefs.notionProxyUrl = '';
      Prefs.notionApiKey = 'focus_access_code_999';
      expect(
        NotionService().getBaseUrl(),
        equals(NotionService.defaultProxyUrl),
      );
    });
  });
}
