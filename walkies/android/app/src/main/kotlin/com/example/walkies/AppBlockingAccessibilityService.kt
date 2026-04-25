package com.example.walkies

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast
import java.util.concurrent.ConcurrentHashMap

class AppBlockingAccessibilityService : AccessibilityService() {
    companion object {
        const val PREFS_NAME = "app_locking_prefs"
        const val LOCKED_APPS_KEY = "locked_apps"
        private const val BLOCK_COOLDOWN_MS = 3000L

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
    private val lastBlockTime = ConcurrentHashMap<String, Long>()
    private var lastToastTime = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName == "com.example.walkies") return
        val now = System.currentTimeMillis()
        val lastBlock = lastBlockTime[packageName] ?: 0
        if (now - lastBlock < BLOCK_COOLDOWN_MS) return
        val lockedApps = getLockedApps(this)
        if (!lockedApps.contains(packageName)) return
        if (hasUserMetStepGoal()) {
            removeAppLock(packageName)
            return
        }
        lastBlockTime[packageName] = now
        mainHandler.post {
            try {
                performGlobalAction(GLOBAL_ACTION_HOME)
                mainHandler.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 100)
                if (now - lastToastTime > 5000) {
                    lastToastTime = now
                    val appLabel = getAppLabel(packageName)
                    showToastLong("$appLabel is locked! Walk ${getStepsRemaining()} more steps to unlock.")
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
}