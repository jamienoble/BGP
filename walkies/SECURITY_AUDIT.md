# Security Audit: Walkies App vs OWASP/Industry Standards

## Executive Summary
Your app has **solid fundamentals** with Row-Level Security (RLS) and Supabase authentication, but critical gaps exist in bot protection, input validation, rate limiting, and advanced authentication patterns. Below is a detailed comparison against the security checklist you provided.

---

## 1. BOT & TRAFFIC PROTECTION

### Current Implementation: ❌ **NOT IMPLEMENTED**

| Component | Status | Notes |
|-----------|--------|-------|
| CAPTCHA/reCAPTCHA | ❌ None | No bot detection on login/signup |
| Rate Limiting | ❌ None | No per-IP or per-user login attempt limits |
| Device Fingerprinting | ❌ None | No device validation or suspicious login detection |
| Honeypot Fields | ❌ None | No hidden form fields to catch bots |
| Cloudflare/Arkose | ❌ None | No third-party bot protection service |

### What You Should Do:
1. **Add reCAPTCHA v3 to login/signup** (invisible scoring, no user friction)
   - Integrate `google_recaptcha_v3` Flutter package
   - Validate token server-side with Supabase Edge Functions
2. **Implement rate limiting at Supabase level:**
   ```sql
   -- Track login attempts in a separate table
   CREATE TABLE login_attempts (
     id uuid PRIMARY KEY,
     email text NOT NULL,
     ip_address text,
     attempted_at timestamp DEFAULT now(),
     success boolean
   );
   
   -- Check failed attempts before allowing new ones
   -- Implement exponential backoff: 3 fails = 5min wait, 5 fails = 1hr wait
   ```
3. **Or use Supabase Edge Functions** to enforce rate limiting before reaching auth
4. **Minimum for MVP:** Just add reCAPTCHA v3 (easiest, no backend required)

---

## 2. AUTHENTICATION

### Current Implementation: ⚠️ **PARTIAL** (Firebase backend handling most)

| Component | Status | Details |
|-----------|--------|---------|
| **Passkeys (WebAuthn)** | ❌ None | No passwordless auth |
| **Strong Password Enforcement** | ⚠️ Supabase Default | Supabase requires 6+ chars (weak), but allows user choice; no rules enforced in app |
| **Password Hashing** | ✅ Yes | Supabase uses bcrypt (verified in Supabase docs) |
| **MFA (TOTP/Hardware Keys)** | ⚠️ Partial | Supabase supports TOTP but not exposed in your UI |
| **Account Lockout** | ✅ Yes | Supabase auto-locks after ~10 failed attempts for ~15 mins |
| **Exponential Backoff** | ✅ Yes | Implemented in `supabase_service.dart` with 500ms → 1s → 2s retries |
| **OAuth (Google)** | ✅ Yes | Implemented: `signInWithGoogle()` |

### Issues:

**🔴 High Priority:**
1. **No password strength validation in UI** — Users can set weak passwords
2. **No MFA UI** — TOTP is available in Supabase but not exposed to users
3. **No account lockout feedback** — When locked, user sees generic "invalid credentials" error
4. **Credentials in code** — `main.dart` has hardcoded Supabase URL + anonKey (⚠️ CRITICAL)

### What You Should Do:

**Immediate (Security Critical):**
```dart
// 1. Move credentials to secure environment or Firebase Remote Config
// Remove from main.dart:
// url: 'https://cbanimdilwtfmouyfumr.supabase.co',
// anonKey: 'sb_publishable_6a52AMpgt5KIdS3KcGzEcQ_5P212w-l',

// Use flutter_dotenv or Firebase Remote Config instead
// For release: use Firebase Remote Config
```

**Short-term (Add to login_screen.dart):**
```dart
// Password strength validator
String? _validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Password required';
  if (value.length < 12) return 'Min 12 chars';
  if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Need uppercase';
  if (!RegExp(r'[0-9]').hasMatch(value)) return 'Need number';
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) return 'Need special char';
  return null;
}
```

**Medium-term:**
- Add TOTP MFA setup screen (enable user choice to enable 2FA)
- Show account lockout message: "Account locked. Try again in 15 minutes."

---

## 3. AUTHORIZATION (Access Control)

### Current Implementation: ✅ **GOOD**

| Component | Status | Details |
|-----------|--------|---------|
| **RLS (Row-Level Security)** | ✅ Yes | Every table has `auth.uid() = user_id` checks |
| **Least Privilege** | ✅ Yes | Users can only see/modify own data |
| **RBAC (Role-Based)** | ⚠️ N/A | Single role (user); no admin panel needed for MVP |
| **JWT Validation** | ✅ Yes | Supabase validates JWTs server-side automatically |
| **RLS Enforcement** | ✅ Yes | `FORCE ROW LEVEL SECURITY` in SUPABASE_HARDENING.sql |

