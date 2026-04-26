package com.example.walkies

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast

class AppBlockingAccessibilityService : AccessibilityService() {
    companion object {
        const val PREFS_NAME = "app_locking_prefs"
        const val LOCKED_APPS_KEY = "locked_apps"
        private const val BLOCKED_APPS_CHANNEL_ID = "walkies_blocked_apps"
        private const val BLOCKED_APPS_CHANNEL_NAME = "Walkies App Blocking"

        /**
         * Retrieve the set of locked app package names from SharedPreferences
         */
        fun getLockedApps(context: Context): Set<String> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val appsList = prefs.getString(LOCKED_APPS_KEY, "") ?: ""
            return if (appsList.isEmpty()) emptySet() else appsList.split(",").toSet()
        }

        /**
         * Save the set of locked app package names to SharedPreferences
         */
        fun setLockedApps(context: Context, packages: Set<String>) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val appsList = packages.joinToString(",")
            prefs.edit().putString(LOCKED_APPS_KEY, appsList).apply()
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastToastTime = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName == "com.example.walkies") return
        val lockedApps = getLockedApps(this)
        if (!lockedApps.contains(packageName)) return
        if (hasUserMetStepGoal()) {
            removeAppLock(packageName)
            return
        }
        mainHandler.post {
            try {
                performGlobalAction(GLOBAL_ACTION_HOME)
                mainHandler.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 100)
                val appLabel = getAppLabel(packageName)
                val stepsRemaining = getStepsRemaining()
                showBlockedAppNotification(appLabel, stepsRemaining)
                val now = System.currentTimeMillis()
                if (now - lastToastTime > 5000) {
                    lastToastTime = now
                    showToastLong("$appLabel is locked! Walk $stepsRemaining more steps to unlock.")
                }
                android.util.Log.d("AppBlocker", "Blocked: $packageName")
            } catch (e: Exception) {
                android.util.Log.e("AppBlocker", "Error: $e")
            }
        }
    }

    override fun onInterrupt() {
        android.util.Log.w("AppBlocker", "Interrupted")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        ensureNotificationChannel()
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or AccessibilityEvent.TYPE_WINDOWS_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
        }
        serviceInfo = info
        android.util.Log.i("AppBlocker", "Service Started")
        showToastLong("Walkies App Locker Active")
    }

    private fun hasUserMetStepGoal(): Boolean {
        return try {
            val prefs = getSharedPreferences("step_prefs", Context.MODE_PRIVATE)
            val currentSteps = prefs.getInt("today_steps", 0)
            val dailyGoal = prefs.getInt("daily_goal", 7000)
            currentSteps >= dailyGoal
        } catch (e: Exception) { false }
    }

    private fun getStepsRemaining(): Int {
        return try {
            val prefs = getSharedPreferences("step_prefs", Context.MODE_PRIVATE)
            val currentSteps = prefs.getInt("today_steps", 0)
            val dailyGoal = prefs.getInt("daily_goal", 7000)
            maxOf(0, dailyGoal - currentSteps)
        } catch (e: Exception) { 7000 }
    }

    private fun removeAppLock(packageName: String) {
        try {
            val lockedApps = getLockedApps(this).toMutableSet()
            if (lockedApps.remove(packageName)) {
                setLockedApps(this, lockedApps)
            }
        } catch (e: Exception) {}
    }

    private fun getAppLabel(packageName: String): String {
        return try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (e: Exception) { packageName }
    }

    private fun showToastLong(message: String) {
        try {
            Handler(Looper.getMainLooper()).post {
                Toast.makeText(this, message, Toast.LENGTH_LONG).show()
            }
        } catch (e: Exception) {}
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(BLOCKED_APPS_CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            BLOCKED_APPS_CHANNEL_ID,
            BLOCKED_APPS_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Shows when a locked app is force-closed by Walkies"
        }
        manager.createNotificationChannel(channel)
    }

    private fun showBlockedAppNotification(appLabel: String, stepsRemaining: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permissionState = ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.POST_NOTIFICATIONS,
            )
            if (permissionState != PackageManager.PERMISSION_GRANTED) {
                return
            }
        }

        val notification = NotificationCompat.Builder(this, BLOCKED_APPS_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("$appLabel was closed")
            .setContentText("Walk $stepsRemaining more steps to unlock.")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("$appLabel was closed by Walkies. Walk $stepsRemaining more steps to unlock your apps."),
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
    }
}