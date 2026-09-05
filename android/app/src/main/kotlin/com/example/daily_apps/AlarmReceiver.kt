package com.example.daily_apps

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat

import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val payload = intent.getStringExtra("payload") ?: "{}"
        val title = intent.getStringExtra("title") ?: "🚨 Tugasmu belum selesai nih"
        val body = intent.getStringExtra("body") ?: "Ada tugas to-do list yang belum selesai!"
        val notificationId = intent.getIntExtra("notificationId", 88888)

        // 0. Verifikasi apakah tanggal to-do list pada payload sudah terlewat (sebelum hari ini)
        try {
            if (payload.isNotEmpty() && payload != "{}") {
                val json = JSONObject(payload)
                val dateStr = json.optString("date", "")
                if (dateStr.isNotEmpty()) {
                    val todayCal = Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, 0)
                        set(Calendar.MINUTE, 0)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }
                    val datePrefix = if (dateStr.length >= 10) dateStr.substring(0, 10) else dateStr
                    val parsedDate = try {
                        SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(datePrefix)
                    } catch (e: Exception) {
                        null
                    }
                    if (parsedDate != null && parsedDate.before(todayCal.time)) {
                        android.util.Log.w("AlarmReceiver", "⚠️ [ALARM IGNORED NATIVE] Section date is in the past: $dateStr")
                        return
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 1. Bangunkan sistem dan nyalakan layar dengan WakeLock
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "DailyApps:AlarmWakeLock"
        )
        wakeLock?.acquire(20000L) // Tahan wake lock selama 20 detik

        // 2. Mulai getaran alarm di ponsel Android
        MainActivity.startAlarmVibration(context)

        // 3. Siapkan Intent untuk membuka aplikasi langsung ke pop-up dialog alarm
        val activityIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra("ALARM_TRIGGER_PAYLOAD", payload)
            putExtra("IS_ALARM_DIRECT_LAUNCH", true)
            putExtra("notificationId", notificationId)
        }

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            activityIntent,
            pendingFlags
        )

        // 4. Siapkan Intent Dismiss Alarm dari Action Notifikasi
        val dismissIntent = Intent(context, AlarmActionReceiver::class.java).apply {
            action = "com.example.daily_apps.ACTION_DISMISS_ALARM"
            putExtra("notificationId", notificationId)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 1,
            dismissIntent,
            pendingFlags
        )

        // 5. Tampilkan Full Screen Intent Notification (Jaminan Android untuk alarm saat layar mati/terkunci atau app di background)
        val channelId = "todo_reminder_alarm_channel_v3"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Pengingat Alarm To-Do List",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alarm pengingat tugas to-do list dengan pop up layar penuh dan suara dering."
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                setBypassDnd(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .setAutoCancel(true)
            .setOngoing(true)
            .addAction(R.mipmap.launcher_icon, "Buka", fullScreenPendingIntent)
            .addAction(R.mipmap.launcher_icon, "Matikan Alarm", dismissPendingIntent)
            .build()

        try {
            notificationManager.notify(notificationId, notification)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 6. Coba luncurkan Activity langsung
        try {
            context.startActivity(activityIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 7. Teruskan sinyal ke MainActivity jika instance sedang berjalan
        MainActivity.sendAlarmEventToFlutter(payload)
    }
}

