import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pomo/helpers/android_background_prompt.dart';
import 'package:pomo/services/android_notification_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// Soft prompt for unrestricted battery and notifications when tracking.
class AndroidTrackerStatusPrompt extends StatefulWidget {
  const AndroidTrackerStatusPrompt({
    required this.child,
    super.key,
    this.isAndroidOverride,
    this.trackerEnabled,
    this.isIgnoringBatteryOptimizations,
    this.areNotificationsEnabled,
    this.requestIgnoreBatteryOptimizations,
    this.requestNotificationPermission,
  });

  final Widget child;
  final bool? isAndroidOverride;
  final bool? trackerEnabled;
  final Future<bool> Function()? isIgnoringBatteryOptimizations;
  final Future<bool> Function()? areNotificationsEnabled;
  final Future<bool> Function()? requestIgnoreBatteryOptimizations;
  final Future<bool> Function()? requestNotificationPermission;

  /// Shows the rationale dialog when Android tracker reminders may be silent.
  static Future<void> showIfNeeded(
    BuildContext context, {
    bool? isAndroidOverride,
    bool? trackerEnabled,
    Future<bool> Function()? isIgnoringBatteryOptimizations,
    Future<bool> Function()? areNotificationsEnabled,
    Future<bool> Function()? requestIgnoreBatteryOptimizations,
    Future<bool> Function()? requestNotificationPermission,
  }) async {
    final isAndroid = isAndroidOverride ?? (!kIsWeb && Platform.isAndroid);
    final trackerOn = trackerEnabled ?? Prefs.enableTimeTracker;
    final service = AndroidNotificationService();
    final ignoring = isIgnoringBatteryOptimizations != null
        ? await isIgnoringBatteryOptimizations()
        : await service.isIgnoringBatteryOptimizations();
    final notifications = areNotificationsEnabled != null
        ? await areNotificationsEnabled()
        : await service.areNotificationsEnabled();
    if (!context.mounted) return;
    if (!AndroidBackgroundPrompt.shouldPrompt(
      isAndroid: isAndroid,
      trackerEnabled: trackerOn,
      ignoringBatteryOptimizations: ignoring,
      notificationsEnabled: notifications,
    )) {
      return;
    }

    final allow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Keep hourly reminders reliable'),
          content: const Text(
            'Allow unrestricted battery and notifications so hourly '
            'check-ins can fire when the app is in the background.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
    if (allow ?? false) {
      if (requestIgnoreBatteryOptimizations != null) {
        await requestIgnoreBatteryOptimizations();
      } else {
        await service.requestIgnoreBatteryOptimizations();
      }
      if (requestNotificationPermission != null) {
        await requestNotificationPermission();
      } else {
        await service.requestNotificationPermission();
      }
    } else {
      AndroidBackgroundPrompt.dismissedThisSession = true;
    }
  }

  @override
  State<AndroidTrackerStatusPrompt> createState() =>
      _AndroidTrackerStatusPromptState();
}

class _AndroidTrackerStatusPromptState
    extends State<AndroidTrackerStatusPrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AndroidTrackerStatusPrompt.showIfNeeded(
        context,
        isAndroidOverride: widget.isAndroidOverride,
        trackerEnabled: widget.trackerEnabled,
        isIgnoringBatteryOptimizations: widget.isIgnoringBatteryOptimizations,
        areNotificationsEnabled: widget.areNotificationsEnabled,
        requestIgnoreBatteryOptimizations:
            widget.requestIgnoreBatteryOptimizations,
        requestNotificationPermission: widget.requestNotificationPermission,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
