import 'dart:io';

import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/singletons/prefs.dart';

/// Writes the canonical activity-tag inventory to specs/activity-tags.md.
class TagRegistryWriter {
  /// Test hook to redirect output away from the repo.
  static String? projectRootForTests;

  static Future<void> writeIfPossible() async {
    final root = projectRootForTests ?? _resolveProjectRoot();
    if (root == null) {
      return;
    }

    final file = File('$root/specs/activity-tags.md');
    await file.parent.create(recursive: true);
    await file.writeAsString(_buildMarkdown(Prefs.trackerTags));
  }

  static String _buildMarkdown(List<TrackerTag> tags) {
    const defaults = TrackerTag.defaults;
    final defaultIds = defaults.map((tag) => tag.id).toSet();
    final customs = tags.where((tag) => !defaultIds.contains(tag.id)).toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    final ordered = [
      for (final tag in defaults)
        if (tags.any((item) => item.id == tag.id)) tag,
      ...customs,
    ];

    final buffer = StringBuffer()
      ..writeln('# Activity tags registry (auto-generated)')
      ..writeln()
      ..writeln(
        'Do not edit manually. Updated when tags are saved, deleted, '
        'deduplicated, or synced.',
      )
      ..writeln()
      ..writeln('| Icon | Name | ID | Default | Color |')
      ..writeln('|------|------|----|---------|-------|');

    for (final tag in ordered) {
      buffer.writeln(
        '| ${tag.icon} | ${tag.name} | `${tag.id}` | '
        '${tag.isDefault ? 'yes' : 'no'} | ${tag.colorHex} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('**Total:** ${ordered.length} tags');
    return buffer.toString();
  }

  static String? _resolveProjectRoot() {
    var dir = Directory.current;
    for (var depth = 0; depth < 6; depth++) {
      if (File('${dir.path}/pubspec.yaml').existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        break;
      }
      dir = parent;
    }
    return null;
  }
}
