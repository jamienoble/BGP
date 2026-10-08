import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walkies/models/community.dart';

/// Thrown when the database rate limit (posts/comments per hour) is hit
class CommunityRateLimitException implements Exception {}

/// Community data. Visibility, blocking, posting rights and rate limits
/// are enforced in the database (row level security and triggers); this
/// class only shapes requests and results.
class CommunityService {
  static final CommunityService _instance = CommunityService._internal();

  factory CommunityService() => _override ?? _instance;

  static CommunityService? _override;

  /// Replace the shared instance. For tests and screenshot previews only.
  @visibleForTesting
  static set debugOverride(CommunityService? value) => _override = value;

  /// For test fakes that subclass this service.
  @visibleForTesting
  CommunityService.forTesting();

  CommunityService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  static const int pageSize = 30;

  // ---------------------------------------------------------------- profile

  Future<CommunityProfile?> getMyProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final row = await _client
        .from('community_profiles')
        .select('user_id, display_name')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : CommunityProfile.fromJson(row);
  }

  /// Join the community. The caller has confirmed 18+ and accepted the rules.
  Future<void> createProfile(String displayName) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not signed in');
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('community_profiles').insert({
      'user_id': userId,
      'display_name': displayName.trim(),
      'confirmed_adult_at': now,
      'accepted_rules_at': now,
    });
  }

  Future<void> updateDisplayName(String displayName) async {
    final userId = currentUserId;
    if (userId == null) return;
    await _client
        .from('community_profiles')
        .update({'display_name': displayName.trim()})
        .eq('user_id', userId);
  }

  /// End of the current user's posting ban, if any. A ban with no end
  /// date is returned as [DateTime] far in the future.
  Future<DateTime?> getMyRestriction() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final row = await _client
        .from('community_restrictions')
        .select('banned_until')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    final until = row['banned_until'] as String?;
    if (until == null) return DateTime(9999);
    final end = DateTime.parse(until).toLocal();
    return end.isAfter(DateTime.now()) ? end : null;
  }

  // ------------------------------------------------------------------ feed

  Future<List<CommunityTopic>> getTopics() async {
    final rows =
        await _client.from('community_topics').select().order('sort');
    return (rows as List)
        .map((r) => CommunityTopic.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Posts in a topic, newest first. Pass [before] (the oldest loaded
  /// post's time) to load the next page.
  Future<List<CommunityPost>> getPosts(String topicId, {DateTime? before}) async {
    var query = _client.from('community_post_feed').select().eq('topic_id', topicId);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await query.order('created_at', ascending: false).limit(pageSize);
    return (rows as List)
        .map((r) => CommunityPost.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<CommunityPost?> getPost(String postId) async {
    final row = await _client
        .from('community_post_feed')
        .select()
        .eq('id', postId)
        .maybeSingle();
    return row == null ? null : CommunityPost.fromJson(row);
  }

  Future<void> createPost(String topicId, String body) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not signed in');
    await _guardRateLimit(() => _client.from('community_posts').insert({
          'topic_id': topicId,
          'author_id': userId,
          'body': body.trim(),
        }));
  }

  Future<void> deletePost(String postId) async {
    await _client.from('community_posts').delete().eq('id', postId);
  }

  /// Add or remove the current user's "support" reaction
  Future<void> setReaction(String postId, bool reacted) async {
    final userId = currentUserId;
    if (userId == null) return;
    if (reacted) {
      await _client.from('community_reactions').upsert(
        {'post_id': postId, 'user_id': userId},
        onConflict: 'post_id,user_id',
        ignoreDuplicates: true,
      );
    } else {
      await _client
          .from('community_reactions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
    }
  }

  // -------------------------------------------------------------- comments

  Future<List<CommunityComment>> getComments(String postId) async {
    final rows = await _client
        .from('community_comments')
        .select('id, post_id, author_id, body, status, created_at')
        .eq('post_id', postId)
        .order('created_at');
    final comments = (rows as List).cast<Map<String, dynamic>>();
    final names = await _displayNames(
      comments.map((c) => c['author_id'] as String).toSet(),
    );
    return comments
        .map((c) => CommunityComment(
              id: c['id'] as String,
              postId: c['post_id'] as String,
              authorId: c['author_id'] as String,
              authorName: names[c['author_id']] ?? 'Member',
              body: c['body'] as String,
              status: c['status'] as String? ?? 'visible',
              createdAt: DateTime.parse(c['created_at'] as String).toLocal(),
            ))
        .toList();
  }

  Future<void> addComment(String postId, String body) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not signed in');
    await _guardRateLimit(() => _client.from('community_comments').insert({
          'post_id': postId,
          'author_id': userId,
          'body': body.trim(),
        }));
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('community_comments').delete().eq('id', commentId);
  }

  // ------------------------------------------------------------ moderation

  /// Report a post or a comment (exactly one of the ids).
  /// Reporting the same thing twice is treated as success.
  Future<void> report({
    String? postId,
    String? commentId,
    required String reason,
    String? details,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      await _client.from('community_reports').insert({
        'reporter_id': userId,
        'post_id': postId,
        'comment_id': commentId,
        'reason': reason,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // unique violation: already reported
    }
  }

  Future<void> blockUser(String userId) async {
    final me = currentUserId;
    if (me == null) return;
    await _client.from('community_blocks').upsert(
      {'blocker_id': me, 'blocked_id': userId},
      onConflict: 'blocker_id,blocked_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> unblockUser(String userId) async {
    final me = currentUserId;
    if (me == null) return;
    await _client
        .from('community_blocks')
        .delete()
        .eq('blocker_id', me)
        .eq('blocked_id', userId);
  }

  /// People the current user has blocked, as id -> display name
  Future<Map<String, String>> getBlockedUsers() async {
    final me = currentUserId;
    if (me == null) return {};
    final rows = await _client
        .from('community_blocks')
        .select('blocked_id')
        .eq('blocker_id', me);
    final ids = (rows as List).map((r) => r['blocked_id'] as String).toSet();
    final names = await _displayNames(ids);
    return {for (final id in ids) id: names[id] ?? 'Member'};
  }

  // --------------------------------------------------------------- helpers

  Future<Map<String, String>> _displayNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await _client
        .from('community_profiles')
        .select('user_id, display_name')
        .inFilter('user_id', userIds.toList());
    return {
      for (final r in rows as List)
        r['user_id'] as String: r['display_name'] as String,
    };
  }

  Future<void> _guardRateLimit(Future<void> Function() action) async {
    try {
      await action();
    } on PostgrestException catch (e) {
      if (e.message.contains('rate_limited')) {
        throw CommunityRateLimitException();
      }
      rethrow;
    }
  }
}
