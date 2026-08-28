package com.example.daily_apps

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
import android.provider.Settings
import androidx.core.app.NotificationCompat

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val CHANNEL_ID = "todo_reminder_alarm_channel_v3"
        const val CHANNEL_NAME = "Pengingat Alarm To-Do List"
        const val CHANNEL_DESC = "Alarm pengingat tugas to-do list yang belum selesai dengan suara looping, getar, dan layar penuh."
    }

    override fun onReceive(context: Context, intent: Intent) {
        val payload = intent.getStringExtra("payload") ?: "{}"
        val title = intent.getStringExtra("title") ?: "🚨 Tugasmu belum selesai nih"
        val body = intent.getStringExtra("body") ?: "Ada tugas to-do list yang belum selesai!"
        val notificationId = intent.getIntExtra("notificationId", 88888)

        // 1. Bangunkan sistem dengan WakeLock
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "DailyApps:AlarmWakeLock"
        )
        wakeLock?.acquire(15000L) // Tahan wake lock selama 15 detik

        // 2. Buat Notification Channel untuk Alarm jika belum ada
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()

            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESC
                enableLights(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000, 500, 1000)
                setSound(soundUri, audioAttributes)
                setBypassDnd(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }

        // 3. Siapkan Intent untuk membuka aplikasi
        val activityIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra("ALARM_TRIGGER_PAYLOAD", payload)
            putExtra("IS_ALARM_DIRECT_LAUNCH", true)
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val contentPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            activityIntent,
            flags
        )

        // Full-screen intent pending intent
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            notificationId + 100000,
            activityIntent,
            flags
        )

        // Dismiss action intent
        val dismissIntent = Intent(context, AlarmActionReceiver::class.java).apply {
            action = "com.example.daily_apps.ACTION_DISMISS_ALARM"
            putExtra("notificationId", notificationId)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 200000,
            dismissIntent,
            flags
        )

        // 4. Bangun Notifikasi Berprioritas Tinggi (Full Screen Intent)
        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(soundUri)
            .setVibrate(longArrayOf(0, 1000, 500, 1000, 500, 1000))
            .setAutoCancel(true)
            .setContentIntent(contentPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(R.mipmap.launcher_icon, "Iyaa tau", dismissPendingIntent)
            .addAction(R.mipmap.launcher_icon, "Buka To-Do", contentPendingIntent)
            .build()

        notificationManager.notify(notificationId, notification)

        // 5. Jika izin overlay ("Tampilkan di atas aplikasi lain") aktif atau aplikasi sedang diizinkan, luncurkan activity langsung
        try {
            var canLaunchDirectly = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                canLaunchDirectly = Settings.canDrawOverlays(context)
            }
            if (canLaunchDirectly) {
                context.startActivity(activityIntent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 6. Teruskan sinyal ke MainActivity jika instance sedang berjalan
        MainActivity.sendAlarmEventToFlutter(payload)
    }
}
