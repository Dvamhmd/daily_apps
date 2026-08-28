package com.example.daily_apps

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.AlarmManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.daily_apps/alarm_permissions"
        var instance: MainActivity? = null
        var methodChannel: MethodChannel? = null
        var pendingAlarmPayload: String? = null

        fun sendAlarmEventToFlutter(payload: String) {
            instance?.runOnUiThread {
                try {
                    methodChannel?.invokeMethod("onAlarmTriggered", payload)
                } catch (e: Exception) {
                    pendingAlarmPayload = payload
                }
            } ?: run {
                pendingAlarmPayload = payload
            }
        }

        fun stopAlarmFromNative() {
            instance?.runOnUiThread {
                try {
                    methodChannel?.invokeMethod("onAlarmDismissed", null)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        turnScreenOnAndShowOnLockScreen()

        val alarmPayload = intent?.getStringExtra("ALARM_TRIGGER_PAYLOAD")
        if (!alarmPayload.isNullOrEmpty()) {
            pendingAlarmPayload = alarmPayload
        }
    }

    override fun onResume() {
        super.onResume()
        instance = this
        turnScreenOnAndShowOnLockScreen()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        turnScreenOnAndShowOnLockScreen()

        val alarmPayload = intent.getStringExtra("ALARM_TRIGGER_PAYLOAD")
        if (!alarmPayload.isNullOrEmpty()) {
            sendAlarmEventToFlutter(alarmPayload)
        }
    }

    override fun onDestroy() {
        if (instance == this) {
            instance = null
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialAlarmPayload" -> {
                    val payload = pendingAlarmPayload
                    pendingAlarmPayload = null
                    result.success(payload)
                }
                "scheduleNativeAlarm" -> {
                    try {
                        val id = call.argument<Int>("id") ?: 0
                        val timeMillis = call.argument<Long>("timeMillis") ?: 0L
                        val payload = call.argument<String>("payload") ?: "{}"
                        val title = call.argument<String>("title") ?: "🚨 Tugasmu ada yang belum selesai Nih"
                        val body = call.argument<String>("body") ?: "Ada tugas to-do list yang belum selesai!"

                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val intent = Intent(this, AlarmReceiver::class.java).apply {
                            action = "com.example.daily_apps.ACTION_TRIGGER_ALARM"
                            putExtra("payload", payload)
                            putExtra("title", title)
                            putExtra("body", body)
                            putExtra("notificationId", id)
                        }

                        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }

                        val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            AlarmManagerCompat.setExactAndAllowWhileIdle(
                                alarmManager,
                                AlarmManager.RTC_WAKEUP,
                                timeMillis,
                                pendingIntent
                            )
                        } else {
                            alarmManager.setExact(
                                AlarmManager.RTC_WAKEUP,
                                timeMillis,
                                pendingIntent
                            )
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("ALARM_ERROR", e.message, null)
                    }
                }
                "cancelNativeAlarm" -> {
                    try {
                        val id = call.argument<Int>("id") ?: 0
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val intent = Intent(this, AlarmReceiver::class.java).apply {
                            action = "com.example.daily_apps.ACTION_TRIGGER_ALARM"
                        }
                        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }
                        val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)
                        alarmManager.cancel(pendingIntent)
                        pendingIntent.cancel()
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("CANCEL_ERROR", e.message, null)
                    }
                }
                "bringAppToForeground" -> {
                    try {
                        val intent = Intent(this, MainActivity::class.java).apply {
                            action = Intent.ACTION_MAIN
                            addCategory(Intent.CATEGORY_LAUNCHER)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                        }
                        startActivity(intent)
                        turnScreenOnAndShowOnLockScreen()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "canDrawOverlays" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "canUseFullScreenIntent" -> {
                    if (Build.VERSION.SDK_INT >= 34) {
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                        result.success(notificationManager?.canUseFullScreenIntent() ?: true)
                    } else {
                        result.success(true)
                    }
                }
                "openFullScreenIntentSettings" -> {
                    if (Build.VERSION.SDK_INT >= 34) {
                        try {
                            val intent = Intent(
                                "android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT",
                                Uri.parse("package:$packageName")
                            ).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "openOverlaySettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            ).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                Uri.parse("package:$packageName")
                            ).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")
                        ).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun turnScreenOnAndShowOnLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            keyguardManager?.requestDismissKeyguard(this, null)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )
    }
}
