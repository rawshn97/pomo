import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pomo/helpers/hourly_log_writer.dart';
import 'package:pomo/helpers/time_log_analytics_helper.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/singletons/prefs.dart';

/// Modal dialog for manually logging past focus time by choosing start time,
/// end time, and an activity tag.
class ManualTimeEntryDialog extends StatefulWidget {
  const ManualTimeEntryDialog({
    this.initialDate,
    super.key,
  });

  final DateTime? initialDate;

  static Future<bool?> show(
    BuildContext context, {
    DateTime? initialDate,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ManualTimeEntryDialog(initialDate: initialDate),
    );
  }

  @override
  State<ManualTimeEntryDialog> createState() => _ManualTimeEntryDialogState();
}

class _ManualTimeEntryDialogState extends State<ManualTimeEntryDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late TrackerTag _selectedTag;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = widget.initialDate ?? now;

    // Default: past 60m ending at nearest minute of current hour
    final startHour = now.hour > 0 ? now.hour - 1 : 0;
    _startTime = TimeOfDay(hour: startHour, minute: now.minute);
    _endTime = TimeOfDay(hour: now.hour, minute: now.minute);

    final tags = Prefs.trackerTags;
    final lastTag = Prefs.lastTimerTags.firstOrNull;
    _selectedTag = lastTag ?? tags.first;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int get _calculatedDurationMinutes {
    final from = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    var to = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    if (to.isBefore(from)) {
      to = to.add(const Duration(days: 1));
    }
    return to.difference(from).inMinutes;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && mounted) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null && mounted) {
      setState(() => _endTime = picked);
    }
  }

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  Future<void> _save() async {
    final duration = _calculatedDurationMinutes;
    if (duration < 1) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final from = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      var to = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );
      if (to.isBefore(from)) {
        to = to.add(const Duration(days: 1));
      }

      await HourlyLogWriter.creditTimerMinutes(
        tags: [_selectedTag],
        from: from,
        to: to,
        totalMinutes: duration,
      );

      // Save as last-used tag for quick subsequent entry
      Prefs.lastTimerTagIds = [_selectedTag.id];

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
    final duration = _calculatedDurationMinutes;
    final formattedDuration =
        TimeLogAnalyticsHelper.formatHoursMinutes(duration);
    final tags = Prefs.trackerTags;
    final dateLabel = TimeLogAnalyticsHelper.formatDateLabel(
      TimeLogAnalyticsHelper.dateStr(_selectedDate),
    );

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
                    'Add Focus Time',
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
              const SizedBox(height: 16),

              // Date selection
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Date: $dateLabel',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        TimeLogAnalyticsHelper.dateStr(_selectedDate),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Start time and End time row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _pickStartTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Time',
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _startTime.format(context),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _pickEndTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Time',
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _endTime.format(context),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Duration readout
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: duration > 0
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : theme.colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      duration > 0 ? Icons.timer_outlined : Icons.error_outline,
                      size: 16,
                      color: duration > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      duration > 0
                          ? 'Duration: $formattedDuration'
                          : 'Invalid duration (0m)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: duration > 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Activity tag selection
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
              const SizedBox(height: 20),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: duration > 0 && !_isSaving ? _save : null,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Log Time'),
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
