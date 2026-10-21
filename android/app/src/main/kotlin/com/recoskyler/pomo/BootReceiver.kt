package com.recoskyler.pomo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * After reboot, AlarmManager exact alarms are cleared. Reschedule when the
 * time tracker preference is enabled (A19).
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        // Hourly check-in reminders decommissioned.
        HourlyAlarmScheduler.cancel(context)
    }
}
