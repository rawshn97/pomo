import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pomo/models/app_update_manifest.dart';
import 'package:pomo/services/app_update_service.dart';

/// Checks for Android OTA updates on launch and shows an install prompt.
class AppUpdateListener extends StatefulWidget {
  const AppUpdateListener({required this.child, super.key});

  final Widget child;

  @override
  State<AppUpdateListener> createState() => _AppUpdateListenerState();
}

class _AppUpdateListenerState extends State<AppUpdateListener> {
  final _service = AppUpdateService();
  var _promptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkOnLaunch());
    });
  }

  Future<void> _checkOnLaunch() async {
    if (!await _service.isEligible || _promptShown) return;
    final result = await _service.checkForUpdate();
    if (!mounted || !result.isUpdateAvailable || result.manifest == null) {
      return;
    }
    _promptShown = true;
    await _showUpdateDialog(result.manifest!);
  }

  Future<void> _showUpdateDialog(AppUpdateManifest manifest) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final install = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Update available (v${manifest.versionName})'),
          content: Text(
            manifest.changelog.isEmpty
                ? 'A newer version of Pomo is ready to install.'
                : manifest.changelog,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Download & install'),
            ),
          ],
        );
      },
    );
    if (install != true || !mounted) return;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return const AlertDialog(
            title: Text('Downloading update'),
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Please keep Pomo open.')),
              ],
            ),
          );
        },
      ),
    );

    final result = await _service.downloadAndInstall(manifest);
    if (mounted) {
      navigator.pop();
    }

    if (!mounted) return;
    final message = result.errorMessage ??
        (result.installed
            ? 'Follow the system prompt to finish installing.'
            : 'Update could not be installed.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
