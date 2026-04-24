# Walkies - App Locker with Step Goals

A Flutter app that locks applications on your phone until you reach your daily step goals, powered by Supabase backend.

## Features

✅ **Step Tracking**: Real-time pedometer integration to track daily steps  
✅ **Custom Step Goals**: Set your own daily step target  
✅ **App Locking**: Lock any installed app until step goal is reached  
✅ **Supabase Backend**: Secure cloud storage for user data and app lock settings  
✅ **Real-time Sync**: Automatic sync of steps across devices  
✅ **Progress Dashboard**: Visual progress tracker with goal status  

## Setup Instructions

### 1. Prerequisites

- Flutter SDK (3.11.5+)
- Dart 3.11.5+
- Supabase account (free tier available at https://supabase.com)

### 2. Supabase Setup

1. Create a new Supabase project at https://app.supabase.com
2. Go to SQL Editor and run the schema from `SUPABASE_SCHEMA.sql`:
   - This creates tables for step goals, daily steps, and app locks
   - Enables Row Level Security for data protection

3. Get your Supabase credentials:
   - Go to Settings > API
   - Copy your `Project URL` and `Anon Key`

### 3. Update Flutter App Configuration

In `lib/main.dart`, replace the placeholder values:

```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',      // e.g., 'https://xyzabc.supabase.co'
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Configure Permissions

**Android**: Already configured in `AndroidManifest.xml` with:
- `ACTIVITY_RECOGNITION` - For step tracking
- `QUERY_ALL_PACKAGES` - For listing installed apps

**iOS**: Add to `ios/Runner/Info.plist`:
```xml
<key>NSMotionUsageDescription</key>
<string>This app uses your step count to enforce daily activity goals</string>
```

### 6. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                          # App entry point & auth wrapper
├── models/
│   ├── user.dart                      # User model
│   ├── step_goal.dart                 # Step goal model
│   ├── app_lock.dart                  # App lock model
│   └── daily_steps.dart               # Daily steps tracking model
├── services/
│   ├── supabase_service.dart          # Supabase database operations
│   ├── step_tracking_service.dart     # Pedometer integration
│   └── app_locker_service.dart        # App locking logic
└── screens/
    ├── login_screen.dart              # Authentication UI
    ├── dashboard_screen.dart          # Main dashboard with progress
    ├── goal_management_screen.dart    # Set daily step goals
    └── app_lock_settings_screen.dart  # Lock/unlock apps
```

## How It Works

1. **User Authentication**: Sign up/login via Supabase Auth
2. **Set Daily Goal**: Configure your daily step target (default 5000)
3. **Select Apps to Lock**: Choose which apps require step goals
4. **Track Progress**: Real-time step counter on dashboard
5. **Unlock Incentive**: Apps unlock automatically when goal is reached
6. **Data Persistence**: All data synced to Supabase

## API Integration

The app uses Supabase as the backend:

### Tables Created:
- `step_goals` - User daily step targets
- `daily_steps` - Daily step records
- `app_locks` - Locked apps configuration

### Row Level Security (RLS):
All tables have RLS policies ensuring users can only access their own data.

## Platform Support

- ✅ Android 5.0+
- ✅ iOS 11.0+
- 🔄 Web (requires additional configuration)
- 🔄 Linux (requires additional configuration)

## Dependencies

```yaml
supabase_flutter: ^2.5.0      # Supabase client
pedometer: ^3.1.0             # Step tracking
device_apps: ^2.2.2           # List installed apps
shared_preferences: ^2.2.2    # Local caching
provider: ^6.1.1              # State management
intl: ^0.19.0                 # Internationalization
```

## Troubleshooting

### "Target of URI doesn't exist" errors
- Run `flutter pub get` to install dependencies
- Run `flutter clean && flutter pub get` if issue persists

### Steps not tracking
- Ensure ACTIVITY_RECOGNITION permission is granted
- Check that the device supports pedometer functionality
- Verify Supabase is properly initialized with correct credentials

### App not launching after lock setup
- Check that app package name is correct
- Verify app is not a system app (system apps cannot be locked)
- Restart the app if changes don't take effect immediately

### Supabase connection errors
- Verify Project URL and Anon Key are correct
- Check internet connection
- Ensure Supabase project is active

## Next Steps / Future Features

- Push notifications when goals are about to be unlocked
- Weekly/monthly step statistics and charts
- Social challenges with friends
- Custom unlock conditions (time-based, achievement-based)
- Offline step counting sync
- App usage time limits
- Daily reminder notifications

## Contributing

Feel free to submit issues and enhancement requests!

## License

MIT License
