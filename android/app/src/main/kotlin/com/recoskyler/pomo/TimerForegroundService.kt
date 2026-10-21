package com.recoskyler.pomo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Focus Timer foreground service (FGS) plus hourly shade helpers.
 *
 * Sticky policy:
 * - Timer FGS uses [TIMER_NOTIFICATION_ID] / [CHANNEL_ID], ongoing while a
 *   session is active. [START_NOT_STICKY]: if the OS kills the service, do not
 *   auto-restart without Dart session state.
 * - Hourly check-ins use [HOURLY_NOTIFICATION_ID] / [HOURLY_CHANNEL_ID]
 *   (IMPORTANCE_HIGH). They are shade notifications only (not FGS), so they
 *   never replace the timer tile and can be posted from [HourlyAlarmReceiver]
 *   without a running Dart isolate.
 */
class TimerForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "pomo_timer_channel_v2"
        const val HOURLY_CHANNEL_ID = "hourly_tracker_v2"
        const val TIMER_NOTIFICATION_ID = 1001
        const val HOURLY_NOTIFICATION_ID = 1002

        /** @deprecated Prefer [TIMER_NOTIFICATION_ID]; kept for call-site clarity. */
        const val NOTIFICATION_ID = TIMER_NOTIFICATION_ID

        const val ACTION_START = "ACTION_START"
        const val ACTION_UPDATE = "ACTION_UPDATE"
        const val ACTION_STOP_SERVICE = "ACTION_STOP_SERVICE"
        const val ACTION_PLAY = "ACTION_PLAY"
        const val ACTION_PAUSE = "ACTION_PAUSE"
        const val ACTION_STOP = "ACTION_STOP"

        var actionListener: ((String) -> Unit)? = null

        fun startService(
            context: Context,
            title: String,
            text: String,
            isRunning: Boolean,
            isHourly: Boolean = false,
            payload: String? = null,
            subText: String? = null,
            bigText: String? = null,
        ) {
            // Hourly is shade-only; never hijack the timer FGS notification.
            if (isHourly) {
                postHourlyNotification(context, title, text, payload)
                return
            }
            val intent = Intent(context, TimerForegroundService::class.java).apply {
                action = ACTION_START
                putExtra("title", title)
                putExtra("text", text)
                putExtra("subText", subText)
                putExtra("bigText", bigText)
                putExtra("isRunning", isRunning)
                putExtra("isHourly", false)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    context.startForegroundService(intent)
                } catch (e: Exception) {
                    // D5: Android 16 may throw ForegroundServiceStartNotAllowedException
                    // when starting from the background. Fall back to a plain notification.
                    postTimerFallbackNotification(context, title, text, isRunning)
                }
            } else {
                context.startService(intent)
            }
        }

        /**
         * Posts the hourly check-in shade notification (ID 1002).
         * Safe from [HourlyAlarmReceiver] with no Dart isolate.
         *
         * Content [PendingIntent] uses request code 13 + a unique action/data URI so
         * it never aliases the timer FGS content intent (request code 0; extras are
         * ignored by Intent.filterEquals). Same-hour re-posts from the Dart backup
         * loop are skipped via [HourlyAlarmScheduler] last-posted block ledger.
         */
        fun postHourlyNotification(
            context: Context,
            title: String,
            text: String,
            payload: String?,
        ) {
            ensureChannels(context)
            val blockKey = HourlyAlarmScheduler.blockKeyFromPayload(payload)
                ?: run {
                    val (hour, date) = HourlyAlarmScheduler.completedHourBlock(
                        System.currentTimeMillis(),
                    )
                    "$hour:$date"
                }
            if (!HourlyAlarmScheduler.shouldPostHourlyBlock(context, blockKey)) {
                return
            }
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.recoskyler.pomo.ACTION_OPEN_HOURLY"
                data = Uri.parse("pomo://hourly/${payload ?: "none"}")
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                if (payload != null) {
                    putExtra("pomo_notification_payload", payload)
                }
            }
            // Request code 13: distinct from timer content (0) and actions (10/11/12).
            val openAppPendingIntent = PendingIntent.getActivity(
                context, 13, openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val coffeeColor = Color.parseColor("#8D6E63")
            val builder = NotificationCompat.Builder(context, HOURLY_CHANNEL_ID)
                .setContentTitle(text)
                .setContentText(title)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setColor(coffeeColor)
                .setContentIntent(openAppPendingIntent)
                .setOngoing(false)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSubText("Hourly Tracker")
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
            if (payload != null) {
                builder.addAction(
                    0,
                    "Log 60m Work",
                    pendingHourlyAction(context, payload, "log_work", 10),
                )
                builder.addAction(
                    0,
                    "Switch Tag",
                    pendingHourlyAction(context, payload, "switch_tag", 11),
                )
                builder.addAction(
                    0,
                    "Open Grid",
                    pendingHourlyAction(context, payload, "open_grid", 12),
                )
            }
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.notify(HOURLY_NOTIFICATION_ID, builder.build())
            HourlyAlarmScheduler.markHourlyBlockPosted(context, blockKey)
        }

        private fun postTimerFallbackNotification(
            context: Context,
            title: String,
            text: String,
            isRunning: Boolean,
        ) {
            ensureChannels(context)
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context, 0, openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val toggleActionIntent = Intent(context, TimerForegroundService::class.java).apply {
                action = if (isRunning) ACTION_PAUSE else ACTION_PLAY
            }
            val togglePendingIntent = PendingIntent.getService(
                context, 1, toggleActionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val stopActionIntent = Intent(context, TimerForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            val stopPendingIntent = PendingIntent.getService(
                context, 2, stopActionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val toggleActionTitle = if (isRunning) "Pause" else "Resume"
            val toggleActionIcon = if (isRunning) {
                android.R.drawable.ic_media_pause
            } else {
                android.R.drawable.ic_media_play
            }
            val coffeeColor = Color.parseColor("#8D6E63")
            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setContentTitle(text)
                .setContentText(title)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setColor(coffeeColor)
                .setContentIntent(openAppPendingIntent)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSubText("Focus Timer")
                .setCategory(NotificationCompat.CATEGORY_PROGRESS)
                .addAction(toggleActionIcon, toggleActionTitle, togglePendingIntent)
                .addAction(android.R.drawable.ic_delete, "Stop", stopPendingIntent)
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.notify(TIMER_NOTIFICATION_ID, builder.build())
        }

        private fun pendingHourlyAction(
            context: Context,
            basePayload: String,
            action: String,
            requestCode: Int,
        ): PendingIntent {
            val actionPayload = "$basePayload:$action"
            if (action == "log_work") {
                val broadcast = Intent(context, HourlyLogActionReceiver::class.java).apply {
                    this.action = HourlyLogActionReceiver.ACTION
                    putExtra(HourlyLogActionReceiver.EXTRA_PAYLOAD, actionPayload)
                }
                return PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    broadcast,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
            val openIntent = Intent(context, MainActivity::class.java).apply {
                this.action = "com.recoskyler.pomo.ACTION_HOURLY_$action"
                data = Uri.parse("pomo://hourly/$actionPayload")
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("pomo_notification_payload", actionPayload)
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun ensureChannels(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    ?: return
            manager.deleteNotificationChannel("pomo_timer_channel")
            manager.deleteNotificationChannel("hourly_tracker")
            val timerChannel = NotificationChannel(
                CHANNEL_ID,
                "Focus Timer",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Shows active Focus Pomodoro countdown"
                setShowBadge(true)
            }
            val beepUri = Uri.parse(
                "android.resource://${context.packageName}/${R.raw.digital_beep}",
            )
            val hourlyAttrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val hourlyChannel = NotificationChannel(
                HOURLY_CHANNEL_ID,
                "Hourly Tracker",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Hourly check-in reminders for time tracking"
                setShowBadge(true)
                enableVibration(true)
                setSound(beepUri, hourlyAttrs)
            }
            manager.createNotificationChannel(timerChannel)
            manager.createNotificationChannel(hourlyChannel)
        }

        fun updateService(
            context: Context,
            title: String,
            text: String,
            isRunning: Boolean,
            isHourly: Boolean = false,
            payload: String? = null,
            subText: String? = null,
            bigText: String? = null,
        ) {
            if (isHourly) {
                postHourlyNotification(context, title, text, payload)
                return
            }
            val intent = Intent(context, TimerForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra("title", title)
                putExtra("text", text)
                putExtra("subText", subText)
                putExtra("bigText", bigText)
                putExtra("isRunning", isRunning)
                putExtra("isHourly", false)
            }
            context.startService(intent)
        }

        fun stopService(context: Context) {
            val intent = Intent(context, TimerForegroundService::class.java).apply {
                action = ACTION_STOP_SERVICE
            }
            context.startService(intent)
        }
    }

    private var currentTitle: String = "Focus Timer"
    private var currentText: String = "25:00"
    private var currentSubText: String = "Focus Timer"
    private var currentBigText: String = "Focus Timer"
    private var isCurrentlyRunning: Boolean = true

    override fun onCreate() {
        super.onCreate()
        ensureChannels(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        when (intent.action) {
            ACTION_START -> {
                currentTitle = intent.getStringExtra("title") ?: currentTitle
                currentText = intent.getStringExtra("text") ?: currentText
                currentSubText = intent.getStringExtra("subText") ?: currentSubText
                currentBigText = intent.getStringExtra("bigText") ?: currentBigText
                isCurrentlyRunning = intent.getBooleanExtra("isRunning", true)
                startForegroundNotification()
            }
            ACTION_UPDATE -> {
                currentTitle = intent.getStringExtra("title") ?: currentTitle
                currentText = intent.getStringExtra("text") ?: currentText
                currentSubText = intent.getStringExtra("subText") ?: currentSubText
                currentBigText = intent.getStringExtra("bigText") ?: currentBigText
                isCurrentlyRunning = intent.getBooleanExtra("isRunning", true)
                updateNotification()
            }
            ACTION_PLAY -> {
                actionListener?.invoke("onPlay")
            }
            ACTION_PAUSE -> {
                actionListener?.invoke("onPause")
            }
            ACTION_STOP -> {
                actionListener?.invoke("onStop")
            }
            ACTION_STOP_SERVICE -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
            }
        }

        // Timer FGS is not sticky: restarting without Dart session state would
        // show a stale countdown. Hourly reminders use AlarmManager instead.
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val toggleActionIntent = Intent(this, TimerForegroundService::class.java).apply {
            action = if (isCurrentlyRunning) ACTION_PAUSE else ACTION_PLAY
        }
        val togglePendingIntent = PendingIntent.getService(
            this, 1, toggleActionIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopActionIntent = Intent(this, TimerForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 2, stopActionIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val toggleActionTitle = if (isCurrentlyRunning) "Pause" else "Resume"
        val toggleActionIcon = if (isCurrentlyRunning) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play

        val coffeeColor = Color.parseColor("#8D6E63") // Warm coffee / mocha accent color

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentText)
            .setContentText(currentTitle)
            .setSubText(currentSubText)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setColor(coffeeColor)
            .setColorized(false)
            .setShowWhen(false)
            .setStyle(NotificationCompat.BigTextStyle()
                .setBigContentTitle(currentText)
                .setSummaryText(currentSubText)
                .bigText(currentBigText))
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .addAction(toggleActionIcon, toggleActionTitle, togglePendingIntent)
            .addAction(android.R.drawable.ic_delete, "Stop", stopPendingIntent)
            .build()
    }

    private fun startForegroundNotification() {
        try {
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                var fgsType = 0
                if (Build.VERSION.SDK_INT >= 34) { // Android 14+ / Android 16
                    fgsType = ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                }
                if (fgsType != 0) {
                    startForeground(TIMER_NOTIFICATION_ID, notification, fgsType)
                } else {
                    startForeground(TIMER_NOTIFICATION_ID, notification)
                }
            } else {
                startForeground(TIMER_NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Direct notification fallback ensures shade tile appears even if FGS start is restricted
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.notify(TIMER_NOTIFICATION_ID, buildNotification())
        }
    }

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.notify(TIMER_NOTIFICATION_ID, buildNotification())
    }
}
