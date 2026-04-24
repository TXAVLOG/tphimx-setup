package com.tphimx.tphimx_setup

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.tphimx.tphimx_setup.R
import java.util.Locale
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.pow

class SpeedNotificationService : Service() {

    companion object {
        private const val CHANNEL_ID = "speed_service_channel_high"
        private const val NOTIFICATION_ID = 101
        private const val ACTION_RESTART_SERVICE = "com.tphimx.speed_service.RESTART"
    }

    private val handler = Handler(Looper.getMainLooper())
    
    private var lastRxBytes: Long = 0
    private var lastTxBytes: Long = 0
    private var lastUpdateTime: Long = 0
    
    // Config
    private var speedUnit: String = "Auto"
    
    // Translations
    private var txtTitle = "Tốc độ mạng"
    private var txtInit = "Đang khởi tạo..."
    private var txtNetwork = "Mạng"
    private var txtOffline = "Ngoại tuyến"
    private var txtWiFi = "WiFi"
    private var txtMobile = "Dữ liệu di động"
    private var txtEthernet = "Ethernet"
    private var txtUnknown = "Không rõ"

    private val updateRunnable = object : Runnable {
        override fun run() {
            updateNotification()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        lastRxBytes = TrafficStats.getTotalRxBytes()
        lastTxBytes = TrafficStats.getTotalTxBytes()
        lastUpdateTime = System.currentTimeMillis()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Handle restart action
        if (intent?.action == ACTION_RESTART_SERVICE) {
            startForegroundService(Intent(this, SpeedNotificationService::class.java))
            return START_STICKY
        }

        // Read config
        speedUnit = intent?.getStringExtra("speedUnit") ?: "Auto"
        
        // Read translations
        intent?.let {
            txtTitle = it.getStringExtra("txtTitle") ?: txtTitle
            txtInit = it.getStringExtra("txtInit") ?: txtInit
            txtNetwork = it.getStringExtra("txtNetwork") ?: txtNetwork
            txtOffline = it.getStringExtra("txtOffline") ?: txtOffline
            txtWiFi = it.getStringExtra("txtWiFi") ?: txtWiFi
            txtMobile = it.getStringExtra("txtMobile") ?: txtMobile
            txtEthernet = it.getStringExtra("txtEthernet") ?: txtEthernet
            txtUnknown = it.getStringExtra("txtUnknown") ?: txtUnknown
        }
        
        val notification = buildNotification(txtTitle, txtInit)
        
        // Android 15 requires foregroundServiceType
        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        
        handler.removeCallbacks(updateRunnable)
        handler.post(updateRunnable)
        
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // When app is swiped away from recents, ensure service stays or restarts
        val restartServiceIntent = Intent(applicationContext, SpeedNotificationService::class.java)
        val restartServicePendingIntent = PendingIntent.getService(
            applicationContext, 1, restartServiceIntent, 
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmService = applicationContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmService.set(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + 1000,
            restartServicePendingIntent
        )
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        handler.removeCallbacks(updateRunnable)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun updateNotification() {
        val currentRxBytes = TrafficStats.getTotalRxBytes()
        val currentTxBytes = TrafficStats.getTotalTxBytes()
        val currentTime = System.currentTimeMillis()

        val timeDiff = (currentTime - lastUpdateTime) / 1000.0
        if (timeDiff <= 0) return

        val rxSpeed = (currentRxBytes - lastRxBytes) / timeDiff
        val txSpeed = (currentTxBytes - lastTxBytes) / timeDiff

        lastRxBytes = currentRxBytes
        lastTxBytes = currentTxBytes
        lastUpdateTime = currentTime

        val downSpeedStr = formatWithUnit(rxSpeed, speedUnit)
        val upSpeedStr = formatWithUnit(txSpeed, speedUnit)
        val networkInfo = getNetworkType()

        val contentTitle = "Down: $downSpeedStr  Up: $upSpeedStr"
        val contentText = "$txtNetwork: $networkInfo"

        val notification = buildNotification(contentTitle, contentText)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun formatWithUnit(bytesPerSec: Double, unit: String): String {
        val bitsPerSec = bytesPerSec * 8.0
        val mbps = bitsPerSec / 1000000.0

        return when (unit) {
            "Mbps", "Mb/s" -> String.format(Locale.US, "%.2f Mb/s", mbps)
            "Gbps", "Gb/s" -> String.format(Locale.US, "%.2f Gb/s", mbps / 1000.0)
            "B/s" -> String.format(Locale.US, "%.0f B/s", bytesPerSec)
            "KB/s" -> String.format(Locale.US, "%.2f KB/s", bytesPerSec / 1024.0)
            "MB/s" -> String.format(Locale.US, "%.2f MB/s", bytesPerSec / (1024.0 * 1024.0))
            "GB/s" -> String.format(Locale.US, "%.2f GB/s", bytesPerSec / (1024.0 * 1024.0 * 1024.0))
            "TB/s" -> String.format(Locale.US, "%.2f TB/s", bytesPerSec / (1024.0 * 1024.0 * 1024.0 * 1024.0))
            else -> { // Auto
                if (mbps >= 1000) String.format(Locale.US, "%.2f Gb/s", mbps / 1000.0)
                else String.format(Locale.US, "%.2f Mb/s", mbps)
            }
        }
    }

    private fun getNetworkType(): String {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivityManager.activeNetwork ?: return txtOffline
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return txtUnknown
        
        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> txtWiFi
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> txtMobile
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> txtEthernet
            else -> txtUnknown
        }
    }

    private fun buildNotification(title: String, text: String): Notification {
        // Intent to handle deletion (though ongoing=true usually prevents it)
        val deleteIntent = Intent(this, SpeedServiceRestarter::class.java).apply {
            action = ACTION_RESTART_SERVICE
        }
        val deletePendingIntent = PendingIntent.getBroadcast(
            this, 0, deleteIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_speed_notification)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true) // Ensures no sound/vibrate on update
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setDeleteIntent(deletePendingIntent)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                txtTitle,
                NotificationManager.IMPORTANCE_HIGH // High importance to stay at top
            ).apply {
                description = txtTitle
                setShowBadge(false)
                enableLights(false)
                enableVibration(false) // No vibration
                setSound(null, null) // No sound
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }
}

/**
 * BroadcastReceiver to restart the service if it's cleared or killed
 */
class SpeedServiceRestarter : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            val serviceIntent = Intent(context, SpeedNotificationService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }, 1000)
    }
}
