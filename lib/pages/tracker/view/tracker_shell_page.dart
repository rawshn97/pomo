import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pomo/helpers/notion_url_helper.dart';
import 'package:pomo/pages/tracker/view/time_log_history_view.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:pomo/widgets/android_tracker_status_prompt.dart';
import 'package:url_launcher/url_launcher.dart';

/// Read-only time log history and analytics tab.
class TrackerShellPage extends StatelessWidget {
  const TrackerShellPage({super.key});

  void _openHourlyTimeline(BuildContext context) {
    if (!NotionUrlHelper.hasHourlyTimelineDatabaseId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set Hourly Timeline Database ID in Settings',
          ),
        ),
      );
      return;
    }
    final url = NotionUrlHelper.hourlyTimelineDatabaseUrl;
    launchUrl(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return AndroidTrackerStatusPrompt(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Time Log',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            if (Prefs.enableNotionSync)
              IconButton(
                tooltip: 'Open Notion Hourly Timeline',
                icon: SvgPicture.asset(
                  'assets/images/notion_logo.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: () => _openHourlyTimeline(context),
              ),
          ],
        ),
        body: const TimeLogHistoryView(),
      ),
    );
  }
}
