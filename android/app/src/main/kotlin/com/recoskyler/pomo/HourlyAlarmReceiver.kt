package com.recoskyler.pomo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.PowerManager

/**
 * Fires at each exact hour boundary. Posts the hourly check-in shade
 * notification (ID 1002) with A4 payload + A3/A21 actions unless quiet hours
 * apply, then reschedules the next hour.
 *
 * Plays [R.raw.digital_beep] under a short WakeLock + audio focus so the
 * chime can sound when the process was restricted. Does not require a running
 * Dart isolate or timer FGS.
 */
class HourlyAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        // Hourly check-in reminders decommissioned.
        if (!HourlyAlarmScheduler.isTimeTrackerEnabled(context)) {
            HourlyAlarmScheduler.cancel(context)
            return
        }

        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "pomo:hourly_chime",
        )
        wakeLock?.acquire(1000)
        try {
            HourlyAlarmScheduler.cancel(context)
        } finally {
            if (wakeLock?.isHeld == true) {
                wakeLock.release()
            }
        }
    }

    private fun playHourlyChime(context: Context) {
        try {
            val audioManager =
                context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                    ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val request = AudioFocusRequest.Builder(
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
                )
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    .build()
                audioManager.requestAudioFocus(request)
            } else {
                @Suppress("DEPRECATION")
                audioManager.requestAudioFocus(
                    null,
                    AudioManager.STREAM_NOTIFICATION,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
                )
            }
            val player = MediaPlayer.create(context, R.raw.digital_beep) ?: return
            player.setOnCompletionListener { mediaPlayer ->
                mediaPlayer.release()
            }
            player.start()
        } catch (_: Exception) {
            // Channel sound remains a backup if MediaPlayer fails.
        }
    }
}
