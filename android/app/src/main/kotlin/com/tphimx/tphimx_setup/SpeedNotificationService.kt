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
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.graphics.drawable.IconCompat
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
        private const val UPDATE_INTERVAL_MS = 1500L
        private const val SAVE_INTERVAL_MS = 10_000L
    }

    private val handler = Handler(Looper.getMainLooper())
    
    private var lastRxBytes: Long = 0
    private var lastTxBytes: Long = 0
    private var lastUpdateTime: Long = 0
    
    // Daily Usage
    private var totalDailyRx: Long = 0
    private var totalDailyTx: Long = 0
    private var lastResetDate: String = ""
    private var lastUsageSaveTime: Long = 0
    private var lastNotificationText: String = ""
    private var cachedIconKey: String = ""
    private var cachedIcon: IconCompat? = null
    
    // Config
    private var speedUnit: String = "Auto"
    private var fontFamily: String = "Outfit"
    
    // Translations
    private var txtTitle = "Tốc độ mạng"
    private var txtInit = "Đang khởi tạo..."
    private var txtNetwork = "Mạng"
    private var txtOffline = "Ngoại tuyến"
    private var txtWiFi = "WiFi"
    private var txtMobile = "Dữ liệu di động"
    private var txtEthernet = "Ethernet"
    private var txtUnknown = "Không rõ"
    private var txtUsage = "Sử dụng"
    private var txtTotal = "Tổng"

    private val updateRunnable = object : Runnable {
        override fun run() {
            updateNotification()
            handler.postDelayed(this, UPDATE_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        loadUsageData()
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

        // Read config and persist to prevent loss on background restarts
        val prefs = getSharedPreferences("speed_service_prefs", Context.MODE_PRIVATE)
        if (intent?.hasExtra("speedUnit") == true) {
            speedUnit = intent.getStringExtra("speedUnit") ?: "Auto"
            prefs.edit().putString("speedUnit", speedUnit).apply()
        } else {
            speedUnit = prefs.getString("speedUnit", "Auto") ?: "Auto"
        }

        if (intent?.hasExtra("fontFamily") == true) {
            fontFamily = intent.getStringExtra("fontFamily") ?: "Outfit"
            prefs.edit().putString("fontFamily", fontFamily).apply()
        } else {
            fontFamily = prefs.getString("fontFamily", "Outfit") ?: "Outfit"
        }
        
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
            txtUsage = it.getStringExtra("txtUsage") ?: "Dùng"
            txtTotal = it.getStringExtra("txtTotal") ?: "Tổng"
        }

        if (intent?.action == "UPDATE_SPEED_DATA") {
            val down = intent.getStringExtra("downSpeed") ?: "0 KB/s"
            val up = intent.getStringExtra("upSpeed") ?: "0 KB/s"
            
            postNotification(down, up, force = true)
            return START_STICKY
        }
        
        val notification = buildNotification(txtTitle, txtInit)
        
        // Android 15 requires foregroundServiceType
        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        
        handler.removeCallbacks(updateRunnable)
        handler.post(updateRunnable)
        
        return START_STICKY
    }

    private fun loadUsageData() {
        val prefs = getSharedPreferences("speed_service_prefs", Context.MODE_PRIVATE)
        totalDailyRx = prefs.getLong("totalDailyRx", 0)
        totalDailyTx = prefs.getLong("totalDailyTx", 0)
        lastResetDate = prefs.getString("lastResetDate", "") ?: ""
        
        checkResetNeeded()
    }

    private fun saveUsageData() {
        val prefs = getSharedPreferences("speed_service_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putLong("totalDailyRx", totalDailyRx)
            putLong("totalDailyTx", totalDailyTx)
            putString("lastResetDate", lastResetDate)
            apply()
        }
    }

    private fun checkResetNeeded() {
        val currentDate = java.text.SimpleDateFormat("yyyy-MM-dd", Locale.US).format(java.util.Date())
        if (lastResetDate != currentDate) {
            totalDailyRx = 0
            totalDailyTx = 0
            lastResetDate = currentDate
            saveUsageData()
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // When app is swiped away from recents, ensure service stays or restarts
        val restartServiceIntent = Intent(applicationContext, SpeedServiceRestarter::class.java)
        val restartServicePendingIntent = PendingIntent.getBroadcast(
            applicationContext, 1, restartServiceIntent, 
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmService = applicationContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            alarmService.set(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 1000,
                restartServicePendingIntent
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        handler.removeCallbacks(updateRunnable)
        saveUsageData()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun updateNotification() {
        checkResetNeeded()
        
        val currentRxBytes = TrafficStats.getTotalRxBytes()
        val currentTxBytes = TrafficStats.getTotalTxBytes()
        val currentTime = System.currentTimeMillis()

        val timeDiff = (currentTime - lastUpdateTime) / 1000.0
        if (timeDiff <= 0) return

        val diffRx = if (lastRxBytes > 0) currentRxBytes - lastRxBytes else 0
        val diffTx = if (lastTxBytes > 0) currentTxBytes - lastTxBytes else 0
        
        val rxSpeed = diffRx / timeDiff
        val txSpeed = diffTx / timeDiff

        // Accumulate daily usage
        if (diffRx > 0) totalDailyRx += diffRx
        if (diffTx > 0) totalDailyTx += diffTx

        lastRxBytes = currentRxBytes
        lastTxBytes = currentTxBytes
        lastUpdateTime = currentTime

        val downSpeedStr = formatWithUnit(rxSpeed, speedUnit)
        val upSpeedStr = formatWithUnit(txSpeed, speedUnit)
        postNotification(downSpeedStr, upSpeedStr)
        
        if (currentTime - lastUsageSaveTime >= SAVE_INTERVAL_MS) {
            saveUsageData()
            lastUsageSaveTime = currentTime
        }
    }

    private fun formatWithUnit(bytes: Double, unit: String, isSpeed: Boolean = true): String {
        val suffix = if (isSpeed) "/s" else ""
        
        // Mb/s and Gb/s removed - use MB/s and GB/s only
        val KB = 1024.0
        val MB = KB * KB
        val GB = MB * KB
        val TB = GB * KB
        
        return when (unit) {
            "B/s", "B" -> String.format(Locale.US, "%.0f B%s", bytes, suffix)
            "KB/s", "KB" -> String.format(Locale.US, "%.2f KB%s", bytes / KB, suffix)
            "MB/s", "MB" -> String.format(Locale.US, "%.2f MB%s", bytes / MB, suffix)
            "GB/s", "GB" -> String.format(Locale.US, "%.2f GB%s", bytes / GB, suffix)
            "TB/s", "TB" -> String.format(Locale.US, "%.2f TB%s", bytes / TB, suffix)
            else -> { // Auto
                when {
                    bytes < MB -> String.format(Locale.US, "%.2f KB%s", bytes / KB, suffix)
                    bytes < GB -> String.format(Locale.US, "%.2f MB%s", bytes / MB, suffix)
                    bytes < TB -> String.format(Locale.US, "%.2f GB%s", bytes / GB, suffix)
                    else -> String.format(Locale.US, "%.2f TB%s", bytes / TB, suffix)
                }
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

    private fun getSignalStrength(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return "━━━━"
        }
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivityManager.activeNetwork ?: return "━━━━"
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return "━━━━"
        
        // Get signal strength from NetworkCapabilities (API 29+)
        val signalStrength = capabilities.signalStrength // dBm value, negative
        
        // Convert to bars (0-4)
        val bars = when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> {
                when {
                    signalStrength >= -50 -> 4  // Excellent
                    signalStrength >= -60 -> 3  // Good
                    signalStrength >= -70 -> 2  // Fair
                    signalStrength >= -80 -> 1  // Weak
                    else -> 0                    // Very weak
                }
            }
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> {
                when {
                    signalStrength >= -85 -> 4
                    signalStrength >= -95 -> 3
                    signalStrength >= -105 -> 2
                    signalStrength >= -115 -> 1
                    else -> 0
                }
            }
            else -> 4 // Ethernet/other = full
        }
        
        val barIcons = listOf("▁", "▂", "▄", "▆", "█")
        return barIcons.take(bars + 1).joinToString("")
    }

    private fun buildNotification(downSpeedStr: String, upSpeedStr: String): Notification {
        // Intent to open app
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Custom RemoteViews
        val remoteViews = RemoteViews(packageName, R.layout.notification_speed).apply {
            setTextViewText(R.id.tv_title, txtTitle)
            setTextViewText(R.id.tv_network, "$txtNetwork: ${getNetworkType()} • ${getSignalStrength()}")
            setTextViewText(R.id.tv_down, downSpeedStr)
            setTextViewText(R.id.tv_up, upSpeedStr)
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(getSpeedIcon(downSpeedStr))
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews) // Same for expanded
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setColor(0xFF737DFD.toInt())
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE) // AS REQUESTED
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_DEFERRED)
            .setShowWhen(false)

        return builder.build()
    }

    private fun postNotification(downSpeedStr: String, upSpeedStr: String, force: Boolean = false) {
        val textKey = "$downSpeedStr|$upSpeedStr|${getNetworkType()}"
        if (!force && textKey == lastNotificationText) return

        lastNotificationText = textKey
        val notification = buildNotification(downSpeedStr, upSpeedStr)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun getSpeedIcon(speedText: String): IconCompat {
        val cleanText = speedText.trim()
        val cacheKey = "$cleanText|$fontFamily"
        val currentIcon = cachedIcon
        if (cacheKey == cachedIconKey && currentIcon != null) return currentIcon

        val icon = createSpeedIcon(cleanText)
        cachedIconKey = cacheKey
        cachedIcon = icon
        return icon
    }

    private fun resolveTypeface(family: String): Typeface {
        return try {
            val systemName = when (family.lowercase(Locale.US)) {
                "roboto" -> "sans-serif-black"
                "inter" -> "sans-serif-black"
                "outfit" -> "sans-serif-black"
                "poppins" -> "sans-serif-black"
                "montserrat" -> "sans-serif-black"
                "lato" -> "sans-serif-medium"
                "open sans" -> "sans-serif-medium"
                "manrope" -> "sans-serif-black"
                "rubik" -> "sans-serif-black"
                "bebas neue" -> "sans-serif-condensed"
                else -> "sans-serif-black"
            }
            Typeface.create(systemName, Typeface.BOLD)
        } catch (e: Exception) {
            Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
    }

    private fun createSpeedIcon(speedText: String): IconCompat {
        val parts = speedText.split(" ")
        var valueStr = "0"
        var unitStr = "KB/s" // Default
        if (parts.size >= 2) {
            valueStr = parts[0]
            val rawUnit = parts[1].replace("/s", "").uppercase()
            val unitPrefix = if (rawUnit.length <= 2) rawUnit else rawUnit.take(2)
            unitStr = "$unitPrefix/s"
        }
        
        val valueFloat = valueStr.toFloatOrNull() ?: 0f
        val displayValue = if (valueFloat >= 100 || valueFloat == 0f || valueFloat % 1 == 0f) {
            valueFloat.toInt().toString()
        } else {
            String.format(Locale.US, "%.1f", valueFloat)
        }

        val size = 128
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // The background of the icon should be transparent
        // Android status bar icons use the ALPHA channel to colorize
        val paintValue = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = if (displayValue.length > 3) 54f else 72f
            typeface = resolveTypeface(fontFamily)
            textAlign = Paint.Align.CENTER
        }

        val paintUnit = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = if (unitStr.length > 3) 28f else 34f
            typeface = resolveTypeface(fontFamily)
            textAlign = Paint.Align.CENTER
        }

        // Draw value and unit
        canvas.drawText(displayValue, size / 2f, size * 0.48f, paintValue)
        canvas.drawText(unitStr, size / 2f, size * 0.86f, paintUnit)

        return IconCompat.createWithBitmap(bitmap)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return

            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                txtTitle,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Hiển thị tốc độ mạng thời gian thực"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(serviceChannel)
        }
    }
}

class SpeedServiceRestarter : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val serviceIntent = Intent(context, SpeedNotificationService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            android.util.Log.e("SpeedService", "Failed to start SpeedNotificationService from background: ${e.message}")
        }
    }
}
