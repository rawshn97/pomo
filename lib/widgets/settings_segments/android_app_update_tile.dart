import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pomo/services/app_update_service.dart';

class AndroidAppUpdateTile extends StatefulWidget {
  const AndroidAppUpdateTile({
    super.key,
    this.isAndroidOverride,
    this.updateService,
  });

  final bool? isAndroidOverride;
  final AppUpdateService? updateService;

  @override
  State<AndroidAppUpdateTile> createState() => _AndroidAppUpdateTileState();
}

class _AndroidAppUpdateTileState extends State<AndroidAppUpdateTile> {
  late final AppUpdateService _service;
  var _busy = false;
  String _subtitle = 'Tap to check for updates';

  bool get _isAndroid =>
      widget.isAndroidOverride ?? (!kIsWeb && Platform.isAndroid);

  @override
  void initState() {
    super.initState();
    _service = widget.updateService ?? AppUpdateService();
    unawaited(_primeSubtitle());
  }

  Future<void> _primeSubtitle() async {
    if (!await _service.isEligible) return;
    if (mounted) {
      setState(() => _subtitle = 'Tap to check for updates');
    }
  }

  Future<void> _onTap() async {
    if (_busy) return;
    if (!await _service.isEligible) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'OTA updates apply to the production Android build only.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _busy = true;
      _subtitle = 'Checking...';
    });

    final check = await _service.checkForUpdate();
    if (!mounted) return;

    if (check.errorMessage != null) {
      setState(() {
        _busy = false;
        _subtitle = check.errorMessage!;
      });
      return;
    }

    if (!check.isUpdateAvailable || check.manifest == null) {
      setState(() {
        _busy = false;
        _subtitle = 'You are on the latest version.';
      });
      return;
    }

    final manifest = check.manifest!;
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Download & install'),
            ),
          ],
        );
      },
    );

    if (install != true) {
      if (mounted) {
        setState(() {
          _busy = false;
          _subtitle = 'Update v${manifest.versionName} available.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _subtitle = 'Downloading...');
    }

    final result = await _service.downloadAndInstall(manifest);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _subtitle = result.errorMessage ??
          (result.installed
              ? 'Installer opened. Confirm on the system screen.'
              : 'Install could not be started.');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAndroid) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: const Icon(Icons.system_update_alt),
      title: const Text('Check for updates'),
      subtitle: Text(_subtitle),
      onTap: _busy ? null : _onTap,
    );
  }
}
