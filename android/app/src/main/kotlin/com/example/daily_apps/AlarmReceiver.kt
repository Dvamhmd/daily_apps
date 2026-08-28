package com.example.daily_apps

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val payload = intent.getStringExtra("payload") ?: "{}"

        // 1. Bangunkan sistem dengan WakeLock
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "DailyApps:AlarmWakeLock"
        )
        wakeLock?.acquire(15000L) // Tahan wake lock selama 15 detik

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
        }

        // 4. Luncurkan Activity langsung tanpa memunculkan notifikasi sistem yang bersuara dobel
        try {
            context.startActivity(activityIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 5. Teruskan sinyal ke MainActivity jika instance sedang berjalan
        MainActivity.sendAlarmEventToFlutter(payload)
    }
}

