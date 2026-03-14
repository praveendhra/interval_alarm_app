package com.example.interval_alarm_app

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app_settings").setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    }
                    startActivity(intent)
                    result.success(null)
                }
                "ensureAlarmVolume" -> {
                    // Alarm volume is a separate stream from ringer — it can silently be at 0.
                    // Set it to at least 50% so alarms are audible.
                    val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val max = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                    val current = audio.getStreamVolume(AudioManager.STREAM_ALARM)
                    try {
                        if (current < max / 3) {
                            audio.setStreamVolume(
                                AudioManager.STREAM_ALARM,
                                max / 2,
                                AudioManager.FLAG_SHOW_UI  // briefly shows volume slider so user is aware
                            )
                        }
                        result.success(audio.getStreamVolume(AudioManager.STREAM_ALARM))
                    } catch (e: SecurityException) {
                        result.success(current)  // DND active, ignore
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
