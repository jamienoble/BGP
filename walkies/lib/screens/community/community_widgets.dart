import 'package:flutter/material.dart';
import 'package:walkies/constants/app_colors.dart';
import 'package:walkies/models/community.dart';
import 'package:walkies/services/community_service.dart';

/// "5m", "3h", "2d", or a date for older items
String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${time.day}/${time.month}/${time.year}';
}

/// What the user picked from a post/comment menu
enum ItemAction { report, block, delete }

class PostCard extends StatelessWidget {
  final CommunityPost post;
  final bool isMine;
  final VoidCallback? onTap;
  final VoidCallback onToggleReaction;
  final ValueChanged<ItemAction> onAction;

  const PostCard({
    super.key,
    required this.post,
    required this.isMine,
    this.onTap,
    required this.onToggleReaction,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.sage,
                    child: Text(
                      post.authorName.isNotEmpty
                          ? post.authorName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.forest,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${post.authorName} · ${timeAgo(post.createdAt)}'
                      '${post.editedAt != null ? ' · edited' : ''}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ItemMenu(isMine: isMine, onSelected: onAction),
                ],
              ),
              if (post.isHidden)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Hidden while a moderator reviews reports. Only you can see it.',
                    style: TextStyle(fontSize: 12, color: AppColors.accent),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 10),
                child: Text(
                  post.body,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onToggleReaction,
                    icon: Icon(
                      post.reactedByMe ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: post.reactedByMe ? AppColors.accent : AppColors.muted,
                    ),
                    label: Text(
                      post.reactionCount > 0 ? '${post.reactionCount}' : 'Support',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.chat_bubble_outline,
                        size: 18, color: AppColors.muted),
                    label: Text(
                      post.commentCount > 0 ? '${post.commentCount}' : 'Reply',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ItemMenu extends StatelessWidget {
  final bool isMine;
  final ValueChanged<ItemAction> onSelected;

  const ItemMenu({super.key, required this.isMine, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ItemAction>(
      icon: const Icon(Icons.more_horiz, color: AppColors.muted),
      onSelected: onSelected,
      itemBuilder: (context) => isMine
          ? const [
              PopupMenuItem(value: ItemAction.delete, child: Text('Delete')),
            ]
          : const [
              PopupMenuItem(value: ItemAction.report, child: Text('Report')),
              PopupMenuItem(value: ItemAction.block, child: Text('Block this person')),
            ],
    );
  }
}

/// Ask for a reason and file a report. Returns true if a report was sent.
Future<bool> showReportSheet(
  BuildContext context, {
  String? postId,
  String? commentId,
}) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Why are you reporting this?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          for (final entry in reportReasons.entries)
            ListTile(
              title: Text(entry.value),
              onTap: () => Navigator.of(context).pop(entry.key),
            ),
        ],
      ),
    ),
  );
  if (reason == null) return false;

  try {
    await CommunityService().report(
      postId: postId,
      commentId: commentId,
      reason: reason,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send report. Please try again.')),
      );
    }
    return false;
  }

  if (context.mounted) {
    final atRisk = reason == 'self_harm';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: Duration(seconds: atRisk ? 10 : 4),
        content: Text(
          atRisk
              ? 'Thank you. A moderator will review it. If someone is in '
                  'immediate danger, call 999. Samaritans: 116 123.'
              : 'Thank you. A moderator will review it.',
        ),
      ),
    );
  }
  return true;
}

/// Confirm and block. Returns true if blocked.
Future<bool> confirmBlock(
  BuildContext context, {
  required String userId,
  required String name,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Block $name?'),
      content: const Text(
        'You won\'t see their posts or comments. They won\'t be told. '
        'You can unblock them from the community menu.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    await CommunityService().blockUser(userId);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not block. Please try again.')),
      );
    }
    return false;
  }
}

Future<bool> confirmDelete(BuildContext context, String what) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete this $what?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
