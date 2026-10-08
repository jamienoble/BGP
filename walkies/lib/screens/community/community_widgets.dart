import 'package:flutter/material.dart';
import 'package:walkies/theme/app_theme.dart';
import 'package:walkies/widgets/ui.dart';
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
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialAvatar(post.authorName, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMine ? '${post.authorName} (you)' : post.authorName,
                      style: text.titleSmall,
                    ),
                    Text(
                      '${timeAgo(post.createdAt)} ago'
                      '${post.editedAt != null ? ' · edited' : ''}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              ItemMenu(isMine: isMine, onSelected: onAction),
            ],
          ),
          if (post.isHidden)
            const Padding(
              padding: EdgeInsets.only(top: 10, right: 10),
              child: Pill(
                'Hidden while a moderator reviews reports',
                icon: Icons.visibility_off_outlined,
                background: AppPalette.warnSoft,
                foreground: AppPalette.warn,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 12, 12, 10),
            child: Text(
              post.body,
              style: text.bodyLarge!.copyWith(color: AppPalette.ink, height: 1.5),
            ),
          ),
          Row(
            children: [
              _ActionChip(
                icon: post.reactedByMe
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: post.reactionCount > 0 ? '${post.reactionCount}' : 'Support',
                active: post.reactedByMe,
                onTap: onToggleReaction,
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.mode_comment_outlined,
                label: post.commentCount > 0
                    ? '${post.commentCount} ${post.commentCount == 1 ? 'reply' : 'replies'}'
                    : 'Reply',
                onTap: onTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? const Color(0xFFB4532A) : AppPalette.muted;
    return Material(
      color: active ? AppPalette.terracottaSoft : AppPalette.cream,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
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
      icon: const Icon(Icons.more_horiz_rounded, color: AppPalette.muted),
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
            child: Text('Why are you reporting this?', style: TextStyle(
              fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w600)),
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
