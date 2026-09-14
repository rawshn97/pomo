part of 'settings_cubit.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.alwaysOnTop = false,
    this.autoAdvance = false,
    this.workMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.lapCount = 4,
    this.themeMode = ThemeMode.dark,
    this.workStartWebHook = '',
    this.workEndWebHook = '',
    this.shortBreakStartWebHook = '',
    this.shortBreakEndWebHook = '',
    this.longBreakStartWebHook = '',
    this.longBreakEndWebHook = '',
    this.startTimerWebHook = '',
    this.stopTimerWebHook = '',
    this.resetTimerWebHook = '',
    this.tickWebHook = '',
    this.locale = const Locale('en'),
    this.enableWebHooks = false,
    this.enableSound = true,
    this.triggerMethod = TriggerMethod.post,
    this.timerFont = TimerFont.boldMono,
    this.timerCustomFont = '',
    this.colorSeed,
    this.customWorkStartSound = '',
    this.customWorkEndSound = '',
    this.customShortBreakStartSound = '',
    this.customShortBreakEndSound = '',
    this.customLongBreakStartSound = '',
    this.customLongBreakEndSound = '',
    this.showFloatingTimer = true,
    this.overlayCorner = 'topRight',
    this.notionApiKey = '',
    this.enableNotionSync = false,
    this.notionProxyUrl = '',
    this.notionDatabaseId = '',
    this.notionTimeLogsDatabaseId = '',
    this.notionProjectsDatabaseId = '',
    this.notionAreasDatabaseId = '',
    this.notionHourlyTimelineDatabaseId = '',
    this.enableTimeTracker = true,
    this.enableQuietHours = true,
    this.quietHoursStart = '23:00',
    this.quietHoursEnd = '07:00',
    this.requestNotificationPermission = false,
    this.enableDesktopNotifications = true,
    this.launchAtLogin = false,
  });

  final ThemeMode themeMode;

  final bool alwaysOnTop;
  final bool autoAdvance;
  final bool enableWebHooks;
  final bool enableSound;
  final bool enableNotionSync;

  final String notionApiKey;
  final String notionProxyUrl;
  final String notionDatabaseId;
  final String notionTimeLogsDatabaseId;
  final String notionProjectsDatabaseId;
  final String notionAreasDatabaseId;
  final String notionHourlyTimelineDatabaseId;

  final bool enableTimeTracker;
  final bool enableQuietHours;
  final String quietHoursStart;
  final String quietHoursEnd;

  final bool requestNotificationPermission;
  final bool enableDesktopNotifications;
  final bool launchAtLogin;

  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;

  final int lapCount;

  final String workStartWebHook;
  final String workEndWebHook;
  final String shortBreakStartWebHook;
  final String shortBreakEndWebHook;
  final String longBreakStartWebHook;
  final String longBreakEndWebHook;
  final String startTimerWebHook;
  final String stopTimerWebHook;
  final String resetTimerWebHook;
  final String tickWebHook;

  final String timerCustomFont;

  final String customWorkStartSound;
  final String customWorkEndSound;
  final String customShortBreakStartSound;
  final String customShortBreakEndSound;
  final String customLongBreakStartSound;
  final String customLongBreakEndSound;

  final Locale locale;

  final TriggerMethod triggerMethod;
  final TimerFont timerFont;

  final Color? colorSeed;

  final bool showFloatingTimer;
  final String overlayCorner;

  SettingsState copyWith({
    ThemeMode Function()? themeMode,
    bool Function()? alwaysOnTop,
    bool Function()? autoAdvance,
    bool Function()? enableWebHooks,
    bool Function()? enableSound,
    int Function()? workMinutes,
    int Function()? shortBreakMinutes,
    int Function()? longBreakMinutes,
    int Function()? lapCount,
    String Function()? workStartWebHook,
    String Function()? workEndWebHook,
    String Function()? shortBreakStartWebHook,
    String Function()? shortBreakEndWebHook,
    String Function()? longBreakStartWebHook,
    String Function()? longBreakEndWebHook,
    String Function()? startTimerWebHook,
    String Function()? stopTimerWebHook,
    String Function()? resetTimerWebHook,
    String Function()? tickWebHook,
    Locale Function()? locale,
    TriggerMethod Function()? triggerMethod,
    TimerFont Function()? timerFont,
    String Function()? timerCustomFont,
    Color? Function()? colorSeed,
    String Function()? customWorkStartSound,
    String Function()? customWorkEndSound,
    String Function()? customShortBreakStartSound,
    String Function()? customShortBreakEndSound,
    String Function()? customLongBreakStartSound,
    String Function()? customLongBreakEndSound,
    bool Function()? showFloatingTimer,
    String Function()? overlayCorner,
    String Function()? notionApiKey,
    bool Function()? enableNotionSync,
    String Function()? notionProxyUrl,
    String Function()? notionDatabaseId,
    String Function()? notionTimeLogsDatabaseId,
    String Function()? notionProjectsDatabaseId,
    String Function()? notionAreasDatabaseId,
    String Function()? notionHourlyTimelineDatabaseId,
    bool Function()? enableTimeTracker,
    bool Function()? enableQuietHours,
    String Function()? quietHoursStart,
    String Function()? quietHoursEnd,
    bool Function()? requestNotificationPermission,
    bool Function()? enableDesktopNotifications,
    bool Function()? launchAtLogin,
  }) {
    return SettingsState(
      themeMode: themeMode != null ? themeMode() : this.themeMode,
      alwaysOnTop: alwaysOnTop != null ? alwaysOnTop() : this.alwaysOnTop,
      autoAdvance: autoAdvance != null ? autoAdvance() : this.autoAdvance,
      enableWebHooks:
          enableWebHooks != null ? enableWebHooks() : this.enableWebHooks,
      enableSound: enableSound != null ? enableSound() : this.enableSound,
      workMinutes: workMinutes != null ? workMinutes() : this.workMinutes,
      shortBreakMinutes: shortBreakMinutes != null
          ? shortBreakMinutes()
          : this.shortBreakMinutes,
      longBreakMinutes:
          longBreakMinutes != null ? longBreakMinutes() : this.longBreakMinutes,
      lapCount: lapCount != null ? lapCount() : this.lapCount,
      workStartWebHook:
          workStartWebHook != null ? workStartWebHook() : this.workStartWebHook,
      workEndWebHook:
          workEndWebHook != null ? workEndWebHook() : this.workEndWebHook,
      shortBreakStartWebHook: shortBreakStartWebHook != null
          ? shortBreakStartWebHook()
          : this.shortBreakStartWebHook,
      shortBreakEndWebHook: shortBreakEndWebHook != null
          ? shortBreakEndWebHook()
          : this.shortBreakEndWebHook,
      longBreakStartWebHook: longBreakStartWebHook != null
          ? longBreakStartWebHook()
          : this.longBreakStartWebHook,
      longBreakEndWebHook: longBreakEndWebHook != null
          ? longBreakEndWebHook()
          : this.longBreakEndWebHook,
      startTimerWebHook: startTimerWebHook != null
          ? startTimerWebHook()
          : this.startTimerWebHook,
      stopTimerWebHook:
          stopTimerWebHook != null ? stopTimerWebHook() : this.stopTimerWebHook,
      resetTimerWebHook: resetTimerWebHook != null
          ? resetTimerWebHook()
          : this.resetTimerWebHook,
      tickWebHook: tickWebHook != null ? tickWebHook() : this.tickWebHook,
      locale: locale != null ? locale() : this.locale,
      triggerMethod:
          triggerMethod != null ? triggerMethod() : this.triggerMethod,
      timerFont: timerFont != null ? timerFont() : this.timerFont,
      timerCustomFont:
          timerCustomFont != null ? timerCustomFont() : this.timerCustomFont,
      colorSeed: colorSeed != null ? colorSeed() : this.colorSeed,
      customWorkStartSound: customWorkStartSound != null
          ? customWorkStartSound()
          : this.customWorkStartSound,
      customWorkEndSound: customWorkEndSound != null
          ? customWorkEndSound()
          : this.customWorkEndSound,
      customShortBreakStartSound: customShortBreakStartSound != null
          ? customShortBreakStartSound()
          : this.customShortBreakStartSound,
      customShortBreakEndSound: customShortBreakEndSound != null
          ? customShortBreakEndSound()
          : this.customShortBreakEndSound,
      customLongBreakStartSound: customLongBreakStartSound != null
          ? customLongBreakStartSound()
          : this.customLongBreakStartSound,
      customLongBreakEndSound: customLongBreakEndSound != null
          ? customLongBreakEndSound()
          : this.customLongBreakEndSound,
      showFloatingTimer: showFloatingTimer != null
          ? showFloatingTimer()
          : this.showFloatingTimer,
      overlayCorner:
          overlayCorner != null ? overlayCorner() : this.overlayCorner,
      notionApiKey: notionApiKey != null ? notionApiKey() : this.notionApiKey,
      enableNotionSync:
          enableNotionSync != null ? enableNotionSync() : this.enableNotionSync,
      notionProxyUrl:
          notionProxyUrl != null ? notionProxyUrl() : this.notionProxyUrl,
      notionDatabaseId:
          notionDatabaseId != null ? notionDatabaseId() : this.notionDatabaseId,
      notionTimeLogsDatabaseId: notionTimeLogsDatabaseId != null
          ? notionTimeLogsDatabaseId()
          : this.notionTimeLogsDatabaseId,
      notionProjectsDatabaseId: notionProjectsDatabaseId != null
          ? notionProjectsDatabaseId()
          : this.notionProjectsDatabaseId,
      notionAreasDatabaseId: notionAreasDatabaseId != null
          ? notionAreasDatabaseId()
          : this.notionAreasDatabaseId,
      notionHourlyTimelineDatabaseId: notionHourlyTimelineDatabaseId != null
          ? notionHourlyTimelineDatabaseId()
          : this.notionHourlyTimelineDatabaseId,
      enableTimeTracker: enableTimeTracker != null
          ? enableTimeTracker()
          : this.enableTimeTracker,
      enableQuietHours:
          enableQuietHours != null ? enableQuietHours() : this.enableQuietHours,
      quietHoursStart:
          quietHoursStart != null ? quietHoursStart() : this.quietHoursStart,
      quietHoursEnd:
          quietHoursEnd != null ? quietHoursEnd() : this.quietHoursEnd,
      requestNotificationPermission: requestNotificationPermission != null
          ? requestNotificationPermission()
          : this.requestNotificationPermission,
      enableDesktopNotifications: enableDesktopNotifications != null
          ? enableDesktopNotifications()
          : this.enableDesktopNotifications,
      launchAtLogin:
          launchAtLogin != null ? launchAtLogin() : this.launchAtLogin,
    );
  }

  @override
  List<Object?> get props => [
        themeMode,
        alwaysOnTop,
        autoAdvance,
        enableWebHooks,
        enableSound,
        workMinutes,
        shortBreakMinutes,
        longBreakMinutes,
        lapCount,
        workStartWebHook,
        workEndWebHook,
        shortBreakStartWebHook,
        shortBreakEndWebHook,
        longBreakStartWebHook,
        longBreakEndWebHook,
        startTimerWebHook,
        stopTimerWebHook,
        resetTimerWebHook,
        tickWebHook,
        locale,
        triggerMethod,
        timerFont,
        timerCustomFont,
        colorSeed,
        customWorkStartSound,
        customWorkEndSound,
        customShortBreakStartSound,
        customShortBreakEndSound,
        customLongBreakStartSound,
        customLongBreakEndSound,
        showFloatingTimer,
        overlayCorner,
        notionApiKey,
        enableNotionSync,
        notionProxyUrl,
        notionDatabaseId,
        notionTimeLogsDatabaseId,
        notionProjectsDatabaseId,
        notionAreasDatabaseId,
        notionHourlyTimelineDatabaseId,
        enableTimeTracker,
        enableQuietHours,
        quietHoursStart,
        quietHoursEnd,
        requestNotificationPermission,
        enableDesktopNotifications,
        launchAtLogin,
      ];
}

final class SettingsInitial extends SettingsState {}
