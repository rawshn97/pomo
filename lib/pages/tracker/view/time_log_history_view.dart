import 'package:flutter/material.dart';
import 'package:pomo/helpers/hourly_log_writer.dart';
import 'package:pomo/helpers/time_log_analytics_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// Read-only history and analytics for timer-credited activity logs.
class TimeLogHistoryView extends StatefulWidget {
  const TimeLogHistoryView({super.key});

  @override
  State<TimeLogHistoryView> createState() => _TimeLogHistoryViewState();
}

class _TimeLogHistoryViewState extends State<TimeLogHistoryView> {
  int _periodDays = 7;
  DateTime _selectedDate = DateTime.now();
  List<HourlyLog> _allLogs = [];

  static const _periodOptions = <int, String>{
    7: '7 days',
    14: '14 days',
    30: '30 days',
    90: '90 days',
  };

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    setState(() => _allLogs = Prefs.hourlyLogs);
    NotionSyncService().syncActivityTags().then((_) {
      return NotionSyncService().pullHourlyLogs();
    }).then((_) {
      return HourlyLogWriter.reconcileResting();
    }).then((_) {
      if (!mounted) return;
      setState(() => _allLogs = Prefs.hourlyLogs);
    });
    NotionService().resolveLogTitles(Prefs.hourlyLogs).then((_) {
      if (mounted) setState(() => _allLogs = Prefs.hourlyLogs);
    });
  }

  String get _selectedDateStr => TimeLogAnalyticsHelper.dateStr(_selectedDate);

  PeriodAnalytics get _periodAnalytics => TimeLogAnalyticsHelper.analyzePeriod(
        logs: _allLogs,
        periodDays: _periodDays,
      );

  DaySummary get _selectedDaySummary =>
      TimeLogAnalyticsHelper.summarizeDay(_allLogs, _selectedDateStr);

  Map<int, List<HourlyLog>> get _selectedDayHourLogs =>
      TimeLogAnalyticsHelper.logsByHourForDate(_allLogs, _selectedDateStr);

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _selectDay(String dateStr) {
    setState(() {
      _selectedDate = TimeLogAnalyticsHelper.parseDateStr(dateStr);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analytics = _periodAnalytics;
    final daySummary = _selectedDaySummary;
    final dayHourLogs = _selectedDayHourLogs;
    final isToday =
        _selectedDateStr == TimeLogAnalyticsHelper.dateStr(DateTime.now());

    return RefreshIndicator(
      onRefresh: () async => _loadLogs(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _PeriodSelector(
            periodDays: _periodDays,
            options: _periodOptions,
            onChanged: (days) => setState(() => _periodDays = days),
          ),
          const SizedBox(height: 12),
          _SummaryGrid(
            totalMinutes: analytics.totalMinutes,
            avgDailyMinutes: analytics.avgDailyMinutes,
            activeDays: analytics.activeDays,
            periodDays: analytics.periodDays,
            streakDays: analytics.streakDays,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Time by Activity',
            child: _TagBreakdownSection(
              tags: analytics.tagBreakdown,
              totalMinutes: analytics.totalMinutes,
              parseColor: _parseHexColor,
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Peak Focus Hours',
            subtitle: 'When you logged the most time in this period',
            child: _PeakHoursChart(
              hourTotals: analytics.hourTotals,
              parseColor: (value) => theme.colorScheme.primary.withValues(
                alpha: 0.15 + (0.85 * value),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Daily History',
            subtitle: 'Tap a day to inspect its timeline',
            child: _DailyHistoryList(
              days: analytics.dailySummaries,
              selectedDateStr: _selectedDateStr,
              onSelectDay: _selectDay,
              parseColor: _parseHexColor,
            ),
          ),
          const SizedBox(height: 12),
          _DayDetailHeader(
            label: TimeLogAnalyticsHelper.formatDateLabel(_selectedDateStr),
            dateStr: _selectedDateStr,
            totalMinutes: daySummary.totalMinutes,
            activeHours: daySummary.activeHours,
            isToday: isToday,
            onPrevious: () => setState(
              () => _selectedDate =
                  _selectedDate.subtract(const Duration(days: 1)),
            ),
            onNext: isToday
                ? null
                : () => setState(
                      () => _selectedDate =
                          _selectedDate.add(const Duration(days: 1)),
                    ),
            onPickDate: _pickDate,
          ),
          const SizedBox(height: 8),
          if (daySummary.totalMinutes == 0)
            _EmptyDayCard(dateLabel: _selectedDateStr)
          else ...[
            _SectionCard(
              title: 'Day Breakdown',
              child: _TagBreakdownSection(
                tags: TimeLogAnalyticsHelper.tagBreakdown(
                  TimeLogAnalyticsHelper.logsForDate(
                      _allLogs, _selectedDateStr),
                ),
                totalMinutes: daySummary.totalMinutes,
                parseColor: _parseHexColor,
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Hour Timeline',
              child: _HourTimeline(
                hourLogs: dayHourLogs,
                parseColor: _parseHexColor,
                selectedDate: _selectedDate,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.periodDays,
    required this.options,
    required this.onChanged,
  });

  final int periodDays;
  final Map<int, String> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.entries.map((entry) {
          final selected = entry.key == periodDays;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) => onChanged(entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.totalMinutes,
    required this.avgDailyMinutes,
    required this.activeDays,
    required this.periodDays,
    required this.streakDays,
  });

  final int totalMinutes;
  final double avgDailyMinutes;
  final int activeDays;
  final int periodDays;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = [
      _StatCard(
        label: 'Total Focus',
        value: '${TimeLogAnalyticsHelper.formatHoursDecimal(totalMinutes)}h',
        icon: Icons.timelapse_outlined,
        color: theme.colorScheme.primary,
      ),
      _StatCard(
        label: 'Daily Average',
        value: '${(avgDailyMinutes / 60).toStringAsFixed(1)}h',
        icon: Icons.insights_outlined,
        color: theme.colorScheme.secondary,
      ),
      _StatCard(
        label: 'Active Days',
        value: '$activeDays / $periodDays',
        icon: Icons.calendar_today_outlined,
        color: theme.colorScheme.tertiary,
      ),
      _StatCard(
        label: 'Current Streak',
        value: streakDays == 0 ? '-' : '$streakDays d',
        icon: Icons.local_fire_department_outlined,
        color: Colors.orange,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumn = constraints.maxWidth >= 520;
        if (twoColumn) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: cards,
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 8),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 8),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TagBreakdownSection extends StatelessWidget {
  const _TagBreakdownSection({
    required this.tags,
    required this.totalMinutes,
    required this.parseColor,
  });

  final List<TagMinutes> tags;
  final int totalMinutes;
  final Color Function(String hex) parseColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tags.isEmpty) {
      return Text(
        'No focus time logged yet. Select tags on the Focus tab before starting the timer.',
        style: theme.textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: tags.map((tag) {
              return Expanded(
                flex: tag.minutes.clamp(1, 10000),
                child: Container(
                  height: 10,
                  color: parseColor(tag.colorHex),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        ...tags.map((tag) {
          final pct = totalMinutes > 0
              ? ((tag.minutes / totalMinutes) * 100).toStringAsFixed(0)
              : '0';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(tag.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tag.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${TimeLogAnalyticsHelper.formatHoursMinutes(tag.minutes)} ($pct%)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _PeakHoursChart extends StatelessWidget {
  const _PeakHoursChart({
    required this.hourTotals,
    required this.parseColor,
  });

  final List<int> hourTotals;
  final Color Function(double normalized) parseColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxTotal = hourTotals.fold<int>(0, (m, v) => v > m ? v : m);
    if (maxTotal == 0) {
      return Text(
        'No hourly pattern yet.',
        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
      );
    }

    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (hour) {
          final total = hourTotals[hour];
          final normalized = total / maxTotal;
          final barHeight = 8.0 + (normalized * 52);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Tooltip(
                message: total > 0
                    ? '${hour.toString().padLeft(2, '0')}:00 - '
                        '${TimeLogAnalyticsHelper.formatHoursMinutes(total)}'
                    : '${hour.toString().padLeft(2, '0')}:00',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: total > 0
                            ? parseColor(normalized)
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    if (hour % 6 == 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${hour.toString().padLeft(2, '0')}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ] else
                      const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DailyHistoryList extends StatelessWidget {
  const _DailyHistoryList({
    required this.days,
    required this.selectedDateStr,
    required this.onSelectDay,
    required this.parseColor,
  });

  final List<DaySummary> days;
  final String selectedDateStr;
  final ValueChanged<String> onSelectDay;
  final Color Function(String hex) parseColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMinutes =
        days.fold<int>(0, (m, d) => d.totalMinutes > m ? d.totalMinutes : m);

    return Column(
      children: days.map((day) {
        final selected = day.dateStr == selectedDateStr;
        final barFlex = maxMinutes > 0 ? day.totalMinutes.clamp(1, 10000) : 1;
        final emptyFlex = maxMinutes > 0
            ? (maxMinutes - day.totalMinutes).clamp(1, 10000)
            : 1;
        final tagColor = day.topTagColorHex != null
            ? parseColor(day.topTagColorHex!)
            : theme.colorScheme.primary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelectDay(day.dateStr),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            TimeLogAnalyticsHelper.formatDateLabel(day.dateStr),
                            style: TextStyle(
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          TimeLogAnalyticsHelper.formatHoursMinutes(
                            day.totalMinutes,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (day.totalMinutes > 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Row(
                          children: [
                            Expanded(
                              flex: barFlex,
                              child: Container(
                                height: 6,
                                color: tagColor,
                              ),
                            ),
                            Expanded(
                              flex: emptyFlex,
                              child: Container(
                                height: 6,
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (day.topTagName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${day.topTagIcon ?? ''} Top: ${day.topTagName}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'No focus time',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DayDetailHeader extends StatelessWidget {
  const _DayDetailHeader({
    required this.label,
    required this.dateStr,
    required this.totalMinutes,
    required this.activeHours,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
  });

  final String label;
  final String dateStr;
  final int totalMinutes;
  final int activeHours;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: onPrevious,
                tooltip: 'Previous day',
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today, size: 18),
                onPressed: onPickDate,
                tooltip: 'Pick date',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: onNext,
                tooltip: 'Next day',
              ),
            ],
          ),
          Text(dateStr, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'Focus: ${TimeLogAnalyticsHelper.formatHoursMinutes(totalMinutes)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                'Active hours: $activeHours',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty_outlined,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No focus time on $dateLabel',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Select activity tags on the Focus tab, then start the timer.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HourTimeline extends StatelessWidget {
  const _HourTimeline({
    required this.hourLogs,
    required this.parseColor,
    required this.selectedDate,
  });

  final Map<int, List<HourlyLog>> hourLogs;
  final Color Function(String hex) parseColor;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    final loggedHours = hourLogs.keys.toList()..sort();
    if (loggedHours.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: loggedHours.map((hour) {
        final logs = hourLogs[hour]!;
        final hourTotal =
            logs.fold<int>(0, (sum, log) => sum + log.durationMinutes);
        final isCurrentHour = isToday && hour == now.hour;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrentHour
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrentHour
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCurrentHour
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: logs.map((log) {
                        final color = parseColor(log.tagColorHex);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: color.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            '${log.tagIcon} ${log.tagName} (${log.durationMinutes}m)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (hourTotal > 60)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${hourTotal}m total in this hour',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
