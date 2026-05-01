package com.example.walkies

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.time.LocalDate
import java.time.ZoneId

class MainActivity : FlutterActivity() {
  private val CHANNEL = "com.example.walkies/app_locking"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "enableAppLocking" -> {
            openAccessibilitySettings()
            result.success(true)
          }
          "disableAppLocking" -> {
            result.success(true)
          }
          "updateLockedApps" -> {
            val packages = call.argument<List<*>>("packages") as? List<String> ?: emptyList()
            val packageSet = packages.toSet()
            AppBlockingAccessibilityService.setLockedApps(this, packageSet)
            result.success(true)
          }
          "syncStepGoalData" -> {
            val dailyGoal = call.argument<Int>("dailyGoal") ?: 7000
            val todaySteps = call.argument<Int>("todaySteps") ?: 0
            val timezone = call.argument<String>("timezone") ?: ZoneId.systemDefault().id
            val prefs = getSharedPreferences("step_prefs", Context.MODE_PRIVATE)
            
            // Get current date in the user's timezone
            val zoneId = ZoneId.of(timezone)
            val today = LocalDate.now(zoneId).toString() // Format: yyyy-MM-dd
            
            prefs.edit()
              .putInt("daily_goal", dailyGoal)
              .putInt("today_steps", todaySteps)
              .putString("last_step_check_date", today)
              .putString("user_timezone", timezone)
              .apply()
            result.success(true)
          }
          "isAppLockingEnabled" -> {
            val isEnabled = isAccessibilityServiceEnabled()
            result.success(isEnabled)
          }
          "openAccessibilitySettings" -> {
            openAccessibilitySettings()
            result.success(null)
          }
          "syncUserTimezone" -> {
            val timezone = call.argument<String>("timezone") ?: ZoneId.systemDefault().id
            val prefs = getSharedPreferences("step_prefs", Context.MODE_PRIVATE)
            prefs.edit().putString("user_timezone", timezone).apply()
            
            // Schedule midnight reset worker when timezone is synced
            MidnightResetWorker.scheduleMidnightReset(this)
            
            android.util.Log.i("MainActivity", "Timezone synced: $timezone. Midnight reset worker scheduled.")
            result.success(true)
          }
          else -> result.notImplemented()
        }
      }
  }

  private fun isAccessibilityServiceEnabled(): Boolean {
    val accessibilityManager = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
    val enabledServices = accessibilityManager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
    
    val iterator = enabledServices.iterator()
    while (iterator.hasNext()) {
      val service = iterator.next()
      if (service.id.contains("com.example.walkies") && service.id.contains("AppBlockingAccessibilityService")) {
        return true
      }
    }
    return false
  }

  private fun openAccessibilitySettings() {
    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
    startActivity(intent)
  }
}
