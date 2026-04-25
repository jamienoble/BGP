# Walkies App - Complete Fix Guide

## ✅ Issues Fixed

### Issue 1: Steps Recording as 0
**Root Cause**: Missing runtime permission requests for step tracking

**Solution Implemented**:
- Added `permission_handler` package to handle runtime permissions
- Created `PermissionsService` to request `ACTIVITY_RECOGNITION` and `BODY_SENSORS` permissions
- Updated `StepTrackingService` to request permissions on initialization
- Added `BODY_SENSORS` permission to AndroidManifest.xml
- Dashboard now shows warning if step tracking fails to initialize

**What Changed**:
- [pubspec.yaml](pubspec.yaml) - Added `permission_handler: ^11.4.4`
- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) - Added BODY_SENSORS permission
- [lib/services/permissions_service.dart](lib/services/permissions_service.dart) - **NEW** service to handle permissions
- [lib/services/step_tracking_service.dart](lib/services/step_tracking_service.dart) - Now requests permissions
- [lib/screens/dashboard_screen.dart](lib/screens/dashboard_screen.dart) - Shows permission warnings

### Issue 2: App Locking Not Functional
**Root Cause**: No actual mechanism to prevent app launches (database only, no enforcement)

**Solution Implemented**:
- Created `AppBlockingAccessibilityService` - Kotlin accessibility service that intercepts app launches
- Integrated accessibility service with database locks
- Added method channel communication between Flutter and native code
- Updated app lock settings screen to prompt users to enable service
- Service automatically blocks attempts to launch locked apps and shows toast messages

**How It Works**:
1. User toggles app to lock → saved to database
2. App notifies accessibility service via method channel
3. When user tries to open locked app → accessibility service intercepts
4. If step goal not met → app gets closed immediately
5. User sees toast: "App is locked. Walk more to unlock!"

**What Changed**:
- [android/app/src/main/kotlin/com/example/walkies/AppBlockingAccessibilityService.kt](android/app/src/main/kotlin/com/example/walkies/AppBlockingAccessibilityService.kt) - **NEW** Kotlin service
- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) - Registered service + added BIND_ACCESSIBILITY_SERVICE permission
- [android/app/src/main/res/xml/accessibility_service_config.xml](android/app/src/main/res/xml/accessibility_service_config.xml) - **NEW** service configuration
- [android/app/src/main/res/values/strings.xml](android/app/src/main/res/values/strings.xml) - **NEW** resource strings
- [android/app/src/main/kotlin/com/example/walkies/MainActivity.kt](android/app/src/main/kotlin/com/example/walkies/MainActivity.kt) - Added method channel handler
- [lib/services/app_locking_service.dart](lib/services/app_locking_service.dart) - Enhanced with accessibility service control
- [lib/screens/app_lock_settings_screen.dart](lib/screens/app_lock_settings_screen.dart) - Shows service status + enable prompt

---

## 🔧 Build & Deploy

### Step 1: Clean & Install Dependencies
```bash
flutter clean
flutter pub get
```

### Step 2: Build Release APK
```bash
flutter build apk --release
```

### Step 3: Install on Device
```bash
adb install -r build/app/outputs/apk/release/app-release.apk
```

---

## 🧪 Testing Checklist

### Step Tracking
1. Open app and login
2. Go to Dashboard
3. **Check for permission banner** - If you see "Step Tracking Issue", tap "Open Settings"
4. In Settings → Permissions → Activity Recognition → Allow
5. **Return to app** - Banner should disappear
6. **Walk around for 2-3 minutes** - Step count should increment (not stay at 0)
7. Check dashboard - should show your actual steps

**If steps still = 0:**
- Check Android version (Android 12+ requires activity recognition)
- Verify device has pedometer sensor
- Check device step counter is working (Google Fit or built-in health app)

### App Locking
1. Go to App Locks menu
2. **Look for status banner:**
   - 🟢 Green = "App Locking Active" → Service is enabled
   - 🟠 Orange = "App Locking Inactive" → Need to enable
