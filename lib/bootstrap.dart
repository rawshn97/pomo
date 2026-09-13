import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pomo/desktop/desktop_window_service.dart';
import 'package:pomo/helpers/hook_helper.dart';
import 'package:pomo/helpers/hourly_log_writer.dart';
import 'package:pomo/helpers/tag_dedup_migration.dart';
import 'package:pomo/helpers/tag_registry_writer.dart';
import 'package:pomo/services/local_notification_service.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:window_manager/window_manager.dart';

class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    log('onChange(${bloc.runtimeType}, $change)');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log('onError(${bloc.runtimeType}, $error, $stackTrace)');
    super.onError(bloc, error, stackTrace);
  }
}

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  Bloc.observer = const AppBlocObserver();

  // Add cross-flavor configuration here

  WidgetsFlutterBinding.ensureInitialized();

  await Prefs().init();
  try {
    await TagDedupMigration.runIfNeeded();
  } catch (error, stackTrace) {
    log('TagDedupMigration failed: $error', stackTrace: stackTrace);
  }
  try {
    await TagRegistryWriter.writeIfPossible();
  } catch (error, stackTrace) {
    log('TagRegistryWriter failed: $error', stackTrace: stackTrace);
  }
  HookHelper.startHourlyTrackerLoop();
  unawaited(NotionSyncService().flushPendingHourlyLogs());
  // Pull logs created on other devices (e.g. the PWA) first, then reconcile
  // Resting into empty slots and recover custom Activity Tags from pulled rows.
  unawaited(
    NotionSyncService().pullHourlyLogs().then((_) {
      return HourlyLogWriter.reconcileResting();
    }).then((_) => NotionSyncService().syncActivityTags()),
  );

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    if (Platform.isMacOS) {
      await LocalNotificationService.instance.init();
      if (Prefs.enableDesktopNotifications) {
        // Non-blocking; user can also grant later via Settings toggle.
        unawaited(LocalNotificationService.instance.requestPermission());
      }
    }

    final startHidden =
        Platform.isMacOS && await DesktopWindowService.shouldStartHidden();

    // Restore the last window size the user chose; fall back to the native
    // window's preloaded 800x600 frame. An opaque background keeps the
    // titlebar (traffic-light) area rendering normally.
    final windowOptions = WindowOptions(
      size: Prefs.windowSize ?? const Size(800, 600),
      skipTaskbar: startHidden,
      minimumSize: const Size(500, 500),
      title: 'Pomo',
      alwaysOnTop: Prefs.alwaysOnTop,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (startHidden) {
        await DesktopWindowService.setAccessoryActivation();
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    });

    if (Platform.isMacOS && !startHidden) {
      await windowManager.setSkipTaskbar(false);
    }
  }

  runApp(await builder());
}
