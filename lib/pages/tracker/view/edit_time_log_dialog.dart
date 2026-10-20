import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pomo/helpers/time_log_analytics_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// Modal dialog for editing or deleting an existing logged time record.
class EditTimeLogDialog extends StatefulWidget {
  const EditTimeLogDialog({
    required this.log,
    super.key,
  });

  final HourlyLog log;

  static Future<bool?> show(
    BuildContext context, {
    required HourlyLog log,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => EditTimeLogDialog(log: log),
    );
  }

  @override
  State<EditTimeLogDialog> createState() => _EditTimeLogDialogState();
}

class _EditTimeLogDialogState extends State<EditTimeLogDialog> {
  late int _durationMinutes;
  late TrackerTag _selectedTag;
  late TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _durationMinutes = widget.log.durationMinutes;
    _notesController = TextEditingController(text: widget.log.notes);

    final tags = Prefs.trackerTags;
    _selectedTag = tags.firstWhere(
      (t) => t.id == widget.log.tagId,
      orElse: () => TrackerTag(
        id: widget.log.tagId,
        name: widget.log.tagName,
        icon: widget.log.tagIcon,
        colorHex: widget.log.tagColorHex,
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _adjustMinutes(int delta) {
    setState(() {
      _durationMinutes = (_durationMinutes + delta).clamp(1, 360);
    });
  }

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Time Log?'),
        content: Text(
          'Remove ${_selectedTag.icon} ${_selectedTag.name} '
          '(${_durationMinutes}m) from ${widget.log.dateStr}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await Prefs.deleteHourlyLog(widget.log.id);
      if (widget.log.notionPageId != null &&
          Prefs.enableNotionSync &&
          Prefs.notionApiKey.isNotEmpty) {
        unawaited(
          NotionService()
              .deletePage(widget.log.notionPageId!)
              .catchError((_) => false),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _save() async {
    if (_durationMinutes < 1) return;

    setState(() => _isSaving = true);
    try {
      final updated = widget.log.copyWith(
        durationMinutes: _durationMinutes,
        tagId: _selectedTag.id,
        tagName: _selectedTag.name,
        tagIcon: _selectedTag.icon,
        tagColorHex: _selectedTag.colorHex,
        notes: _notesController.text.trim(),
        loggedAt: DateTime.now(),
      );

      await Prefs.saveHourlyLog(updated);

      if (Prefs.enableNotionSync &&
          Prefs.notionApiKey.isNotEmpty &&
          Prefs.notionHourlyTimelineDatabaseId.isNotEmpty) {
        unawaited(NotionSyncService().syncHourlyLog(updated));
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = Prefs.trackerTags;
    final hourLabel = '${widget.log.hour.toString().padLeft(2, '0')}:00';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Logged Time',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date & hour chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.log.dateStr} at $hourLabel',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Duration editing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Duration',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    TimeLogAnalyticsHelper.formatHoursMinutes(_durationMinutes),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _QuickAdjustButton(
                    label: '-15m',
                    onPressed: () => _adjustMinutes(-15),
                  ),
                  const SizedBox(width: 6),
                  _QuickAdjustButton(
                    label: '-5m',
                    onPressed: () => _adjustMinutes(-5),
                  ),
                  const SizedBox(width: 6),
                  _QuickAdjustButton(
                    label: '+5m',
                    onPressed: () => _adjustMinutes(5),
                  ),
                  const SizedBox(width: 6),
                  _QuickAdjustButton(
                    label: '+15m',
                    onPressed: () => _adjustMinutes(15),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Slider(
                value: _durationMinutes.toDouble(),
                min: 1,
                max: 180,
                divisions: 36,
                label: '$_durationMinutes mins',
                onChanged: (val) {
                  setState(() => _durationMinutes = val.round());
                },
              ),
              const SizedBox(height: 12),

              // Activity Tag selection
              Text(
                'Activity Tag',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) {
                  final isSelected = tag.id == _selectedTag.id;
                  final tagColor = _parseHex(tag.colorHex);
                  return FilterChip(
                    label: Text('${tag.icon} ${tag.name}'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedTag = tag);
                    },
                    selectedColor: tagColor.withValues(alpha: 0.25),
                    checkmarkColor: tagColor,
                    labelStyle: TextStyle(
                      color:
                          isSelected ? tagColor : theme.colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? tagColor
                          : theme.colorScheme.outlineVariant,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Notes
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Footer: Delete & Save
              Row(
                children: [
                  IconButton(
                    tooltip: 'Delete time log',
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: _isSaving ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAdjustButton extends StatelessWidget {
  const _QuickAdjustButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 6),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
