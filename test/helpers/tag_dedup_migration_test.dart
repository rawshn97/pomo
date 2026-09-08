import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/tag_dedup_migration.dart';
import 'package:pomo/helpers/tag_registry_writer.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagDedupMigration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pomo-tag-tests');
      TagRegistryWriter.projectRootForTests = tempDir.path;
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
      Prefs.activityTagDedupMigrationVersion = 0;
      Prefs.enableNotionSync = false;
    });

    tearDown(() async {
      TagRegistryWriter.projectRootForTests = null;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('merges recovered duplicate into default and remaps timer tags',
        () async {
      const recovered = TrackerTag(
        id: 'tag_custom_recovered_reading___learning',
        name: 'Reading & Learning',
        icon: '📚',
        colorHex: '#5C6BC0',
      );
      Prefs.trackerTags = [...TrackerTag.defaults, recovered];
      Prefs.lastTimerTagIds = [recovered.id];
      Prefs.hourlyLogs = [
        HourlyLog(
          id: 'hlog_2026-09-03_10_tag_custom_recovered_reading___learning',
          dateStr: '2026-09-03',
          hour: 10,
          tagId: recovered.id,
          tagName: recovered.name,
          tagIcon: recovered.icon,
          tagColorHex: recovered.colorHex,
          loggedAt: DateTime(2026, 9, 3, 10),
        ),
      ];

      await TagDedupMigration.runIfNeeded();

      expect(
        Prefs.trackerTags.any(
          (tag) => tag.id == 'tag_custom_recovered_reading___learning',
        ),
        isFalse,
      );
      expect(Prefs.hourlyLogs.single.tagId, 'tag_reading');
      expect(Prefs.lastTimerTagIds, ['tag_reading']);
      expect(
        Prefs.activityTagDedupMigrationVersion,
        TagDedupMigration.currentVersion,
      );
    });

    test('runIfNeeded is idempotent', () async {
      Prefs.trackerTags = TrackerTag.defaults;
      await TagDedupMigration.runIfNeeded();
      final firstCount = Prefs.trackerTags.length;
      await TagDedupMigration.runIfNeeded();
      expect(Prefs.trackerTags.length, firstCount);
    });
  });

  group('TagRegistryWriter', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    test('builds markdown table sorted defaults then customs', () async {
      final dir = await Directory.systemTemp.createTemp('pomo-tag-registry');
      TagRegistryWriter.projectRootForTests = dir.path;
      Prefs.trackerTags = [
        ...TrackerTag.defaults,
        const TrackerTag(
          id: 'tag_custom_gaming',
          name: 'Gaming',
          icon: '⚽',
          colorHex: '#FFEE58',
        ),
      ];

      await TagRegistryWriter.writeIfPossible();
      final content =
          await File('${dir.path}/specs/activity-tags.md').readAsString();

      expect(content, contains('Do not edit manually'));
      expect(content, contains('`tag_coding`'));
      expect(content, contains('`tag_custom_gaming`'));
      expect(
        content.indexOf('Coding & Dev'),
        lessThan(content.indexOf('Gaming')),
      );
      TagRegistryWriter.projectRootForTests = null;
    });
  });
}
