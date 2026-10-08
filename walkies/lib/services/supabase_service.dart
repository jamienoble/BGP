import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walkies/models/app_lock.dart';
import 'package:walkies/models/daily_steps.dart';
import 'package:walkies/models/step_goal.dart';
import 'package:walkies/models/user.dart';
import 'package:walkies/services/network_service.dart';
import 'package:walkies/constants/app_constants.dart';
import 'package:walkies/utils/date_utils.dart' as date_utils;

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  final NetworkService _networkService = NetworkService();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  String? get currentUserId => client.auth.currentUser?.id;

  /// Retry a future with exponential backoff on network errors
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation, {
    String operationName = 'Operation',
  }) async {
    int retryCount = 0;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        // If it's not a network error, rethrow immediately
        if (!_networkService.isNetworkError(e)) {
          rethrow;
        }

        retryCount++;

        // If we've exhausted retries, rethrow
        if (retryCount >= AppConstants.maxRetries) {
          rethrow;
        }

        // Calculate exponential backoff: 500ms, 1s, 2s, etc.
        final delay =
            AppConstants.retryInitialDelay * (1 << (retryCount - 1));

        debugPrint(
          'Network error in $operationName. Retrying in ${delay.inMilliseconds}ms... '
          '(Attempt $retryCount/${AppConstants.maxRetries})',
        );

        await Future.delayed(delay);
      }
    }
  }

  // ==================== User Management ====================
  Future<AppUser?> getCurrentUser() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return AppUser.fromSupabaseAuth(user);
  }

  Future<AuthResponse> signUp(String email, String password) async {
    return await _retryWithBackoff(
      () => client.auth.signUp(email: email, password: password),
      operationName: 'Sign up',
    );
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _retryWithBackoff(
      () => client.auth.signInWithPassword(email: email, password: password),
      operationName: 'Sign in',
    );
  }

  Future<bool> signInWithGoogle() async {
    return client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : AppConstants.deepLinkCallbackUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Email a password reset link that opens the app
  Future<void> sendPasswordResetEmail(String email) async {
    await _retryWithBackoff(
      () => client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : AppConstants.deepLinkCallbackUrl,
      ),
      operationName: 'Password reset',
    );
  }

  /// Set a new password for the signed-in user (after a reset link)
  Future<void> updatePassword(String newPassword) async {
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Permanently delete the signed-in user's account and all their data.
  /// Requires the `delete_user` function from SUPABASE_SCHEMA.sql.
  Future<void> deleteAccount() async {
    await client.rpc('delete_user');
    await client.auth.signOut();
  }

  // ==================== Step Goals ====================
  Future<StepGoal?> getStepGoal() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final response = await client
        .from('step_goals')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    return response != null ? StepGoal.fromJson(response) : null;
  }

  Future<StepGoal> createOrUpdateStepGoal(int dailySteps) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await client
        .from('step_goals')
        .upsert(
          {'user_id': userId, 'daily_steps': dailySteps},
          onConflict: 'user_id',
        )
        .select()
        .single();

    return StepGoal.fromJson(response);
  }

  // ==================== App Locks ====================
  Future<List<AppLock>> getLockedApps() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final response =
        await client.from('app_locks').select().eq('user_id', userId);

    return (response as List)
        .map((item) => AppLock.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AppLock> createAppLock(
    String appPackageName,
    String appName,
  ) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await client
        .from('app_locks')
        .insert({
          'user_id': userId,
          'app_package_name': appPackageName,
          'app_name': appName,
          'is_locked': true,
        })
        .select()
        .single();

    return AppLock.fromJson(response);
  }

  Future<void> deleteAppLock(String appLockId) async {
    await client.from('app_locks').delete().eq('id', appLockId);
  }

  Future<AppLock> updateAppLockStatus(
    String appLockId,
    bool isLocked,
  ) async {
    final response = await client
        .from('app_locks')
        .update({'is_locked': isLocked})
        .eq('id', appLockId)
        .select()
        .single();

    return AppLock.fromJson(response);
  }

  // ==================== Daily Steps ====================
  Future<DailySteps?> getTodaySteps() async {
    final userId = currentUserId;
    if (userId == null) return null;

    return getTodayStepsForDate(date_utils.DateUtils.todayDateString());
  }

  /// Save today's steps in one request (insert or update on the
  /// user/date unique key)
  Future<void> upsertTodaySteps(int steps) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await client.from('daily_steps').upsert(
      {
        'user_id': userId,
        'steps': steps,
        'date': date_utils.DateUtils.todayDateString(),
      },
      onConflict: 'user_id,date',
    );
  }

  /// Get daily steps for a specific date (format: yyyy-MM-dd)
  Future<DailySteps?> getTodayStepsForDate(String dateStr) async {
    final userId = currentUserId;
    if (userId == null) return null;

    final response = await client
        .from('daily_steps')
        .select()
        .eq('user_id', userId)
        .eq('date', dateStr)
        .maybeSingle();

    return response != null ? DailySteps.fromJson(response) : null;
  }

  Future<List<DailySteps>> getStepsHistory(int days) async {
    final userId = currentUserId;
    if (userId == null) return [];

    final startDate = DateTime.now().subtract(Duration(days: days));

    final response = await client
        .from('daily_steps')
        .select()
        .eq('user_id', userId)
        .gte('date', date_utils.DateUtils.todayDateString(dateTime: startDate))
        .order('date', ascending: false);

    return (response as List)
        .map((item) => DailySteps.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