3. **If inactive**, tap "Enable Service"
4. Android Settings opens → Accessibility → Find "Walkies"
5. Tap Walkies → Toggle "Use Walkies" ON
6. **Return to app**
7. Try locking an app (e.g., Camera, Gallery)
8. **Go to home screen and try launching the locked app**
9. Should close immediately with toast: "App is locked. Walk more to unlock!"

**If app still opens:**
- Verify accessibility service is enabled (Settings → Accessibility → look for Walkies checkmark)
- Check app isn't on system blocklist
- May need to restart phone

---

## ⚠️ Important Permissions Required

### Android Permissions (Already Added)
```xml
<!-- In AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="android.permission.BODY_SENSORS" />
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
<uses-permission android:name="android.permission.BIND_ACCESSIBILITY_SERVICE" />
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" />
```

### Runtime Permissions (User Grants)
When you run the app for the first time, you'll be asked to grant:
1. **Activity Recognition** - For step counting
2. **Body Sensors** - For pedometer access

### Accessibility Service (User Must Enable)
1. Navigate to **Settings → Accessibility**
2. Look for "Walkies"
3. Toggle it ON
4. Tap to open → Enable the service
5. Grant any additional permissions

---

## 🐛 Troubleshooting

### Steps Not Counting
| Symptom | Solution |
|---------|----------|
| Permission banner shows | Tap "Open Settings" → enable Activity Recognition |
| Device pedometer missing | Some devices don't have pedometers (check your phone specs) |
| Steps stuck at 0 | Restart app, verify Activity Recognition is granted |
| Android < 12 issues | Some older devices may need additional configuration |

### App Locking Not Working
| Symptom | Solution |
|---------|----------|
| Banner shows "Inactive" | Tap "Enable Service" → Go to Settings → Accessibility → Find Walkies → Toggle ON |
| Service won't enable | Some custom ROMs block accessibility services (check manufacturer settings) |
| Apps still open | Verify Walkies appears in Accessibility with a checkmark |
| Locked apps work fine | Service might not have received updated app list - toggle lock off/on |

### Build Errors
```bash
# If build fails with Kotlin errors
flutter clean
rm -rf android/build
flutter pub get
flutter build apk --release

# If gradlew has permission issues (Windows)
cd android
./gradlew.bat clean
./gradlew.bat build
```

---

## 📱 New Features Added

### Permission Service (`PermissionsService`)
- Handles runtime permission requests
- Checks permission status
- Opens app settings for manual enabling
- User-friendly permission reason strings

### Network Service (From Previous Fix)
- Checks internet connectivity
- Retries failed network requests
- User-friendly error messages

### Accessibility Service (`AppBlockingAccessibilityService`)
- Monitors app launches
- Automatically closes locked apps
- Shows toast notifications
- Works even when app is closed (system-level service)

---

## 🔄 How It All Works Together

```
User Sets Goal (7000 steps)
         ↓
   User Locks Apps
         ↓
   Toggle App Lock → Saved to DB + Sent to Accessibility Service
         ↓
   User Walks (Pedometer counts steps → saved to DB)
         ↓
   User Tries to Open Locked App
         ↓
   Accessibility Service Intercepts
         ↓
   Step Check: current_steps >= goal?
         ├─ YES → Allow app to open ✅
         └─ NO  → Close app immediately + Show toast ❌
```

---

## 📞 Still Having Issues?

Check the app logs:
```bash
adb logcat | grep flutter
```

Look for error messages related to:
- `StepTracking` - Step counting errors
- `Accessibility` - App locking errors
- `Permission` - Permission-related errors

---

**Status**: ✅ Ready for Testing!
After building and installing the new APK, your app should:
1. ✅ Accurately track steps (with permission)
2. ✅ Actually block locked apps (with accessibility service)
3. ✅ Show clear status and setup prompts
4. ✅ Handle network errors gracefully
