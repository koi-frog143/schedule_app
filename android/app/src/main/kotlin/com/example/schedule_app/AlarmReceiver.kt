package com.example.schedule_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ALARM_CHANNEL_ID = "class_alarms_channel_v5"
        const val SILENT_CHANNEL_ID = "class_silent_channel_v5"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", (System.currentTimeMillis() % 100000).toInt())
        val title = intent.getStringExtra("title") ?: "Class Alarm"
        val body = intent.getStringExtra("body") ?: "Upcoming class reminder"
        val isAlarm = intent.getBooleanExtra("isAlarm", true)
        val repeatWeekly = intent.getBooleanExtra("repeatWeekly", false)
        val triggerAtMillis = intent.getLongExtra("triggerAtMillis", 0L)

        // 1. Wake the screen up to the lock screen (does NOT open the app)
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
                "schedule_app:alarm_wake"
            )
            wakeLock.acquire(4000)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 2. Direct hardware vibration for 3 seconds (guaranteed 1s-200ms-1s-200ms-1s pulse rhythm)
        if (isAlarm) {
            try {
                val timings = longArrayOf(0, 1000, 200, 1000, 200, 1000)
                val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                    val vibrator = vibratorManager?.defaultVibrator
                        ?: @Suppress("DEPRECATION") (context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator)
                    val attributes = VibrationAttributes.Builder()
                        .setUsage(VibrationAttributes.USAGE_ALARM)
                        .build()
                    vibrator?.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1), attributes)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                    val audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                    vibrator?.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1), audioAttributes)
                } else {
                    @Suppress("DEPRECATION")
                    val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(timings, -1)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // 3. Post notification to lock screen
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = if (isAlarm) ALARM_CHANNEL_ID else SILENT_CHANNEL_ID

            // Create notification channels if on Android O+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()

                val alarmChannel = NotificationChannel(
                    ALARM_CHANNEL_ID,
                    "Class Alarms",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Audible alarms and 3-second vibration for upcoming classes"
                    setSound(alarmSound, audioAttributes)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 1000, 200, 1000, 200, 1000)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }

                val silentChannel = NotificationChannel(
                    SILENT_CHANNEL_ID,
                    "Silent Class Reminders",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "Silent notifications for upcoming courses"
                    setSound(null, null)
                    enableVibration(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }

                notificationManager.createNotificationChannel(alarmChannel)
                notificationManager.createNotificationChannel(silentChannel)
            }

            // Cancel any previous notification with this ID first to prevent update suppression
            notificationManager.cancel(id)

            val tapIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingTap = PendingIntent.getActivity(
                context,
                id,
                tapIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, channelId)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }

            builder.setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setContentIntent(pendingTap)
                .setAutoCancel(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                builder.setCategory(if (isAlarm) Notification.CATEGORY_ALARM else Notification.CATEGORY_REMINDER)
                    .setPriority(Notification.PRIORITY_MAX)
            }

            if (isAlarm) {
                builder.setSound(alarmSound)
                @Suppress("DEPRECATION")
                builder.setVibrate(longArrayOf(0, 1000, 200, 1000, 200, 1000))
            }

            notificationManager.notify(id, builder.build())
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 4. Repeat for next week if configured
        if (repeatWeekly && triggerAtMillis > 0) {
            val nextWeekMillis = triggerAtMillis + 7L * 24 * 60 * 60 * 1000
            MainActivity.scheduleNativeAlarm(
                context,
                id,
                nextWeekMillis,
                title,
                body,
                isAlarm,
                true
            )
        }
    }
}
