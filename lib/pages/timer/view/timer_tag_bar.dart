import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/pages/timer/timer.dart';
import 'package:pomo/pages/tracker/view/tag_create_dialog.dart';
import 'package:pomo/pages/tracker/view/tag_delete_dialog.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:pomo/theme/rawshn_brand.dart';

/// Compact activity credit control: selected tags on one row; full catalog in
/// a bottom sheet so the Focus timer stays the hero on mobile.
class TimerTagBar extends StatefulWidget {
  const TimerTagBar({super.key});

  @override
  State<TimerTagBar> createState() => _TimerTagBarState();
}

class _TimerTagBarState extends State<TimerTagBar> {
  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return RawshnBrand.cyan;
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
    if (!cubit.state.activeTags.any((tag) => tag.id == created.id)) {
      cubit.toggleTag(created);
    }
    setState(() {});
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
    setState(() {});
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

  Future<void> _openTagSheet() async {
    final cubit = context.read<TimerCubit>();
    if (!cubit.canModifyTags) {
      _showTagsLockedMessage();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(
          value: cubit,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return _TagPickerSheet(
                scrollController: scrollController,
                parseHexColor: _parseHexColor,
                onCreateTag: () async {
                  Navigator.of(sheetContext).pop();
                  await _createTag();
                },
                onDeleteTag: _deleteTag,
              );
            },
          ),
        );
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.watch<TimerCubit>();
    final selected = cubit.state.activeTags;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openTagSheet,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  children: [
                    Text(
                      'ACTIVITY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: RawshnBrand.fontMono,
                        color: scheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: selected.isEmpty
                          ? Text(
                              'Tap to credit this focus block',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final tag in selected) ...[
                                    _SelectedTagChip(
                                      icon: tag.icon,
                                      name: tag.name,
                                      color: _parseHexColor(tag.colorHex),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                ],
                              ),
                            ),
                    ),
                    IconButton(
                      tooltip: 'Choose activity tags',
                      onPressed: _openTagSheet,
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedTagChip extends StatelessWidget {
  const _SelectedTagChip({
    required this.icon,
    required this.name,
    required this.color,
  });

  final String icon;
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({
    required this.scrollController,
    required this.parseHexColor,
    required this.onCreateTag,
    required this.onDeleteTag,
  });

  final ScrollController scrollController;
  final Color Function(String hex) parseHexColor;
  final Future<void> Function() onCreateTag;
  final Future<void> Function(TrackerTag tag) onDeleteTag;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late List<TrackerTag> _tags;

  @override
  void initState() {
    super.initState();
    _tags = Prefs.trackerTags;
  }

  void _reload() {
    setState(() => _tags = Prefs.trackerTags);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.watch<TimerCubit>();
    final selected = cubit.state.activeTags;
    final canModifyTags = cubit.canModifyTags;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: scheme.outline,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Credit this block',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selected.isEmpty
                          ? 'Pick one or more activity tags'
                          : '${selected.length} selected',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: canModifyTags ? widget.onCreateTag : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _tags)
                    _TagChoiceChip(
                      tag: tag,
                      selected: selected.any((item) => item.id == tag.id),
                      color: widget.parseHexColor(tag.colorHex),
                      canModify: canModifyTags,
                      onToggle: () {
                        cubit.toggleTag(tag);
                        _reload();
                      },
                      onDelete: tag.isDefault
                          ? null
                          : () async {
                              await widget.onDeleteTag(tag);
                              if (mounted) {
                                _reload();
                              }
                            },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TagChoiceChip extends StatelessWidget {
  const _TagChoiceChip({
    required this.tag,
    required this.selected,
    required this.color,
    required this.canModify,
    required this.onToggle,
    this.onDelete,
  });

  final TrackerTag tag;
  final bool selected;
  final Color color;
  final bool canModify;
  final VoidCallback onToggle;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected
          ? color.withValues(alpha: 0.22)
          : scheme.surface.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: canModify ? onToggle : null,
        onLongPress:
            onDelete == null || !canModify ? null : () => onDelete?.call(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tag.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                tag.name,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : scheme.onSurfaceVariant,
                ),
              ),
              if (!tag.isDefault && canModify && onDelete != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => onDelete?.call(),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