### What You Should Do:
- ✅ **Keep as-is** — Your RLS is solid
- If you add admin features later: add `role` field to `auth.users` metadata and check it in policies

---

## 4. TRANSPORT SECURITY (TLS/HTTPS)

### Current Implementation: ✅ **YES** (via Supabase)

| Component | Status | Details |
|-----------|--------|---------|
| **TLS 1.2+** | ✅ Yes | Supabase enforces HTTPS only |
| **Certificate Pinning** | ⚠️ No | Not implemented in app; risk if network intercepted |
| **HSTS Headers** | ✅ Yes | Supabase sets HSTS by default |
| **CORS** | ✅ N/A | Mobile app (no CORS needed), but Supabase handles it |
| **Security Headers** | ✅ Yes (backend) | Supabase sets X-Frame-Options, Content-Security-Policy |

### What You Should Do:
- Consider **certificate pinning** for Android/iOS if handling sensitive data (bonus security)
- ```dart
  // In supabase_service.dart, you could add cert pinning:
  // final certPin = 'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA...';
  // (Would require adding dio package and custom HTTP client)
  ```

---

## 5. INPUT VALIDATION & INJECTION PREVENTION

### Current Implementation: ⚠️ **NEEDS WORK**

| Threat | Status | Current Code | Problem |
|--------|--------|--------------|---------|
| **SQL Injection** | ✅ Safe | `client.from('table').eq('user_id', userId)` | Supabase uses parameterized queries; ✅ Good |
| **XSS (Output Encoding)** | ❌ Risk | `Text(_preferredName!)` in settings_screen.dart | Flutter text fields auto-escape, but user-generated names could appear in web version; should sanitize |
| **CSRF** | ✅ Safe | Not applicable | Flutter sends JWTs (no cookies), immune to CSRF |
| **Email Validation** | ⚠️ Weak | No validation in login_screen.dart | Should validate email format before submission |
| **Preferred Name Sanitization** | ⚠️ Weak | `preferredName.trim()` only | Should strip HTML/special chars |
| **Integer Input (Step Goals)** | ⚠️ Weak | `dailySteps` passed as `int` | No range validation (0-999999) in UI |

### Issues & Fixes:

**Email validation is missing:**
```dart
// In login_screen.dart, add before sign-in:
String? _validateEmail(String? value) {
  if (value == null || value.isEmpty) return 'Email required';
  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  if (!emailRegex.hasMatch(value)) return 'Invalid email format';
  return null;
}
```

**Preferred name needs sanitization:**
```dart
// In supabase_service.dart, update upsertPreferredName:
Future<void> upsertPreferredName(String preferredName) async {
  final cleaned = preferredName
    .trim()
    .replaceAll(RegExp(r'[<>"\']'), '') // Remove HTML special chars
    .replaceAll(RegExp(r'[^\w\s-]'), ''); // Allow only word chars, spaces, hyphens
  
  if (cleaned.isEmpty) throw Exception('Name must contain valid characters');
  if (cleaned.length > 50) throw Exception('Name too long (max 50 chars)');
  // ... rest of method
}
```

**Step goal range validation:**
```dart
// In goal_management_screen.dart:
const int minSteps = 100;
const int maxSteps = 50000;

String? _validateStepGoal(String? value) {
  final steps = int.tryParse(value ?? '');
  if (steps == null) return 'Must be a number';
  if (steps < minSteps) return 'Min $minSteps steps';
  if (steps > maxSteps) return 'Max $maxSteps steps';
  return null;
}
```

---

## 6. DATA PROTECTION

### Current Implementation: ⚠️ **PARTIAL**

| Component | Status | Details |
|-----------|--------|---------|
| **Password Hashing** | ✅ Yes | Supabase uses bcrypt |
| **Encryption at Rest** | ✅ Yes (Supabase) | Data encrypted in PostgreSQL by default |
| **Secrets Management** | ❌ CRITICAL | Hardcoded in `main.dart` |
| **PII Minimization** | ✅ Good | Only store: email, preferred_name, step counts |
| **Local Data Encryption** | ⚠️ No | SharedPreferences stores step baselines in plaintext |

### Critical Issues:

**🔴 CRITICAL — Credentials in Code:**
```dart
// Current (UNSAFE):
await Supabase.initialize(
  url: 'https://cbanimdilwtfmouyfumr.supabase.co',
  anonKey: 'sb_publishable_6a52AMpgt5KIdS3KcGzEcQ_5P212w-l', // ← EXPOSED!
);
```

**Fix Option 1: Use Environment Variables (Development)**
```dart
// Create lib/config/env.dart (add to .gitignore)
class AppEnv {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}

// Run with: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

**Fix Option 2: Use Firebase Remote Config (Recommended for Production)**
```dart
// Fetch from Firebase at app startup
final remoteConfig = FirebaseRemoteConfig.instance;
await remoteConfig.fetchAndActivate();

