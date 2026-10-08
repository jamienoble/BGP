class ContentCategory {
  final String id;
  final String name;

  ContentCategory({required this.id, required this.name});

  factory ContentCategory.fromJson(Map<String, dynamic> json) =>
      ContentCategory(id: json['id'] as String, name: json['name'] as String);
}

/// Something shown in the Education feed: an article or a video.
abstract class ContentItem {
  String get id;
  String get title;
  String? get summary;
  String? get categoryId;
  String? get imageRef;
  DateTime get sortDate;
  String get contentType; // 'article' or 'video'
}

class Article implements ContentItem {
  @override
  final String id;
  final String kind; // 'article' or 'news'
  @override
  final String title;
  @override
  final String? summary;
  final String? body;
  final String? coverImage;
  @override
  final String? categoryId;
  final DateTime? publishAt;
  final DateTime createdAt;
  final String? authorName;
  final String? sourceName;
  final String? sourceUrl;
  final bool isAiDrafted;

  Article({
    required this.id,
    required this.kind,
    required this.title,
    this.summary,
    this.body,
    this.coverImage,
    this.categoryId,
    this.publishAt,
    required this.createdAt,
    this.authorName,
    this.sourceName,
    this.sourceUrl,
    this.isAiDrafted = false,
  });

  bool get isNews => kind == 'news';

  @override
  String? get imageRef => coverImage;

  @override
  DateTime get sortDate => publishAt ?? createdAt;

  @override
  String get contentType => 'article';

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? 'article',
        title: json['title'] as String,
        summary: json['summary'] as String?,
        body: json['body'] as String?,
        coverImage: json['cover_image'] as String?,
        categoryId: json['category_id'] as String?,
        publishAt: _parseDate(json['publish_at']),
        createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
        authorName: json['author_name'] as String?,
        sourceName: json['source_name'] as String?,
        sourceUrl: json['source_url'] as String?,
        isAiDrafted: json['is_ai_drafted'] as bool? ?? false,
      );
}

class Video implements ContentItem {
  @override
  final String id;
  @override
  final String title;
  @override
  final String? summary;
  final String playbackUrl;
  final String? thumbnailImage;
  final int? durationSeconds;
  @override
  final String? categoryId;
  final DateTime? publishAt;
  final DateTime createdAt;
  final String? presenterName;

  Video({
    required this.id,
    required this.title,
    this.summary,
    required this.playbackUrl,
    this.thumbnailImage,
    this.durationSeconds,
    this.categoryId,
    this.publishAt,
    required this.createdAt,
    this.presenterName,
  });

  @override
  String? get imageRef => thumbnailImage;

  @override
  DateTime get sortDate => publishAt ?? createdAt;

  @override
  String get contentType => 'video';

  factory Video.fromJson(Map<String, dynamic> json) => Video(
        id: json['id'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String?,
        playbackUrl: json['playback_url'] as String,
        thumbnailImage: json['thumbnail_image'] as String?,
        durationSeconds: json['duration_seconds'] as int?,
        categoryId: json['category_id'] as String?,
        publishAt: _parseDate(json['publish_at']),
        createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
        presenterName: json['presenter_name'] as String?,
      );
}

/// A user's progress through a piece of content.
class ContentProgress {
  final int progressSeconds;
  final bool completed;

  ContentProgress({required this.progressSeconds, required this.completed});
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
