package com.example.walkies

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Native record of today's steps and goal, read by the accessibility service.
 *
 * Two sources feed it:
 *  - the Flutter app, via [recordFlutterSteps], whenever it is running
 *  - the step counter sensor, via [recordSensorReading], which the
 *    accessibility service listens to so steps count even when Walkies is closed
 *
 * Every value is stored with the date it belongs to, so a count from
 * yesterday is never mistaken for today's.
 */
object StepStore {
    const val PREFS_NAME = "step_prefs"
    const val DEFAULT_DAILY_GOAL = 7000

    private const val KEY_DAILY_GOAL = "daily_goal"
    private const val KEY_FLUTTER_STEPS = "today_steps"
    private const val KEY_FLUTTER_DATE = "today_steps_date"
    private const val KEY_SENSOR_DATE = "sensor_date"
    private const val KEY_SENSOR_BASELINE = "sensor_baseline"
    private const val KEY_SENSOR_LAST_RAW = "sensor_last_raw"
    private const val KEY_SENSOR_CARRIED = "sensor_carried"
    private const val KEY_BLOCKED_DATE = "blocked_before_goal_date"

    fun todayString(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getDailyGoal(context: Context): Int =
        prefs(context).getInt(KEY_DAILY_GOAL, DEFAULT_DAILY_GOAL)

    fun setDailyGoal(context: Context, goal: Int) {
        prefs(context).edit().putInt(KEY_DAILY_GOAL, goal).apply()
    }

    /**
     * Record the step count the Flutter app computed for [date].
     * Within a day the count only goes up, so a stale lower value
     * (e.g. from the cloud) cannot re-lock apps.
     */
    fun recordFlutterSteps(context: Context, steps: Int, date: String) {
        val p = prefs(context)
        val storedDate = p.getString(KEY_FLUTTER_DATE, "")
        val stored = if (storedDate == date) p.getInt(KEY_FLUTTER_STEPS, 0) else 0
        p.edit()
            .putString(KEY_FLUTTER_DATE, date)
            .putInt(KEY_FLUTTER_STEPS, maxOf(stored, steps))
            .apply()
    }

    /**
     * Record a raw reading from the step counter sensor (steps since boot).
     * Handles the start of a new day and device reboots.
     */
    fun recordSensorReading(context: Context, raw: Int) {
        val p = prefs(context)
        val today = todayString()
        var baseline = p.getInt(KEY_SENSOR_BASELINE, raw)
        var lastRaw = p.getInt(KEY_SENSOR_LAST_RAW, raw)
        var carried = p.getInt(KEY_SENSOR_CARRIED, 0)

        if (p.getString(KEY_SENSOR_DATE, "") != today) {
            baseline = raw
            carried = 0
        } else if (raw < lastRaw || raw < baseline) {
            // Counter restarted (reboot): keep the steps already counted today
            carried += maxOf(0, lastRaw - baseline)
            baseline = raw
        }
        lastRaw = raw

        p.edit()
            .putString(KEY_SENSOR_DATE, today)
            .putInt(KEY_SENSOR_BASELINE, baseline)
            .putInt(KEY_SENSOR_LAST_RAW, lastRaw)
            .putInt(KEY_SENSOR_CARRIED, carried)
            .apply()
    }

    /** Record that a locked app was blocked today (goal not yet met). */
    fun recordBlockedAttempt(context: Context) {
        prefs(context).edit().putString(KEY_BLOCKED_DATE, todayString()).apply()
    }

    fun wasBlockedToday(context: Context): Boolean =
        prefs(context).getString(KEY_BLOCKED_DATE, "") == todayString()

    /** Best known step count for today from either source. */
    fun getTodaySteps(context: Context): Int {
        val p = prefs(context)
        val today = todayString()
        val flutterSteps =
            if (p.getString(KEY_FLUTTER_DATE, "") == today) p.getInt(KEY_FLUTTER_STEPS, 0) else 0
        val sensorSteps = if (p.getString(KEY_SENSOR_DATE, "") == today) {
            p.getInt(KEY_SENSOR_CARRIED, 0) +
                maxOf(0, p.getInt(KEY_SENSOR_LAST_RAW, 0) - p.getInt(KEY_SENSOR_BASELINE, 0))
        } else 0
        return maxOf(flutterSteps, sensorSteps)
    }
}
