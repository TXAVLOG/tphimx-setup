package com.tphimx.tphimx_setup

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.tphimx.tphimx/dnd"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            when (call.method) {
                "setDND" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (notificationManager.isNotificationPolicyAccessGranted) {
                            if (enable) {
                                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                            } else {
                                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                            }
                            result.success(true)
                        } else {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                            startActivity(intent)
                            result.error("PERMISSION_DENIED", "Notification Policy Access not granted", null)
                        }
                    } else {
                        result.error("NOT_SUPPORTED", "DND toggle not supported on this version", null)
                    }
                }
                "checkPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(notificationManager.isNotificationPolicyAccessGranted)
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
