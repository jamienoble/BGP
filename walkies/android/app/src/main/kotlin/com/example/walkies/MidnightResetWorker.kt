package com.example.walkies

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.time.LocalDate
import java.time.ZoneId
import java.util.concurrent.TimeUnit

/**
 * Periodic worker that ensures app locks are reset at midnight in the user's timezone.
 * Runs daily and checks if a new day has occurred.
 */
class MidnightResetWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        return try {
            val prefs = applicationContext.getSharedPreferences("step_prefs", Context.MODE_PRIVATE)
            
            // Get timezone from prefs (set by Flutter app) or use system timezone
            val timezoneId = prefs.getString("user_timezone", ZoneId.systemDefault().id) ?: ZoneId.systemDefault().id
            val zoneId = ZoneId.of(timezoneId)
            
            // Get today's date in the user's timezone
            val today = LocalDate.now(zoneId).toString() // Format: yyyy-MM-dd
            val lastCheckDate = prefs.getString("last_step_check_date", "")
            
            if (lastCheckDate != today) {
                // New day detected, reset step counter and unlock all apps for the new day
                prefs.edit()
                    .putInt("today_steps", 0)
                    .putString("last_step_check_date", today)
                    .putBoolean("blocked_app_opened_before_goal", false)
                    .apply()
                
                android.util.Log.i(
                    "MidnightReset",
                    "Midnight reset executed (TZ: $timezoneId). Today: $today, Last: $lastCheckDate"
                )
            }
            
            Result.success()
        } catch (e: Exception) {
            android.util.Log.e("MidnightReset", "Error during reset: ${e.message}")
            Result.retry()
        }
    }

    companion object {
        private const val WORK_TAG = "midnight_reset"

        /**
         * Schedule a periodic worker to run daily at approximately midnight.
         * The exact time depends on the device and WorkManager's scheduling.
         */
        fun scheduleMidnightReset(context: Context) {
            val resetWork = PeriodicWorkRequestBuilder<MidnightResetWorker>(
                1, // repeatInterval
                TimeUnit.DAYS // repeatIntervalTimeUnit
            )
                .addTag(WORK_TAG)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_TAG,
                androidx.work.ExistingPeriodicWorkPolicy.KEEP, // Keep existing if already scheduled
                resetWork
            )

            android.util.Log.i("MidnightReset", "Midnight reset worker scheduled")
        }

        /**
         * Cancel the midnight reset worker
         */
        fun cancelMidnightReset(context: Context) {
            WorkManager.getInstance(context).cancelAllWorkByTag(WORK_TAG)
            android.util.Log.i("MidnightReset", "Midnight reset worker cancelled")
        }
    }
}
