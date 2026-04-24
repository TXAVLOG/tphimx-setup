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
    private val CHANNEL_DND = "com.tphimx.tphimx/dnd"
    private val CHANNEL_SPEED = "com.tphimx/speed_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Existing DND Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_DND).setMethodCallHandler { call, result ->
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            when (call.method) {
                "setDND" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
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
                }
                "checkPermission" -> {
                    result.success(notificationManager.isNotificationPolicyAccessGranted)
                }
                else -> result.notImplemented()
            }
        }

        // New Speed Service Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SPEED).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSpeedService" -> {
                    val speedUnit = call.argument<String>("speedUnit") ?: "Auto"
                    val intent = Intent(this, SpeedNotificationService::class.java).apply {
                        putExtra("speedUnit", speedUnit)
                        putExtra("txtTitle", call.argument<String>("txtTitle"))
                        putExtra("txtInit", call.argument<String>("txtInit"))
                        putExtra("txtNetwork", call.argument<String>("txtNetwork"))
                        putExtra("txtOffline", call.argument<String>("txtOffline"))
                        putExtra("txtWiFi", call.argument<String>("txtWiFi"))
                        putExtra("txtMobile", call.argument<String>("txtMobile"))
                        putExtra("txtEthernet", call.argument<String>("txtEthernet"))
                        putExtra("txtUnknown", call.argument<String>("txtUnknown"))
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }


                "stopSpeedService" -> {
                    val intent = Intent(this, SpeedNotificationService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Settings Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tphimx/settings").setMethodCallHandler { call, result ->
            when (call.method) {
                "openCastSettings" -> {
                    try {
                        val intent = Intent("android.settings.CAST_SETTINGS")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent("android.settings.WIFI_DISPLAY_SETTINGS")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            val intent = Intent(android.provider.Settings.ACTION_DISPLAY_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}


