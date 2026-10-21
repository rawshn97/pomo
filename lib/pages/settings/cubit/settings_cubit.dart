import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:pomo/helpers/hook_helper.dart';
import 'package:pomo/services/android_notification_service.dart';
import 'package:pomo/services/launch_at_login_service.dart';
import 'package:pomo/services/local_notification_service.dart';
import 'package:pomo/singletons/prefs.dart';

part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(SettingsInitial());

  void loadSettings() {
    emit(
      SettingsState(
        alwaysOnTop: Prefs.alwaysOnTop,
        themeMode: Prefs.themeMode,
        autoAdvance: Prefs.autoAdvance,
        workMinutes: Prefs.workMinutes,
        shortBreakMinutes: Prefs.shortBreakMinutes,
        longBreakMinutes: Prefs.longBreakMinutes,
        lapCount: Prefs.lapCount,
        workStartWebHook: Prefs.workStartWebHook,
        workEndWebHook: Prefs.workEndWebHook,
        shortBreakStartWebHook: Prefs.shortBreakStartWebHook,
        shortBreakEndWebHook: Prefs.shortBreakEndWebHook,
        longBreakStartWebHook: Prefs.longBreakStartWebHook,
        longBreakEndWebHook: Prefs.longBreakEndWebHook,
        startTimerWebHook: Prefs.startTimerWebHook,
        stopTimerWebHook: Prefs.stopTimerWebHook,
        resetTimerWebHook: Prefs.resetTimerWebHook,
        enableWebHooks: Prefs.enableWebhooks,
        enableSound: Prefs.enableSound,
        triggerMethod: Prefs.triggerMethod,
        timerFont: Prefs.timerFont,
        timerCustomFont: Prefs.timerCustomFont,
        colorSeed: Prefs.colorSeed,
        customWorkStartSound: Prefs.customWorkStartSound,
        customWorkEndSound: Prefs.customWorkEndSound,
        customShortBreakStartSound: Prefs.customShortBreakStartSound,
        customShortBreakEndSound: Prefs.customShortBreakEndSound,
        customLongBreakStartSound: Prefs.customLongBreakStartSound,
        customLongBreakEndSound: Prefs.customLongBreakEndSound,
        showFloatingTimer: Prefs.showFloatingTimer,
        overlayCorner: Prefs.overlayCorner,
        notionApiKey: Prefs.notionApiKey,
        enableNotionSync: Prefs.enableNotionSync,
        notionProxyUrl: Prefs.notionProxyUrl,
        notionDatabaseId: Prefs.notionDatabaseId,
        notionTimeLogsDatabaseId: Prefs.notionTimeLogsDatabaseId,
        notionProjectsDatabaseId: Prefs.notionProjectsDatabaseId,
        notionAreasDatabaseId: Prefs.notionAreasDatabaseId,
        notionHourlyTimelineDatabaseId: Prefs.notionHourlyTimelineDatabaseId,
        enableTimeTracker: Prefs.enableTimeTracker,
        enableQuietHours: Prefs.enableQuietHours,
        quietHoursStart: Prefs.quietHoursStart,
        quietHoursEnd: Prefs.quietHoursEnd,
        enableDesktopNotifications: Prefs.enableDesktopNotifications,
        launchAtLogin: Prefs.launchAtLogin,
      ),
    );
  }

  // ignore: avoid_positional_boolean_parameters
  void setAlwaysOnTop(bool value) {
    Prefs.alwaysOnTop = value;
    emit(state.copyWith(alwaysOnTop: () => value));
  }

  void setThemeMode(ThemeMode value) {
    Prefs.themeMode = value;
    emit(state.copyWith(themeMode: () => value));
  }

  // ignore: avoid_positional_boolean_parameters
  void setAutoAdvance(bool value) {
    Prefs.autoAdvance = value;
    emit(state.copyWith(autoAdvance: () => value));
  }

  void setWorkMinutes(int value) {
    Prefs.workMinutes = value;
    emit(state.copyWith(workMinutes: () => value));
  }

  void setShortBreakMinutes(int value) {
    Prefs.shortBreakMinutes = value;
    emit(state.copyWith(shortBreakMinutes: () => value));
  }

  void setLongBreakMinutes(int value) {
    Prefs.longBreakMinutes = value;
    emit(state.copyWith(longBreakMinutes: () => value));
  }

  void setLapCount(int value) {
    Prefs.lapCount = value;
    emit(state.copyWith(lapCount: () => value));
  }

  void setWorkStartWebHook(String value) {
    Prefs.workStartWebHook = value;
    emit(state.copyWith(workStartWebHook: () => value));
  }

  void setWorkEndWebHook(String value) {
    Prefs.workEndWebHook = value;
    emit(state.copyWith(workEndWebHook: () => value));
  }

  void setShortBreakStartWebHook(String value) {
    Prefs.shortBreakStartWebHook = value;
    emit(state.copyWith(shortBreakStartWebHook: () => value));
  }

  void setShortBreakEndWebHook(String value) {
    Prefs.shortBreakEndWebHook = value;
    emit(state.copyWith(shortBreakEndWebHook: () => value));
  }

  void setLongBreakStartWebHook(String value) {
    Prefs.longBreakStartWebHook = value;
    emit(state.copyWith(longBreakStartWebHook: () => value));
  }

  void setLongBreakEndWebHook(String value) {
    Prefs.longBreakEndWebHook = value;
    emit(state.copyWith(longBreakEndWebHook: () => value));
  }

  void setStartTimerWebHook(String value) {
    Prefs.startTimerWebHook = value;
    emit(state.copyWith(startTimerWebHook: () => value));
  }

  void setStopTimerWebHook(String value) {
    Prefs.stopTimerWebHook = value;
    emit(state.copyWith(stopTimerWebHook: () => value));
  }

  void setResetTimerWebHook(String value) {
    Prefs.resetTimerWebHook = value;
    emit(state.copyWith(resetTimerWebHook: () => value));
  }

  void setTickWebHook(String value) {
    Prefs.tickWebHook = value;
    emit(state.copyWith(tickWebHook: () => value));
  }

  // ignore: avoid_positional_boolean_parameters
  void setEnableWebHooks(bool value) {
    Prefs.enableWebhooks = value;
    emit(state.copyWith(enableWebHooks: () => value));
  }

  void toggleSound() {
    Prefs.enableSound = !state.enableSound;
    emit(state.copyWith(enableSound: () => !state.enableSound));
  }

  void setTriggerMethod(TriggerMethod value) {
    Prefs.triggerMethod = value;
    emit(state.copyWith(triggerMethod: () => value));
  }

  void setTimerFont(TimerFont value) {
    Prefs.timerFont = value;
    emit(state.copyWith(timerFont: () => value));
  }

  void setTimerCustomFont(String value) {
    Prefs.timerCustomFont = value;
    emit(state.copyWith(timerCustomFont: () => value));
  }

  void setColorSeed(Color? value) {
    Prefs.colorSeed = value;
    emit(state.copyWith(colorSeed: () => value));
  }

  void setCustomWorkStartSound(String value) {
    Prefs.customWorkStartSound = value;
    emit(state.copyWith(customWorkStartSound: () => value));
  }

  void setCustomWorkEndSound(String value) {
    Prefs.customWorkEndSound = value;
    emit(state.copyWith(customWorkEndSound: () => value));
  }

  void setCustomShortBreakStartSound(String value) {
    Prefs.customShortBreakStartSound = value;
    emit(state.copyWith(customShortBreakStartSound: () => value));
  }

  void setCustomShortBreakEndSound(String value) {
    Prefs.customShortBreakEndSound = value;
    emit(state.copyWith(customShortBreakEndSound: () => value));
  }

  void setCustomLongBreakStartSound(String value) {
    Prefs.customLongBreakStartSound = value;
    emit(state.copyWith(customLongBreakStartSound: () => value));
  }

  void setCustomLongBreakEndSound(String value) {
    Prefs.customLongBreakEndSound = value;
    emit(state.copyWith(customLongBreakEndSound: () => value));
  }

  // ignore: avoid_positional_boolean_parameters
  void setShowFloatingTimer(bool value) {
    Prefs.showFloatingTimer = value;
    emit(state.copyWith(showFloatingTimer: () => value));
  }

  void setOverlayCorner(String value) {
    Prefs.overlayCorner = value;
    emit(state.copyWith(overlayCorner: () => value));
  }

  void setNotionApiKey(String value) {
    Prefs.notionApiKey = value;
    emit(state.copyWith(notionApiKey: () => value));
  }

  // ignore: avoid_positional_boolean_parameters
  void setEnableNotionSync(bool value) {
    Prefs.enableNotionSync = value;
    emit(state.copyWith(enableNotionSync: () => value));
  }

  void setNotionProxyUrl(String value) {
    Prefs.notionProxyUrl = value;
    emit(state.copyWith(notionProxyUrl: () => value));
  }

  void setNotionDatabaseId(String value) {
    Prefs.notionDatabaseId = value;
    emit(state.copyWith(notionDatabaseId: () => value));
  }

  void setNotionTimeLogsDatabaseId(String value) {
    Prefs.notionTimeLogsDatabaseId = value;
    emit(state.copyWith(notionTimeLogsDatabaseId: () => value));
  }

  void setNotionProjectsDatabaseId(String value) {
    Prefs.notionProjectsDatabaseId = value;
    emit(state.copyWith(notionProjectsDatabaseId: () => value));
  }

  void setNotionAreasDatabaseId(String value) {
    Prefs.notionAreasDatabaseId = value;
    emit(state.copyWith(notionAreasDatabaseId: () => value));
  }

  void setNotionHourlyTimelineDatabaseId(String value) {
    Prefs.notionHourlyTimelineDatabaseId = value;
    emit(state.copyWith(notionHourlyTimelineDatabaseId: () => value));
  }

  // ignore: avoid_positional_boolean_parameters
  void setEnableTimeTracker(bool value) {
    Prefs.enableTimeTracker = value;
    emit(state.copyWith(enableTimeTracker: () => value));
    unawaited(AndroidNotificationService().cancelHourlyAlarms());
  }

  // ignore: avoid_positional_boolean_parameters
  void setEnableQuietHours(bool value) {
    Prefs.enableQuietHours = value;
    emit(state.copyWith(enableQuietHours: () => value));
    unawaited(AndroidNotificationService().cancelHourlyAlarms());
  }

  void setQuietHoursStart(String value) {
    Prefs.quietHoursStart = value;
    emit(state.copyWith(quietHoursStart: () => value));
    unawaited(AndroidNotificationService().cancelHourlyAlarms());
  }

  void setQuietHoursEnd(String value) {
    Prefs.quietHoursEnd = value;
    emit(state.copyWith(quietHoursEnd: () => value));
    unawaited(AndroidNotificationService().cancelHourlyAlarms());
  }

  // ignore: avoid_positional_boolean_parameters
  void setRequestNotificationPermission(bool value) {
    Prefs.requestNotificationPermission = value;
    emit(state.copyWith(requestNotificationPermission: () => value));
  }

  // ignore: avoid_positional_boolean_parameters
  Future<void> setEnableDesktopNotifications(bool value) async {
    Prefs.enableDesktopNotifications = value;
    emit(state.copyWith(enableDesktopNotifications: () => value));
    if (value) {
      await LocalNotificationService.instance.requestPermission();
    }
  }

  // ignore: avoid_positional_boolean_parameters
  Future<void> setLaunchAtLogin(bool value) async {
    Prefs.launchAtLogin = value;
    emit(state.copyWith(launchAtLogin: () => value));
    await LaunchAtLoginService.instance.setEnabled(enabled: value);
  }
}
