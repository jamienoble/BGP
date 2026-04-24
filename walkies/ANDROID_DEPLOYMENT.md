# Android Deployment Guide - Walkies App

## 📋 Pre-Deployment Checklist

### Step 1: Environment Setup ✓
- [ ] Flutter SDK installed (`flutter --version`)
- [ ] Android SDK installed (via Android Studio)
- [ ] Java Development Kit (JDK) 11+ installed
- [ ] `ANDROID_SDK_ROOT` and `JAVA_HOME` environment variables set

**Verify:**
```bash
flutter doctor
```

### Step 2: Supabase Configuration ✓
- [ ] Create Supabase project at https://app.supabase.com
- [ ] Copy Project URL and Anon Key
- [ ] **Edit `lib/main.dart` (lines 14-17):**
  ```dart
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',           // Paste Project URL
    anonKey: 'YOUR_SUPABASE_ANON_KEY',  // Paste Anon Key
  );
  ```
- [ ] Run `SUPABASE_SCHEMA.sql` in Supabase SQL Editor (creates tables & RLS)

**Verify:**
```bash
grep -A 2 "await Supabase.initialize" lib/main.dart
```

### Step 3: Android Device Preparation ✓
- [ ] **Enable Developer Mode:**
  - Go to Settings > About Phone
  - Tap Build Number 7 times
  - Settings > System > Developer Options now visible

- [ ] **Enable USB Debugging:**
  - Settings > System > Developer Options
  - Toggle "USB Debugging" ON

- [ ] **Connect USB Cable** (preferably with data transfer enabled)

**Verify connected device:**
```bash
flutter devices
```

---

## 🚀 Deployment Steps

### Step 4: Clean Build Environment
```bash
cd /home/jamie/Documents/GitRepo/BGP/walkies

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Verify code quality
flutter analyze
```

### Step 5: Run on Device (Debug Mode - Fastest)
```bash
# List connected devices
flutter devices

# Run app in debug mode
flutter run

# Alternative: specify device by ID
flutter run -d [DEVICE_ID]
```

**Expected output:**
```
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Launching lib/main.dart on [device-name] in debug mode...
```

---

## 🔧 Build Modes & Options

### Debug Build (Recommended for Testing)
```bash
flutter run --debug
```
- **Fastest to build** (~30-60 seconds)
- Includes debugging symbols
- Hot reload enabled
- Perfect for functional testing

### Profile Build (Performance Testing)
```bash
flutter run --profile
```
- Optimized performance
- Debugging disabled
- ~2-3 min build time

### Release Build (Final Distribution)
```bash
flutter build apk
# Creates: build/app/outputs/flutter-apk/app-release.apk

# Or release with split APKs (smaller downloads)
flutter build apk --split-per-abi
```

---

## 📱 Testing Workflow

