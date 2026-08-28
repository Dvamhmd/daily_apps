package com.example.daily_apps

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val notificationId = intent.getIntExtra("notificationId", 88888)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(notificationId)

        if (action == "com.example.daily_apps.ACTION_DISMISS_ALARM") {
            MainActivity.stopAlarmFromNative()
        }
    }
}
