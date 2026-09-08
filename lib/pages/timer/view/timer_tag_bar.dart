import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/pages/timer/timer.dart';
import 'package:pomo/pages/tracker/view/tag_create_dialog.dart';
import 'package:pomo/pages/tracker/view/tag_delete_dialog.dart';
import 'package:pomo/singletons/prefs.dart';

/// Multi-select activity tags that receive Pomodoro hourly credit.
class TimerTagBar extends StatefulWidget {
  const TimerTagBar({super.key});

  @override
  State<TimerTagBar> createState() => _TimerTagBarState();
}

class _TimerTagBarState extends State<TimerTagBar> {
  late List<TrackerTag> _tags;

  @override
  void initState() {
    super.initState();
    _tags = Prefs.trackerTags;
  }

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  void _showTagsLockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pause the timer to change activity tags.'),
      ),
    );
  }

  Future<void> _createTag() async {
    final cubit = context.read<TimerCubit>();
    if (!cubit.canModifyTags) {
      _showTagsLockedMessage();
      return;
    }
    final created = await showDialog<TrackerTag>(
      context: context,
      builder: (ctx) => const TagCreateDialog(),
    );
    if (!mounted || created == null) {
      return;
    }
    setState(() => _tags = Prefs.trackerTags);
    if (!cubit.state.activeTags.any((tag) => tag.id == created.id)) {
      cubit.toggleTag(created);
    }
  }

  Future<void> _deleteTag(TrackerTag tag) async {
    if (tag.isDefault) {
      return;
    }
    final cubit = context.read<TimerCubit>();
    if (!cubit.canModifyTags) {
      _showTagsLockedMessage();
      return;
    }
    final result = await showDialog<TagDeleteResult>(
      context: context,
      builder: (ctx) => TagDeleteDialog(tag: tag),
    );
    if (!mounted || result == null) {
      return;
    }
    cubit.replaceActiveTag(fromId: result.deleted.id, toTag: result.target);
    setState(() => _tags = Prefs.trackerTags);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reassigned ${result.reassignedLogCount} log row'
          '${result.reassignedLogCount == 1 ? '' : 's'} to '
          '${result.target.icon} ${result.target.name}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.watch<TimerCubit>();
    final canModifyTags = cubit.canModifyTags;
    final selected = cubit.state.activeTags;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ..._tags.map((tag) {
                final isSelected = selected.any((item) => item.id == tag.id);
                final color = _parseHexColor(tag.colorHex);
                return Material(
                  color: isSelected
                      ? color.withValues(alpha: 0.22)
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: canModifyTags
                        ? () => cubit.toggleTag(tag)
                        : _showTagsLockedMessage,
                    onLongPress: tag.isDefault || !canModifyTags
                        ? null
                        : () => _deleteTag(tag),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tag.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            tag.name,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? color
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (!tag.isDefault && canModifyTags) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _deleteTag(tag),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add tag'),
                onPressed: canModifyTags ? _createTag : _showTagsLockedMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
