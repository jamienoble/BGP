class CommunityProfile {
  final String userId;
  final String displayName;

  CommunityProfile({required this.userId, required this.displayName});

  factory CommunityProfile.fromJson(Map<String, dynamic> json) =>
      CommunityProfile(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
      );
}

class CommunityTopic {
  final String id;
  final String name;
  final String? description;
  final bool isLocked;

  CommunityTopic({
    required this.id,
    required this.name,
    this.description,
    required this.isLocked,
  });

  factory CommunityTopic.fromJson(Map<String, dynamic> json) => CommunityTopic(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        isLocked: json['is_locked'] as bool? ?? false,
      );
}

class CommunityPost {
  final String id;
  final String topicId;
  final String authorId;
  final String authorName;
  final String body;
  final String status;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int commentCount;
  final int reactionCount;
  final bool reactedByMe;

  CommunityPost({
    required this.id,
    required this.topicId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.status,
    required this.createdAt,
    this.editedAt,
    required this.commentCount,
    required this.reactionCount,
    required this.reactedByMe,
  });

  bool get isHidden => status == 'hidden';

  factory CommunityPost.fromJson(Map<String, dynamic> json) => CommunityPost(
        id: json['id'] as String,
        topicId: json['topic_id'] as String,
        authorId: json['author_id'] as String,
        authorName: json['author_name'] as String? ?? 'Member',
        body: json['body'] as String,
        status: json['status'] as String? ?? 'visible',
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        editedAt: json['edited_at'] == null
            ? null
            : DateTime.parse(json['edited_at'] as String).toLocal(),
        commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
        reactionCount: (json['reaction_count'] as num?)?.toInt() ?? 0,
        reactedByMe: json['reacted_by_me'] as bool? ?? false,
      );

  CommunityPost copyWith({int? reactionCount, bool? reactedByMe, int? commentCount}) =>
      CommunityPost(
        id: id,
        topicId: topicId,
        authorId: authorId,
        authorName: authorName,
        body: body,
        status: status,
        createdAt: createdAt,
        editedAt: editedAt,
        commentCount: commentCount ?? this.commentCount,
        reactionCount: reactionCount ?? this.reactionCount,
        reactedByMe: reactedByMe ?? this.reactedByMe,
      );
}

class CommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String body;
  final String status;
  final DateTime createdAt;

  CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.status,
    required this.createdAt,
  });

  bool get isHidden => status == 'hidden';
}

/// Report reasons, matching the database check constraint
const Map<String, String> reportReasons = {
  'harassment': 'Harassment or bullying',
  'hate': 'Hate or discrimination',
  'self_harm': 'Someone may be at risk of harm',
  'misinformation': 'Harmful health misinformation',
  'spam': 'Spam or advertising',
  'sexual': 'Sexual content',
  'illegal': 'Illegal content',
  'other': 'Something else',
};
