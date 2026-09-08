import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @pomo.
  ///
  /// In en, this message translates to:
  /// **'Pomo'**
  String get pomo;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Pomo'**
  String get title;

  /// No description provided for @lap.
  ///
  /// In en, this message translates to:
  /// **'Lap #{lap}'**
  String lap(num lap);

  /// No description provided for @shortBreak.
  ///
  /// In en, this message translates to:
  /// **'Short break #{lap}'**
  String shortBreak(num lap);

  /// No description provided for @longBreak.
  ///
  /// In en, this message translates to:
  /// **'Long break'**
  String get longBreak;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @workDuration.
  ///
  /// In en, this message translates to:
  /// **'Work duration ({minutes} minutes)'**
  String workDuration(num minutes);

  /// No description provided for @shortBreakDuration.
  ///
  /// In en, this message translates to:
  /// **'Short break duration ({minutes} minutes)'**
  String shortBreakDuration(num minutes);

  /// No description provided for @longBreakDuration.
  ///
  /// In en, this message translates to:
  /// **'Long break duration ({minutes} minutes)'**
  String longBreakDuration(num minutes);

  /// No description provided for @lapCount.
  ///
  /// In en, this message translates to:
  /// **'Lap count ({count} work laps)'**
  String lapCount(num count);

  /// No description provided for @autoAdvance.
  ///
  /// In en, this message translates to:
  /// **'Auto advance'**
  String get autoAdvance;

  /// No description provided for @alwaysOnTop.
  ///
  /// In en, this message translates to:
  /// **'Always on top'**
  String get alwaysOnTop;

  /// No description provided for @startWorkWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Start work webhook URL'**
  String get startWorkWebHookUrl;

  /// No description provided for @startShortBreakWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Start short break webhook URL'**
  String get startShortBreakWebHookUrl;

  /// No description provided for @startLongBreakWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Start long break webhook URL'**
  String get startLongBreakWebHookUrl;

  /// No description provided for @endWorkWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'End work webhook URL'**
  String get endWorkWebHookUrl;

  /// No description provided for @endShortBreakWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'End short break webhook URL'**
  String get endShortBreakWebHookUrl;

  /// No description provided for @endLongBreakWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'End long break webhook URL'**
  String get endLongBreakWebHookUrl;

  /// No description provided for @startTimerWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Start timer webhook URL'**
  String get startTimerWebHookUrl;

  /// No description provided for @stopTimerWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Stop timer webhook URL'**
  String get stopTimerWebHookUrl;

  /// No description provided for @resetTimerWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Reset timer webhook URL'**
  String get resetTimerWebHookUrl;

  /// No description provided for @stateChangeWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'State change webhook URL'**
  String get stateChangeWebHookUrl;

  /// No description provided for @tickWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Timer tick webhook URL'**
  String get tickWebHookUrl;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @requiresRestart.
  ///
  /// In en, this message translates to:
  /// **'Requires restart'**
  String get requiresRestart;

  /// No description provided for @webhooks.
  ///
  /// In en, this message translates to:
  /// **'Webhooks'**
  String get webhooks;

  /// No description provided for @enableWebhooks.
  ///
  /// In en, this message translates to:
  /// **'Enable Webhooks'**
  String get enableWebhooks;

  /// No description provided for @toggleSound.
  ///
  /// In en, this message translates to:
  /// **'Toggle sound'**
  String get toggleSound;

  /// No description provided for @startTimer.
  ///
  /// In en, this message translates to:
  /// **'Start timer'**
  String get startTimer;

  /// No description provided for @pauseTimer.
  ///
  /// In en, this message translates to:
  /// **'Pause timer'**
  String get pauseTimer;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @skipLap.
  ///
  /// In en, this message translates to:
  /// **'Skip lap'**
  String get skipLap;

  /// No description provided for @triggerMethod.
  ///
  /// In en, this message translates to:
  /// **'Trigger method'**
  String get triggerMethod;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @madeBy1.
  ///
  /// In en, this message translates to:
  /// **'Made by '**
  String get madeBy1;

  /// No description provided for @madeBy2.
  ///
  /// In en, this message translates to:
  /// **' - 2026'**
  String get madeBy2;

  /// No description provided for @timer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timer;

  /// No description provided for @autoAdvanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically advance to the next lap after the current lap is over'**
  String get autoAdvanceDescription;

  /// No description provided for @webhooksDescription.
  ///
  /// In en, this message translates to:
  /// **'Send a webhook request when the timer state changes. You can trigger multiple webhooks for the same event if you separate the URLs with a comma (,)'**
  String get webhooksDescription;

  /// No description provided for @timerFont.
  ///
  /// In en, this message translates to:
  /// **'Timer font'**
  String get timerFont;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @regular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get regular;

  /// No description provided for @mono.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get mono;

  /// No description provided for @boldMono.
  ///
  /// In en, this message translates to:
  /// **'Bold monospace'**
  String get boldMono;

  /// No description provided for @fancyMono.
  ///
  /// In en, this message translates to:
  /// **'Fancy monospace'**
  String get fancyMono;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @customFontName.
  ///
  /// In en, this message translates to:
  /// **'Custom font name'**
  String get customFontName;

  /// No description provided for @workEndSound.
  ///
  /// In en, this message translates to:
  /// **'Work end sound'**
  String get workEndSound;

  /// No description provided for @shortBreakEndSound.
  ///
  /// In en, this message translates to:
  /// **'Short break end sound'**
  String get shortBreakEndSound;

  /// No description provided for @longBreakEndSound.
  ///
  /// In en, this message translates to:
  /// **'Long break end sound'**
  String get longBreakEndSound;

  /// No description provided for @workStartSound.
  ///
  /// In en, this message translates to:
  /// **'Work start sound'**
  String get workStartSound;

  /// No description provided for @shortBreakStartSound.
  ///
  /// In en, this message translates to:
  /// **'Short break start sound'**
  String get shortBreakStartSound;

  /// No description provided for @longBreakStartSound.
  ///
  /// In en, this message translates to:
  /// **'Long break start sound'**
  String get longBreakStartSound;

  /// No description provided for @customSounds.
  ///
  /// In en, this message translates to:
  /// **'Custom sounds'**
  String get customSounds;

  /// No description provided for @customSoundFile.
  ///
  /// In en, this message translates to:
  /// **'Custom file...'**
  String get customSoundFile;

  /// No description provided for @previewSound.
  ///
  /// In en, this message translates to:
  /// **'Preview sound'**
  String get previewSound;

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @timerTitle.
  ///
  /// In en, this message translates to:
  /// **'{time} {stoppedEmoji} | Pomo - Pomodoro timer'**
  String timerTitle(String time, String stoppedEmoji);

  /// No description provided for @showFloatingTimer.
  ///
  /// In en, this message translates to:
  /// **'Show floating timer'**
  String get showFloatingTimer;

  /// No description provided for @showFloatingTimerDescription.
  ///
  /// In en, this message translates to:
  /// **'Display a small countdown pill over other apps while a session is active'**
  String get showFloatingTimerDescription;

  /// No description provided for @overlayCorner.
  ///
  /// In en, this message translates to:
  /// **'Overlay position'**
  String get overlayCorner;

  /// No description provided for @overlayCornerDescription.
  ///
  /// In en, this message translates to:
  /// **'Default corner for the floating timer widget'**
  String get overlayCornerDescription;

  /// No description provided for @enableDesktopNotifications.
  ///
  /// In en, this message translates to:
  /// **'Desktop notifications'**
  String get enableDesktopNotifications;

  /// No description provided for @enableDesktopNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Notify on hourly check-ins and when work or break laps end'**
  String get enableDesktopNotificationsDescription;

  /// No description provided for @launchAtLogin.
  ///
  /// In en, this message translates to:
  /// **'Launch at login'**
  String get launchAtLogin;

  /// No description provided for @launchAtLoginDescription.
  ///
  /// In en, this message translates to:
  /// **'Start Pomo in the menu bar when you log in (window stays hidden)'**
  String get launchAtLoginDescription;

  /// No description provided for @notionIntegration.
  ///
  /// In en, this message translates to:
  /// **'Notion Integration'**
  String get notionIntegration;

  /// No description provided for @enableNotionSync.
  ///
  /// In en, this message translates to:
  /// **'Enable Notion Sync'**
  String get enableNotionSync;

  /// No description provided for @enableNotionSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync completed Pomodoro sessions and partial time logs back to your PARA Dashboard Notion database'**
  String get enableNotionSyncDescription;

  /// No description provided for @notionApiKey.
  ///
  /// In en, this message translates to:
  /// **'Access code / Notion token'**
  String get notionApiKey;

  /// No description provided for @notionApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'access code or secret_...'**
  String get notionApiKeyHint;

  /// No description provided for @notionProxyUrl.
  ///
  /// In en, this message translates to:
  /// **'Notion Proxy URL (Optional)'**
  String get notionProxyUrl;

  /// No description provided for @notionProxyUrlHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. /api/notion/ or proxy server'**
  String get notionProxyUrlHint;

  /// No description provided for @selectTask.
  ///
  /// In en, this message translates to:
  /// **'Select Task'**
  String get selectTask;

  /// No description provided for @activeTask.
  ///
  /// In en, this message translates to:
  /// **'Active Task'**
  String get activeTask;

  /// No description provided for @clearTask.
  ///
  /// In en, this message translates to:
  /// **'Clear Task'**
  String get clearTask;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due Today'**
  String get dueToday;

  /// No description provided for @dueThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Due This Week'**
  String get dueThisWeek;

  /// No description provided for @searchTasks.
  ///
  /// In en, this message translates to:
  /// **'Search Tasks...'**
  String get searchTasks;

  /// No description provided for @noTasksFound.
  ///
  /// In en, this message translates to:
  /// **'No tasks found.'**
  String get noTasksFound;

  /// No description provided for @notionNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Please configure your Notion API Token in Settings.'**
  String get notionNotConfigured;

  /// No description provided for @timeTrackerAndAutomation.
  ///
  /// In en, this message translates to:
  /// **'Time Tracker & Automation'**
  String get timeTrackerAndAutomation;

  /// No description provided for @enableTimeTracker.
  ///
  /// In en, this message translates to:
  /// **'Enable Time Tracker'**
  String get enableTimeTracker;

  /// No description provided for @enableTimeTrackerDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically track elapsed time and send webhooks or Notion logs'**
  String get enableTimeTrackerDescription;

  /// No description provided for @enableQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Enable quiet hours'**
  String get enableQuietHours;

  /// No description provided for @enableQuietHoursDescription.
  ///
  /// In en, this message translates to:
  /// **'Silence unattended hourly reminders during the selected time range'**
  String get enableQuietHoursDescription;

  /// No description provided for @quietHoursStart.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours start'**
  String get quietHoursStart;

  /// No description provided for @quietHoursEnd.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours end'**
  String get quietHoursEnd;

  /// No description provided for @logPastTime.
  ///
  /// In en, this message translates to:
  /// **'Log past time'**
  String get logPastTime;

  /// No description provided for @logPastTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Missed Time'**
  String get logPastTimeTitle;

  /// No description provided for @hoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hoursLabel;

  /// No description provided for @minutesLabel.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutesLabel;

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick Add:'**
  String get quickAdd;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @timeLoggedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully logged {duration} to {task}'**
  String timeLoggedSuccess(String duration, String task);
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
  }

  throw FlutterError(
      'S.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
