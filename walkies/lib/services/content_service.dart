import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walkies/models/content.dart';

/// Reads Education content. Only published items whose publish time has
/// passed are returned; that rule is enforced by row level security.
class ContentService {
  static final ContentService _instance = ContentService._internal();

  factory ContentService() => _instance;

  ContentService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  static const int _feedLimit = 50;

  Future<List<ContentCategory>> getCategories() async {
    final rows = await _client
        .from('content_categories')
        .select('id, name')
        .order('sort');
    return (rows as List)
        .map((r) => ContentCategory.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Latest news item for the news box, if any.
  Future<Article?> getLatestNews() async {
    final row = await _client
        .from('articles')
        .select()
        .eq('kind', 'news')
        .order('publish_at', ascending: false, nullsFirst: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : Article.fromJson(row);
  }

  /// Articles and videos, newest first, optionally in one category.
  Future<List<ContentItem>> getFeed({String? categoryId}) async {
    var articles = _client.from('articles').select().eq('kind', 'article');
    var videos = _client.from('videos').select();
    if (categoryId != null) {
      articles = articles.eq('category_id', categoryId);
      videos = videos.eq('category_id', categoryId);
    }

    final results = await Future.wait([
      articles
          .order('publish_at', ascending: false, nullsFirst: false)
          .limit(_feedLimit),
      videos
          .order('publish_at', ascending: false, nullsFirst: false)
          .limit(_feedLimit),
    ]);

    final items = <ContentItem>[
      ...(results[0] as List)
          .map((r) => Article.fromJson(r as Map<String, dynamic>)),
      ...(results[1] as List)
          .map((r) => Video.fromJson(r as Map<String, dynamic>)),
    ];
    items.sort((a, b) => b.sortDate.compareTo(a.sortDate));
    return items.take(_feedLimit).toList();
  }

  /// The signed-in user's progress, keyed by `type:id`.
  Future<Map<String, ContentProgress>> getProgress() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    final rows = await _client
        .from('content_views')
        .select('content_type, content_id, progress_seconds, completed')
        .eq('user_id', userId);
    return {
      for (final r in rows as List)
        '${r['content_type']}:${r['content_id']}': ContentProgress(
          progressSeconds: r['progress_seconds'] as int? ?? 0,
          completed: r['completed'] as bool? ?? false,
        ),
    };
  }

  Future<void> saveProgress({
    required String contentType,
    required String contentId,
    int progressSeconds = 0,
    bool completed = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('content_views').upsert({
      'user_id': userId,
      'content_type': contentType,
      'content_id': contentId,
      'progress_seconds': progressSeconds,
      'completed': completed,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,content_type,content_id');
  }
}
