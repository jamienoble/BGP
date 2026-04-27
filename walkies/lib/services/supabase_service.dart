import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walkies/models/app_lock.dart';
import 'package:walkies/models/daily_steps.dart';
import 'package:walkies/models/step_goal.dart';
import 'package:walkies/models/user.dart';
import 'package:walkies/services/network_service.dart';
import 'package:walkies/constants/app_constants.dart';

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

        print(
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

  Future<AuthResponse> signUp(
    String email,
    String password, {
    String? preferredName,
  }) async {
    return await _retryWithBackoff(
      () => client.auth.signUp(
        email: email,
        password: password,
        data: preferredName == null || preferredName.trim().isEmpty
            ? null
            : {'preferred_name': preferredName.trim()},
      ),
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

  Future<String?> getPreferredName() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final response = await client
        .from('user_profiles')
        .select('preferred_name')
        .eq('user_id', userId)
        .maybeSingle();

    final dbValue = response?['preferred_name'] as String?;
    if (dbValue != null && dbValue.trim().isNotEmpty) {
      return dbValue.trim();
    }

    final metadataValue =
        client.auth.currentUser?.userMetadata?['preferred_name'] as String?;
    if (metadataValue != null && metadataValue.trim().isNotEmpty) {
      return metadataValue.trim();
    }

    return null;
  }

  Future<void> upsertPreferredName(String preferredName) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final cleaned = preferredName.trim();
    if (cleaned.isEmpty) throw Exception('Preferred name cannot be empty');

    await client.from('user_profiles').upsert({
      'user_id': userId,
      'preferred_name': cleaned,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<void> ensureUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return;

    final existing = await client
        .from('user_profiles')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) return;

    final metadataName =
        client.auth.currentUser?.userMetadata?['preferred_name'] as String?;
    final fallbackName =
        (metadataName != null && metadataName.trim().isNotEmpty)
            ? metadataName.trim()
            : null;

    await client.from('user_profiles').insert({
      'user_id': userId,
      'preferred_name': fallbackName,
    });
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

    final existing = await getStepGoal();

    if (existing != null) {
      final response = await client
          .from('step_goals')
          .update({'daily_steps': dailySteps})
          .eq('user_id', userId)
          .select()
          .single();

      return StepGoal.fromJson(response);
    } else {
      final response = await client
          .from('step_goals')
          .insert({'user_id': userId, 'daily_steps': dailySteps})
          .select()
          .single();

      return StepGoal.fromJson(response);
    }
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

    final today = DateTime.now();
    final dateStr = today.toIso8601String().split('T')[0];

    final response = await client
        .from('daily_steps')
        .select()
        .eq('user_id', userId)
        .eq('date', dateStr)
        .maybeSingle();

    return response != null ? DailySteps.fromJson(response) : null;
  }

  Future<DailySteps> upsertTodaySteps(int steps) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final today = DateTime.now();
    final dateStr = today.toIso8601String().split('T')[0];

    final existing = await getTodaySteps();

    if (existing != null) {
      final response = await client
          .from('daily_steps')
          .update({'steps': steps})
          .eq('id', existing.id)
          .select()
          .single();

      return DailySteps.fromJson(response);
    } else {
      final response = await client
          .from('daily_steps')
          .insert({
            'user_id': userId,
            'steps': steps,
            'date': dateStr,
          })
          .select()
          .single();

      return DailySteps.fromJson(response);
    }
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
        .gte('date', startDate.toIso8601String().split('T')[0])
        .order('date', ascending: false);

    return (response as List)
        .map((item) => DailySteps.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
