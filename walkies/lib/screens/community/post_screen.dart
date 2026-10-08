import 'package:flutter/material.dart';
import 'package:walkies/constants/app_colors.dart';
import 'package:walkies/models/community.dart';
import 'package:walkies/screens/community/community_widgets.dart';
import 'package:walkies/services/community_service.dart';

/// A post with its comments and a reply box. Pops with true if the post
/// was deleted or its author blocked (so the feed should refresh).
class PostScreen extends StatefulWidget {
  final CommunityPost post;
  final bool canComment;

  const PostScreen({super.key, required this.post, required this.canComment});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _service = CommunityService();
  final _replyController = TextEditingController();
  late CommunityPost _post = widget.post;
  List<CommunityComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _feedChanged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.getPost(_post.id),
        _service.getComments(_post.id),
      ]);
      if (!mounted) return;
      final post = results[0] as CommunityPost?;
      if (post == null) {
        // Removed, or its author has been blocked
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _post = post;
        _comments = results[1] as List<CommunityComment>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load replies.')),
      );
    }
  }

  Future<void> _toggleReaction() async {
    final reacted = !_post.reactedByMe;
    setState(() {
      _post = _post.copyWith(
        reactedByMe: reacted,
        reactionCount: _post.reactionCount + (reacted ? 1 : -1),
      );
      _feedChanged = true;
    });
    try {
      await _service.setReaction(_post.id, reacted);
    } catch (_) {
      await _load();
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await _service.addComment(_post.id, text);
      _replyController.clear();
      _feedChanged = true;
      await _load();
    } on CommunityRateLimitException {
      _snack('You\'re replying very quickly. Please wait a while and try again.');
    } catch (e) {
      _snack('Could not send your reply. Please try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _onPostAction(ItemAction action) async {
    switch (action) {
      case ItemAction.report:
        await showReportSheet(context, postId: _post.id);
      case ItemAction.block:
        if (await confirmBlock(context,
                userId: _post.authorId, name: _post.authorName) &&
            mounted) {
          Navigator.of(context).pop(true);
        }
      case ItemAction.delete:
        if (!await confirmDelete(context, 'post')) return;
        try {
          await _service.deletePost(_post.id);
          if (mounted) Navigator.of(context).pop(true);
        } catch (_) {
          _snack('Could not delete. Please try again.');
        }
    }
  }

  Future<void> _onCommentAction(CommunityComment comment, ItemAction action) async {
    switch (action) {
      case ItemAction.report:
        await showReportSheet(context, commentId: comment.id);
      case ItemAction.block:
        if (await confirmBlock(context,
            userId: comment.authorId, name: comment.authorName)) {
          _feedChanged = true;
          await _load();
        }
      case ItemAction.delete:
        if (!await confirmDelete(context, 'reply')) return;
        try {
          await _service.deleteComment(comment.id);
          _feedChanged = true;
          await _load();
        } catch (_) {
          _snack('Could not delete. Please try again.');
        }
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final me = _service.currentUserId;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_feedChanged);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Post')),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    PostCard(
                      post: _post,
                      isMine: _post.authorId == me,
                      onToggleReaction: _toggleReaction,
                      onAction: _onPostAction,
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('No replies yet.',
                              style: TextStyle(color: AppColors.muted)),
                        ),
                      )
                    else
                      for (final c in _comments)
                        _CommentTile(
                          comment: c,
                          isMine: c.authorId == me,
                          onAction: (a) => _onCommentAction(c, a),
                        ),
                  ],
                ),
              ),
            ),
            if (widget.canComment)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Write a reply',
                            counterText: '',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isSending ? null : _sendReply,
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send, color: AppColors.forest),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommunityComment comment;
  final bool isMine;
  final ValueChanged<ItemAction> onAction;

  const _CommentTile({
    required this.comment,
    required this.isMine,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 16),
      padding: const EdgeInsets.fromLTRB(12, 6, 0, 10),
      decoration: BoxDecoration(
        color: AppColors.sand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${comment.authorName} · ${timeAgo(comment.createdAt)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              ItemMenu(isMine: isMine, onSelected: onAction),
            ],
          ),
          if (comment.isHidden)
            const Text(
              'Hidden while a moderator reviews reports. Only you can see it.',
              style: TextStyle(fontSize: 12, color: AppColors.accent),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(comment.body, style: const TextStyle(height: 1.45)),
          ),
        ],
      ),
    );
  }
}
