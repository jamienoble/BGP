import 'package:supabase_flutter/supabase_flutter.dart';

class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    required this.createdAt,
  });

  factory AppUser.fromSupabaseAuth(User user) {
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      createdAt: DateTime.parse(user.createdAt),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'created_at': createdAt.toIso8601String(),
      };
}
