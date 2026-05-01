# Quick Reference: Timezone-Aware App Lock Fix

## The Problem (What Was Broken)
Apps stayed unlocked the next day even after goals weren't met because:
- Day checks used device local time, not user's timezone
- Resets only happened when app intercepted window events
- No background process ensured midnight resets

## The Solution (What Was Fixed)

### 1️⃣ Timezone-Aware Date Comparison
**File:** `AppBlockingAccessibilityService.kt`  
**What Changed:**
```kotlin
// BEFORE: Uses device local time
val today = SimpleDateFormat("yyyy-MM-dd").format(Date())

// AFTER: Uses user's timezone
val zoneId = ZoneId.of(prefs.getString("user_timezone", ...))
val today = LocalDate.now(zoneId).toString()
```

### 2️⃣ Background Midnight Resets
**File:** `MidnightResetWorker.kt` (NEW)  
**What Added:**
- WorkManager schedules daily checks at ~midnight
- Runs even when app is closed
- Automatically resets step counter on day boundary

### 3️⃣ Timezone Synchronization
**Files:** `MainActivity.kt`, `app_locker_service.dart`, `main.dart`  
**What Added:**
- `syncUserTimezone()` method passes timezone from app to native
- Called at startup, on screen resume, and when timezone changes
- Timezone stored in SharedPreferences for accessibility service to read

### 4️⃣ Forced Day Boundary Checks
**File:** `app_lock_settings_screen.dart`  
**What Added:**
- Forces timezone sync and day reset checks when screen resumes
- Catches any midnight resets that happened while app was closed

## File-by-File Summary

| File | Type | Change | Impact |
|------|------|--------|--------|
| `AppBlockingAccessibilityService.kt` | Kotlin | Timezone-aware date logic | ✅ Consistent day detection |
| `MidnightResetWorker.kt` | Kotlin (NEW) | Background daily reset | ✅ Resets work when app closed |
| `MainActivity.kt` | Kotlin | Timezone sync + scheduling | ✅ Timezone stored & worker started |
| `build.gradle.kts` | Build | WorkManager dependency | ✅ Enables background jobs |
| `app_locker_service.dart` | Dart | Timezone sync methods | ✅ Communicates with native |
| `app_lock_settings_screen.dart` | Dart | Timezone on lifecycle | ✅ Syncs on resume |
| `main.dart` | Dart | Timezone on startup | ✅ Initial setup |

## How It Works (End-to-End)

```
1. APP STARTS
   ├─ main.dart calculates timezone (UTC+/-X format)
   ├─ Calls syncUserTimezone() 
   └─ MidnightResetWorker.scheduleMidnightReset() is called

2. TIMEZONE IS STORED
   ├─ MainActivity receives timezone
   ├─ Saves to SharedPreferences ("user_timezone")
   └─ WorkManager scheduled for daily 1-day repeat

3. EVERY MIDNIGHT (AppLifecycle doesn't matter)
   ├─ MidnightResetWorker.doWork() runs
   ├─ Reads timezone from SharedPreferences
   ├─ Calculates "today" in user's timezone
   ├─ Compares with "last_step_check_date"
   └─ If different: reset step counter ✓

4. USER OPENS LOCKED APP
   ├─ AccessibilityService intercepts
   ├─ Calls checkAndResetIfNewDay()
   ├─ Uses LocalDate.now(ZoneId) for current date
   ├─ Checks if goal met in user's timezone
   └─ Locks/allows app launch ✓

5. APP SCREEN RESUMES
   ├─ app_lock_settings_screen calls _loadData()
   ├─ Syncs timezone again
   ├─ Forces refresh of locked apps
   └─ Catches any missed day resets ✓
```

## Key Technical Details

### Timezone Format
- Uses UTC offset: `"UTC+05:30"`, `"UTC-08:00"`, `"UTC+00:00"`
- Calculated from `DateTime.now().timeZoneOffset`
- Stored in SharedPreferences as `"user_timezone"`

### Date Format
- Uses `"yyyy-MM-dd"` format (e.g., `"2026-05-01"`)
- Consistent across Kotlin and Dart
- Stored in SharedPreferences as `"last_step_check_date"`

### Timezone Sync Triggers
1. **App Startup** - `main.dart`
2. **App Foreground** - `app_lock_settings_screen.dart` on resume
3. **Manual Refresh** - User pulls to refresh (calls `_loadData()`)

### WorkManager Behavior
- Periodic: Runs once daily
- Inexact: May execute within ~15-30 min window after scheduled time
- Persists: Continues even after device restart
- Respects: Doze mode and battery optimization

## Testing Quick Commands

```bash
# View timezone in prefs
adb shell run-as com.example.walkies cat shared_prefs/step_prefs.xml | grep user_timezone

# Check worker status
adb shell dumpsys jobscheduler

# View accessibility logs
adb logcat | grep -E "AppBlocker|MidnightReset"

# Simulate midnight (advance system time)
adb shell date '+%m%d%H%M%Y.%S' -s '050100010126.00'  # May 1, 00:01, 2026
```

## Expected Behavior (Post-Fix)

### ✅ Correct Behavior
1. User closes app at 11:59 PM after meeting goal (apps unlocked)
2. User reopens app at 12:01 AM next day
3. **Apps are locked again** ← This is the fix!
4. Goal must be re-met to unlock on new day

### ✅ Timezone Handling
1. User is in UTC+05:30
2. Midnight reset happens at actual midnight (00:00) in UTC+05:30
3. Not dependent on device local timezone or Supabase server timezone

### ✅ Background Operation
1. App closed at 11:50 PM
2. Device might be off/locked during actual midnight
3. MidnightResetWorker still fires at ~midnight
4. Next app open detects fresh day → apps locked ✓

## Rollback Plan (If Needed)

If issues arise, revert these files:
1. `AppBlockingAccessibilityService.kt` - Remove `LocalDate`/`ZoneId` logic
2. `MidnightResetWorker.kt` - Delete file
3. `MainActivity.kt` - Remove timezone sync method, remove scheduling call
4. `build.gradle.kts` - Remove WorkManager dependency
5. Dart files - Remove timezone parameters from method calls

## Future Enhancements (Optional)

1. **Store Timezone in Supabase** - Track user's timezone in DB for multi-device consistency
2. **Named Timezones** - Use `"America/New_York"` format instead of UTC offset
3. **Recurring Schedules** - Use user-defined "weekly reset" schedules
4. **Notifications** - Alert user at midnight if goal not met
5. **Timezone Change Detection** - Automatically detect when user travels to different timezone
