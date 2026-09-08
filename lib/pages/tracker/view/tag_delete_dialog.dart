import 'package:flutter/material.dart';
import 'package:pomo/helpers/tag_reassign_helper.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// Deletes a custom tag after reassigning its hourly logs to another tag.
class TagDeleteDialog extends StatefulWidget {
  const TagDeleteDialog({
    required this.tag,
    super.key,
  });

  final TrackerTag tag;

  @override
  State<TagDeleteDialog> createState() => _TagDeleteDialogState();
}

class _TagDeleteDialogState extends State<TagDeleteDialog> {
  TrackerTag? _target;
  late final int _affectedLogs;
  late final List<TrackerTag> _targets;

  @override
  void initState() {
    super.initState();
    _affectedLogs = TagReassignHelper.countLogsForTag(widget.tag.id);
    _targets =
        Prefs.trackerTags.where((tag) => tag.id != widget.tag.id).toList();
    if (_targets.length == 1) {
      _target = _targets.single;
    }
  }

  Future<void> _confirm() async {
    final target = _target;
    if (target == null) {
      return;
    }

    final count = await NotionSyncService().reassignAndDeleteActivityTag(
      from: widget.tag,
      to: target,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(
      TagDeleteResult(
        deleted: widget.tag,
        target: target,
        reassignedLogCount: count,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete tag?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reassign existing logs from '
            '"${widget.tag.icon} ${widget.tag.name}" '
            'to another tag before deleting it.',
          ),
          const SizedBox(height: 12),
          Text(
            '$_affectedLogs hourly log row${_affectedLogs == 1 ? '' : 's'} '
            'will move to the selected tag.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TrackerTag>(
            initialValue: _target,
            decoration: const InputDecoration(
              labelText: 'Reassign to',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final tag in _targets)
                DropdownMenuItem(
                  value: tag,
                  child: Text('${tag.icon} ${tag.name}'),
                ),
            ],
            onChanged: (value) => setState(() => _target = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _target == null ? null : _confirm,
          child: const Text('Delete and reassign'),
        ),
      ],
    );
  }
}

/// Result returned when a tag delete + reassign flow completes.
class TagDeleteResult {
  const TagDeleteResult({
    required this.deleted,
    required this.target,
    required this.reassignedLogCount,
  });

  final TrackerTag deleted;
  final TrackerTag target;
  final int reassignedLogCount;
}