### Immediate Testing (After Deployment)
1. **App Launch:**
   - App should open with LoginScreen
   - Check for "YOUR_SUPABASE_URL" in debug console (if still placeholder, that's the issue)

2. **Sign Up Flow:**
   - Enter email: `test@example.com`
   - Enter password: `testpassword123`
   - Click "Sign Up"
   - Should see: "Check your email to confirm signup"

3. **Confirm Email:**
   - Open email inbox
   - Click confirmation link from Supabase
   - Return to app

4. **Sign In:**
   - Enter same email/password
   - Should navigate to DashboardScreen

5. **Set Step Goal:**
   - Tap "Daily Goal" card
   - Enter `5000` (or desired number)
   - Tap "Save Goal"
   - Should return to dashboard

6. **Lock Apps:**
   - Tap "App Locks Active"
   - Scroll through installed apps
   - Toggle switch on a test app (e.g., Gallery, Calculator)
   - App should now be locked

7. **Step Tracking:**
   - Dashboard should show step counter (initially 0)
   - Walk around with device for 2-3 minutes
   - Steps should increment

---

## 🐛 Troubleshooting

### Device Not Recognized
```bash
# Check connection
flutter devices

# If not listed:
# 1. Reconnect USB cable
# 2. Check phone notification for "Allow USB debugging"
# 3. Restart Flutter daemon
adb devices
adb kill-server
adb devices
```

### Supabase Connection Errors
**Symptoms:** App crashes on login attempt
```
E/flutter: [ERROR:flutter/runtime/dart_isolate.cc:123]
Unhandled Exception: Failed to initialize Supabase
```

**Fix:**
1. Verify credentials in `lib/main.dart` are correct (copy-paste from Supabase > Settings > API)
2. Ensure Supabase project is active
3. Check internet connection on device
4. Rebuild: `flutter clean && flutter pub get && flutter run`

### "No Android SDK found"
```bash
# Set Android SDK path
export ANDROID_SDK_ROOT=/path/to/android/sdk
# Or on Windows:
# set ANDROID_SDK_ROOT=C:\Android\sdk

# Verify
flutter doctor
```

### App Closes Immediately
1. Check logcat:
   ```bash
   adb logcat -s flutter
   ```
2. Look for error messages
3. Common causes:
   - Supabase not initialized (check credentials)
   - Missing permissions (check AndroidManifest.xml)
   - Dependency issues (`flutter pub get`)

### Steps Not Tracking
1. **Grant Permission:**
   - On device: Settings > Apps > Walkies > Permissions > Activity Recognition
   - Toggle ON

2. **Test Pedometer:**
   ```bash
   # Check if device has accelerometer
   adb shell getprop ro.hardware
   ```

3. **Check Supabase Connection:**
   - Open Supabase Dashboard
   - Tables > daily_steps
   - Should see new record after walking

---

## 🔍 Monitoring & Debugging

### View Logs in Real-Time
```bash
# All Flutter logs
flutter logs

# Filtered logs
flutter logs | grep "Walkies"
```

### Check Database Sync
1. Open Supabase Project Dashboard
2. Navigate to: Table Editor > daily_steps
3. Should see new records with timestamps

### Device Performance
```bash
# Memory usage
adb shell am proc-stats package.name

# Check app size
ls -lh build/app/outputs/flutter-apk/
```

---

## ✅ Final Verification Checklist

Before considering deployment successful:

- [ ] App launches without crashes
- [ ] LoginScreen displays correctly
- [ ] Can sign up and receive email confirmation
- [ ] Can sign in successfully
- [ ] Navigation to DashboardScreen works
- [ ] Can set daily step goal
- [ ] Can view and toggle app locks
- [ ] Step counter increments after walking
- [ ] Supabase tables show data in real-time
- [ ] All UI elements responsive and clickable
- [ ] No errors in `flutter logs`

---

## 📊 Performance Benchmarks

Expected performance on typical Android device:

| Metric | Expected | Status |
|--------|----------|--------|
| App startup time | 2-5 seconds | ✓ |
| Dashboard load | <1 second | ✓ |
| Step sync interval | Real-time | ✓ |
| App lock toggle | <500ms | ✓ |
| Memory usage | 50-150 MB | ✓ |

---

## 🛑 Rollback / Reinstall

If you need to completely reset:

```bash
# Uninstall app from device
adb uninstall com.example.walkies

# Or via Settings > Apps > Walkies > Uninstall

# Then rebuild and redeploy
flutter clean
flutter pub get
flutter run
```

---

## 🎯 Testing Scenarios

### Test 1: Basic Flow
1. Sign up → Email confirmation → Sign in → Set goal → Lock app → Walk → View progress

### Test 2: Multi-App Locking
1. Lock 5 different apps
2. Walk to meet goal
3. Verify all 5 unlock simultaneously

### Test 3: Goal Adjustment
1. Set goal to 100 steps
2. Walk and reach it
3. Change goal to 1000 steps
4. Verify locked status remains until new goal met

### Test 4: Offline Behavior
1. Enable airplane mode
2. Walk with device
3. Disable airplane mode
4. Verify steps sync to Supabase

### Test 5: App Persistence
1. Close app completely
2. Reopen
3. Verify step count and lock status preserved

---

## 📞 Quick Reference Commands

```bash
# Build & run
flutter run

# Run on specific device
flutter devices                    # List devices
flutter run -d [DEVICE_ID]        # Run on device

# Logs & debugging
flutter logs                       # Real-time logs
adb logcat                         # All system logs
adb devices                        # List connected devices

# Clean builds
flutter clean
flutter pub get

# Code quality
flutter analyze
flutter format lib/

# Performance profiling
flutter run --profile

# Production build
flutter build apk                  # Single APK
flutter build apk --split-per-abi # Multiple APKs
```

---

## ✨ Next Steps After Testing

1. **Bug Fixes:** Address any issues found
2. **Performance:** Optimize if needed
3. **Release Build:** `flutter build apk` for distribution
4. **App Signing:** Sign APK for Play Store submission
5. **Beta Testing:** Upload to Google Play Beta

---

## 📚 Additional Resources

- Flutter Deployment: https://flutter.dev/docs/deployment/android
- Android Developer: https://developer.android.com/studio
- Supabase Docs: https://supabase.com/docs
- Flutter Debugging: https://flutter.dev/docs/testing/debugging

---

**Ready to test? Start with Step 4: Clean Build Environment** ✨
