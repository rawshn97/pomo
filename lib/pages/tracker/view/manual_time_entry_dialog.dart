import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pomo/helpers/hourly_log_writer.dart';
import 'package:pomo/helpers/quiet_hours_helper.dart';
import 'package:pomo/helpers/time_log_analytics_helper.dart';
import 'package:pomo/helpers/timer_tag_credit_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/singletons/prefs.dart';

/// Modal dialog for manually logging past focus time by choosing start time,
/// end time, and activity tags with overlap detection.
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
  late List<TrackerTag> _selectedTags;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
  bool _overwriteConflicting = false;

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
    final lastTags = Prefs.lastTimerTags;
    if (lastTags.isNotEmpty) {
      _selectedTags = List.from(lastTags);
    } else if (tags.isNotEmpty) {
      _selectedTags = [tags.first];
    } else {
      _selectedTags = const [];
    }
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

  List<HourlyLog> get _overlappingLogs {
    final duration = _calculatedDurationMinutes;
    if (duration < 1) return const [];

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

    final slices = TimerTagCreditHelper.sliceByHour(
      from: from,
      to: to,
      totalMinutes: duration,
    );
    final targetHours = slices.map((s) => s.hour).toSet();
    final targetDates = slices.map((s) => s.dateStr).toSet();

    return Prefs.hourlyLogs.where((log) {
      if (!targetDates.contains(log.dateStr)) return false;
      if (!targetHours.contains(log.hour)) return false;
      if (QuietHoursHelper.isAutoResting(log)) return false;
      return log.durationMinutes > 0;
    }).toList();
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
    if (duration < 1 || _selectedTags.isEmpty) {
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

      if (_overwriteConflicting) {
        for (final log in _overlappingLogs) {
          await Prefs.deleteHourlyLog(log.id);
        }
      }

      await HourlyLogWriter.creditTimerMinutes(
        tags: _selectedTags,
        from: from,
        to: to,
        totalMinutes: duration,
      );

      // Save as last-used tags for quick subsequent entry
      Prefs.lastTimerTagIds = _selectedTags.map((t) => t.id).toList();

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

              // Activity tag selection (multi-select with equal split)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Activity Tags',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_selectedTags.length > 1 && duration > 0)
                    Text(
                      '${duration ~/ _selectedTags.length}m each',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) {
                  final isSelected = _selectedTags.any((t) => t.id == tag.id);
                  final tagColor = _parseHex(tag.colorHex);
                  return FilterChip(
                    label: Text('${tag.icon} ${tag.name}'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        if (isSelected) {
                          if (_selectedTags.length > 1) {
                            _selectedTags.removeWhere((t) => t.id == tag.id);
                          }
                        } else {
                          _selectedTags.add(tag);
                        }
                      });
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

              // Overlap warning & overwrite selector
              if (_overlappingLogs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Overlaps with ${_overlappingLogs.length} '
                              'existing record(s)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _overlappingLogs.map((log) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              '${log.hour.toString().padLeft(2, '0')}:00: '
                              '${log.tagIcon} ${log.tagName} '
                              '(${log.durationMinutes}m)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _overwriteConflicting
                                  ? 'Mode: Overwrite & replace existing logs'
                                  : 'Mode: Add alongside (Merge up to 60m/hr)',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: _overwriteConflicting,
                            onChanged: (val) =>
                                setState(() => _overwriteConflicting = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
