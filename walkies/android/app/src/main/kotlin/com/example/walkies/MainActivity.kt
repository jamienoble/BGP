package com.example.walkies

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

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
            val dailyGoal = call.argument<Int>("dailyGoal") ?: StepStore.DEFAULT_DAILY_GOAL
            val todaySteps = call.argument<Int>("todaySteps") ?: 0
            val date = call.argument<String>("date") ?: StepStore.todayString()
            StepStore.setDailyGoal(this, dailyGoal)
            StepStore.recordFlutterSteps(this, todaySteps, date)
            result.success(true)
          }
          "getStepsRemaining" -> {
            val remaining = StepStore.getDailyGoal(this) - StepStore.getTodaySteps(this)
            result.success(maxOf(0, remaining))
          }
          "wasBlockedToday" -> {
            result.success(StepStore.wasBlockedToday(this))
          }
          "isAppLockingEnabled" -> {
            val isEnabled = isAccessibilityServiceEnabled()
            result.success(isEnabled)
          }
          "getInstalledApps" -> {
            // null = every launchable app; otherwise only these packages
            val only = call.argument<List<String>>("packages")?.toSet()
            Thread {
              val apps = try { loadLaunchableApps(only) } catch (e: Exception) { null }
              runOnUiThread {
                if (apps != null) result.success(apps)
                else result.error("APPS_FAILED", "Could not list installed apps", null)
              }
            }.start()
          }
          "openAccessibilitySettings" -> {
            openAccessibilitySettings()
            result.success(null)
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

  /** Apps that appear in the launcher, with a small PNG icon each. */
  private fun loadLaunchableApps(only: Set<String>?): List<Map<String, Any>> {
    val pm = packageManager
    val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
    val seen = HashSet<String>()
    val apps = ArrayList<Map<String, Any>>()
    for (info in pm.queryIntentActivities(launcherIntent, 0)) {
      val pkg = info.activityInfo.packageName
      if (pkg == packageName || !seen.add(pkg)) continue
      if (only != null && pkg !in only) continue
      apps.add(
        mapOf(
          "packageName" to pkg,
          "appName" to info.loadLabel(pm).toString(),
          "icon" to drawableToPng(info.loadIcon(pm)),
        ),
      )
    }
    return apps.sortedBy { (it["appName"] as String).lowercase() }
  }

  private fun drawableToPng(drawable: Drawable): ByteArray {
    val size = 96
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    drawable.setBounds(0, 0, size, size)
    drawable.draw(Canvas(bitmap))
    val out = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
    return out.toByteArray()
  }

  private fun openAccessibilitySettings() {
    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
    startActivity(intent)
  }
}
