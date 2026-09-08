package com.recoskyler.pomo

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.recoskyler.pomo/timer_notification"
    private val APP_UPDATE_CHANNEL = "com.recoskyler.pomo/app_update"
    private var methodChannel: MethodChannel? = null
    private var appUpdateChannel: MethodChannel? = null

    /// Cold-start safe store; Dart pulls via [getPendingNotificationPayload].
    private var pendingNotificationPayload: String? = null

    companion object {
        @Volatile
        private var liveChannel: MethodChannel? = null

        fun notifyDartNotificationTap(payload: String) {
            Handler(Looper.getMainLooper()).post {
                liveChannel?.invokeMethod("onNotificationTap", payload)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureNotificationPayload(intent)
        checkAndRequestNotificationPermission()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Warm path: handler is usually already registered.
        forwardNotificationPayload(intent)
    }

    private fun checkAndRequestNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
                return false
            }
        }
        return areNotificationsEnabled()
    }

    private fun areNotificationsEnabled(): Boolean {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return true
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            manager.areNotificationsEnabled()
        } else {
            true
        }
    }

    private fun captureNotificationPayload(intent: Intent?) {
        val payload = intent?.getStringExtra("pomo_notification_payload") ?: return
        pendingNotificationPayload = payload
        cancelHourlyNotificationIfNeeded(payload)
    }

    private fun forwardNotificationPayload(intent: Intent?) {
        val payload = intent?.getStringExtra("pomo_notification_payload") ?: return
        pendingNotificationPayload = payload
        cancelHourlyNotificationIfNeeded(payload)
        Handler(Looper.getMainLooper()).post {
            methodChannel?.invokeMethod("onNotificationTap", payload)
        }
    }

    /** Dismiss the hourly shade tile once the user acts (content tap or action). */
    private fun cancelHourlyNotificationIfNeeded(payload: String) {
        if (!payload.startsWith("hourly:")) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.cancel(TimerForegroundService.HOURLY_NOTIFICATION_ID)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureNotificationPayload(intent)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        liveChannel = methodChannel
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    val granted = checkAndRequestNotificationPermission()
                    result.success(granted)
                }
                "areNotificationsEnabled" -> {
                    result.success(areNotificationsEnabled())
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        powerManager.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(ignoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        val ignoring = powerManager.isIgnoringBatteryOptimizations(packageName)
                        if (!ignoring) {
                            try {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "getPendingNotificationPayload" -> {
                    val payload = pendingNotificationPayload
                    pendingNotificationPayload = null
                    result.success(payload)
                }
                "getPendingInstantHourlyWrites" -> {
                    val pending = HourlyAlarmScheduler.drainPendingInstantWrites(this)
                    result.success(pending)
                }
                "startForeground" -> {
                    checkAndRequestNotificationPermission()
                    val title = call.argument<String>("title") ?: "Focus Timer"
                    val text = call.argument<String>("text") ?: "25:00"
                    val isRunning = call.argument<Boolean>("isRunning") ?: true
                    val isHourly = call.argument<Boolean>("isHourly") ?: (title.contains("Time Tracker") || title.contains("Check-in"))
                    val payload = call.argument<String>("payload")
                    // Hourly routes to shade ID 1002; never replaces timer FGS.
                    TimerForegroundService.startService(this, title, text, isRunning, isHourly, payload)
                    result.success(true)
                }
                "showHourlyNotification" -> {
                    checkAndRequestNotificationPermission()
                    val title = call.argument<String>("title") ?: "Time Tracker: Check-in Required"
                    val text = call.argument<String>("text") ?: "Log the past hour."
                    val payload = call.argument<String>("payload")
                    TimerForegroundService.postHourlyNotification(this, title, text, payload)
                    result.success(true)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "Focus Timer"
                    val text = call.argument<String>("text") ?: "25:00"
                    val isRunning = call.argument<Boolean>("isRunning") ?: true
                    val isHourly = call.argument<Boolean>("isHourly") ?: (title.contains("Time Tracker") || title.contains("Check-in"))
                    val payload = call.argument<String>("payload")
                    TimerForegroundService.updateService(this, title, text, isRunning, isHourly, payload)
                    result.success(true)
                }
                "stopForeground" -> {
                    TimerForegroundService.stopService(this)
                    result.success(true)
                }
                "scheduleNextHourlyAlarm" -> {
                    val enableTracker = call.argument<Boolean>("enableTimeTracker") ?: true
                    val enableQuiet = call.argument<Boolean>("enableQuietHours") ?: true
                    val quietStart = call.argument<String>("quietHoursStart") ?: "23:00"
                    val quietEnd = call.argument<String>("quietHoursEnd") ?: "07:00"
                    HourlyAlarmScheduler.syncTrackerPrefs(
                        this,
                        enableTracker,
                        enableQuiet,
                        quietStart,
                        quietEnd,
                    )
                    if (!enableTracker) {
                        HourlyAlarmScheduler.cancel(this)
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    val triggerAt = call.argument<Number>("triggerAtMillis")?.toLong()
                    if (triggerAt != null) {
                        HourlyAlarmScheduler.schedule(this, triggerAt)
                    } else {
                        HourlyAlarmScheduler.scheduleNextHour(this)
                    }
                    result.success(true)
                }
                "cancelHourlyAlarms" -> {
                    HourlyAlarmScheduler.setTimeTrackerEnabled(this, false)
                    HourlyAlarmScheduler.cancel(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        TimerForegroundService.actionListener = { action ->
            Handler(Looper.getMainLooper()).post {
                methodChannel?.invokeMethod(action, null)
            }
        }
        // Cold start: do not push onNotificationTap on a fixed delay. Dart pulls
        // via getPendingNotificationPayload after setMethodCallHandler.

        appUpdateChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_UPDATE_CHANNEL,
        )
        appUpdateChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallPackages" -> {
                    val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(allowed)
                }
                "requestInstallPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (!packageManager.canRequestPackageInstalls()) {
                            try {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                ).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                                result.success(false)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID", "path is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("MISSING", "APK file not found", null)
                            return@setMethodCallHandler
                        }
                        val uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file,
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(
                                uri,
                                "application/vnd.android.package-archive",
                            )
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_GRANT_READ_URI_PERMISSION
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        TimerForegroundService.actionListener = null
        if (liveChannel === methodChannel) {
            liveChannel = null
        }
        methodChannel?.setMethodCallHandler(null)
        appUpdateChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