final supabaseUrl = remoteConfig.getString('supabase_url');
final supabaseAnonKey = remoteConfig.getString('supabase_anon_key');

await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
```

**⚠️ LOCAL DATA ISSUE:**
```dart
// In step_tracking_service.dart, step baselines are stored in SharedPreferences:
prefs.setInt(AppConstants.prefStepBaselineValue, _pedometerBaseline);
```
**Risk:** If device is rooted/jailbroken, step data readable. For MVP this is acceptable (not cryptographic keys), but consider:
```dart
// For sensitive local storage, use flutter_secure_storage:
final secureStorage = FlutterSecureStorage();
await secureStorage.write(key: 'step_baseline', value: _pedometerBaseline.toString());
```

---

## 7. SUMMARY TABLE

| Category | Status | Priority | Effort |
|----------|--------|----------|--------|
| **Authentication** | ⚠️ Partial | 🔴 HIGH | 2-3 hrs |
| - Hardcoded Credentials | 🔴 CRITICAL | 🔴 CRITICAL | 1 hr |
| - No Password Rules | ⚠️ Medium | 🟡 MEDIUM | 30 min |
| - No MFA UI | ⚠️ Low | 🟡 MEDIUM | 2 hrs |
| **Authorization** | ✅ Good | ✅ DONE | — |
| **Transport** | ✅ Good | ✅ DONE | — |
| **Input Validation** | ⚠️ Weak | 🟡 MEDIUM | 1-2 hrs |
| - Email validation | ⚠️ Missing | 🟡 MEDIUM | 15 min |
| - Name sanitization | ⚠️ Weak | 🟡 MEDIUM | 30 min |
| - Step range validation | ⚠️ Weak | 🟡 MEDIUM | 30 min |
| **Bot Protection** | ❌ None | 🟡 MEDIUM | 2-4 hrs |
| - reCAPTCHA v3 | ❌ None | 🟡 MEDIUM | 2 hrs |
| - Rate Limiting | ❌ None | 🟡 MEDIUM | 2 hrs |
| **Data Protection** | ⚠️ Partial | 🟡 MEDIUM | 1-2 hrs |
| - RLS Enforcement | ✅ Good | ✅ DONE | — |
| - Local encryption | ⚠️ Optional | 🟢 LOW | 1 hr |

---

## 🚀 Priority Roadmap

### **Phase 1: CRITICAL (Today)**
1. Move credentials out of `main.dart` → Firebase Remote Config or env vars
2. Add email validation to login
3. Add name sanitization to avoid XSS in future web version

**Time: ~2 hours**

### **Phase 2: HIGH (This Week)**
1. Add password strength rules & validator
2. Implement reCAPTCHA v3 on login/signup
3. Expose TOTP MFA setup in settings
4. Add step goal range validation

**Time: ~4 hours**

### **Phase 3: MEDIUM (Next Sprint)**
1. Implement server-side rate limiting (Supabase Edge Functions)
2. Add certificate pinning for transport security
3. Use flutter_secure_storage for local sensitive data

**Time: ~4 hours**

### **Phase 4: NICE-TO-HAVE**
1. Device fingerprinting for suspicious login detection
2. Admin dashboard with user management & audit logs
3. Webhook logging for all auth events

---

## Supabase Best Practices You're Already Doing ✅

1. ✅ Row-Level Security enforced (`FORCE ROW LEVEL SECURITY`)
2. ✅ Authenticated users only (policies use `TO authenticated`)
3. ✅ Per-user data isolation (`auth.uid() = user_id`)
4. ✅ Exponential backoff retries on network errors
5. ✅ OAuth integration (Google)
6. ✅ Proper session management via auth state stream

---

## Files to Update

| File | Changes | Priority |
|------|---------|----------|
| `lib/main.dart` | Move credentials | 🔴 CRITICAL |
| `lib/screens/login_screen.dart` | Email validation, error handling | 🟡 HIGH |
| `lib/screens/goal_management_screen.dart` | Step range validation | 🟡 HIGH |
| `lib/services/supabase_service.dart` | Name sanitization | 🟡 HIGH |
| `pubspec.yaml` | Add reCAPTCHA, validators packages | 🟡 HIGH |
| `lib/constants/app_constants.dart` | Add validation constants | 🟡 MEDIUM |

---

## Recommended Packages to Add

```yaml
dependencies:
  google_recaptcha_v3: ^1.0.0          # reCAPTCHA v3
  form_validator: ^0.1.1               # Email/string validation helpers
  flutter_secure_storage: ^9.0.0       # Encrypted local storage
  firebase_remote_config: ^4.0.0       # For credentials management
```

---

## Next Steps

1. **Fix CRITICAL issue** (hardcoded credentials) immediately
2. **Run this audit again** in 1 week after Phase 1 fixes
3. **Consider penetration testing** before production launch
4. **Enable Supabase audit logs** to track all database changes
