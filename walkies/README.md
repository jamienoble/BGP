# Walkies - App Locker Based on Step Goals

## 🎯 Overview

**Walkies** is a Flutter-based fitness incentive app that uses step tracking to enforce app usage. Users set daily step goals, and any apps they "lock" become unavailable until they reach their daily step target.

### Key Features:
- 🚶 **Real-time Step Tracking** via device pedometer
- 🔒 **App Locking Mechanism** - Lock distracting apps
- 📊 **Progress Dashboard** - Visual step counter with goal tracking
- 🎯 **Custom Goals** - Set your daily step target
- ☁️ **Supabase Backend** - Secure cloud sync across devices
- 🔐 **Authentication** - Email/password signup and signin

---

## 📁 Project Structure

```
lib/
├── main.dart                          # Entry point with auth wrapper & Supabase init
├── models/
│   ├── user.dart                      # User authentication model
│   ├── step_goal.dart                 # Daily step goal configuration
│   ├── app_lock.dart                  # Locked app configuration
│   └── daily_steps.dart               # Daily step record
├── services/
│   ├── supabase_service.dart          # Supabase API client (CRUD operations)
│   ├── step_tracking_service.dart     # Pedometer integration & data sync
│   └── app_locker_service.dart        # App locking logic & queries
└── screens/
    ├── login_screen.dart              # Signup/Login UI
    ├── dashboard_screen.dart          # Main dashboard with progress ring
    ├── goal_management_screen.dart    # Set/update daily goals
    └── app_lock_settings_screen.dart  # List installed apps & lock/unlock
```

---

## 🚀 Quick Start

### 1. **Prerequisites**
- Flutter SDK 3.11.5+
- Dart 3.11.5+
- Supabase account (https://supabase.com)

### 2. **Setup Supabase**
1. Create a new Supabase project
2. Go to SQL Editor
3. Run the SQL from `SUPABASE_SCHEMA.sql` to create tables and policies
4. Copy your Project URL and Anon Key from Settings > API

### 3. **Configure App**
Edit `lib/main.dart` and add your Supabase credentials:
```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```

### 4. **Install & Run**
```bash
flutter pub get
flutter run
```

---

## 📊 Data Flow

```
User Pedometer (Physical Steps)
         ↓
  StepTrackingService (Listen & Aggregate)
         ↓
  SupabaseService.upsertTodaySteps()
         ↓
  Supabase Database (daily_steps table)
         ↓
  DashboardScreen (Display Progress)
         ↓
  Check if Goal Met → Unlock Locked Apps
```

---

## 🔐 Security

- **Row Level Security (RLS)** on all tables ensures users see only their data
- Authentication via Supabase Auth (secure JWT tokens)
- No credentials stored locally (managed by Supabase)
- App locks are user-specific and cloud-synced

---

## 📦 Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `supabase_flutter` | ^2.0.0 | Cloud backend & auth |
| `pedometer` | ^3.0.0 | Step tracking |
| `device_apps` | ^2.1.0 | List installed apps |
| `shared_preferences` | ^2.2.0 | Local caching |
| `provider` | ^6.1.0 | State management |
| `intl` | ^0.19.0 | Internationalization |

---

## ⚙️ Configuration Files

### `pubspec.yaml`
- Lists all Flutter dependencies
- Configures app name, version, and assets

### `SUPABASE_SCHEMA.sql`
- Creates database tables: `step_goals`, `daily_steps`, `app_locks`
- Enables Row Level Security policies
- Ensures data isolation per user

### `AndroidManifest.xml`
- Added `ACTIVITY_RECOGNITION` permission (step tracking)
- Added `QUERY_ALL_PACKAGES` permission (app listing)

---

## 🎮 Usage Flow

```
1. Launch App
   ↓
2. Sign Up / Login
   ↓
3. Set Daily Step Goal (e.g., 7000 steps)
   ↓
4. Select Apps to Lock (e.g., TikTok, Instagram)
   ↓
5. Dashboard shows Progress (0/7000 steps)
   ↓
6. Physical Activity: Walk & Steps accumulate
   ↓
7. App syncs with Supabase every step count change
   ↓
8. Once 7000 steps reached → Locked apps unlock
```

---

## 🛠️ Key Services

### **SupabaseService**
- Handles all database CRUD operations
- Manages authentication (signup/login/logout)
- Sync step goals, daily steps, and app locks

### **StepTrackingService**
- Listens to device pedometer stream
- Updates Supabase daily step count in real-time
- Handles local caching via SharedPreferences

### **AppLockerService**
- Queries which apps are locked for current user
- Checks if user has met goal before allowing app launch
- Manages lock/unlock operations

---

## 📱 Screens Breakdown

| Screen | Purpose |
|--------|---------|
| **LoginScreen** | User authentication (signup/signin) |
| **DashboardScreen** | Main hub - shows step progress, app locks status |
| **GoalManagementScreen** | Set/update daily step target |
| **AppLockSettingsScreen** | Browse installed apps & toggle locks |

---

## 🐛 Troubleshooting

### Steps Not Tracking?
- ✅ Verify `ACTIVITY_RECOGNITION` permission is granted
- ✅ Ensure device supports pedometer
- ✅ Check Supabase credentials are correct
- ✅ Restart app if changes not reflected

### Build Errors?
```bash
flutter clean
flutter pub get
flutter analyze
```

### Supabase Connection Issues?
- Verify Project URL is correct (no typos)
- Verify Anon Key matches your project
- Check internet connection
- Ensure Supabase project is active

---

## 🎯 Future Enhancements

- [ ] Push notifications when goals are near completion
- [ ] Weekly/monthly statistics and charts
- [ ] Social challenges with friends
- [ ] Time-based app restrictions
- [ ] Reward system for consistent achievement
- [ ] Dark mode theme
- [ ] Multilingual support

---

## 📄 License

MIT License - Feel free to modify and distribute!

---

## 📧 Support

For issues or feature requests, please create an issue in the repository.

**Happy Walking! 🚶‍♂️**
