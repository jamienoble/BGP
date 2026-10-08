import 'package:flutter/material.dart';
import 'package:walkies/theme/app_theme.dart';
import 'package:walkies/widgets/ui.dart';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not load replies.')));
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
      _snack(
        'You\'re replying very quickly. Please wait a while and try again.',
      );
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
        if (await confirmBlock(
              context,
              userId: _post.authorId,
              name: _post.authorName,
            ) &&
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

  Future<void> _onCommentAction(
    CommunityComment comment,
    ItemAction action,
  ) async {
    switch (action) {
      case ItemAction.report:
        await showReportSheet(context, commentId: comment.id);
      case ItemAction.block:
        if (await confirmBlock(
          context,
          userId: comment.authorId,
          name: comment.authorName,
        )) {
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
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    PostCard(
                      post: _post,
                      isMine: _post.authorId == me,
                      onToggleReaction: _toggleReaction,
                      onAction: _onPostAction,
                    ),
                    const SizedBox(height: 20),
                    SectionLabel(
                      _comments.isEmpty
                          ? 'Replies'
                          : '${_comments.length} ${_comments.length == 1 ? 'reply' : 'replies'}',
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_comments.isEmpty)
                      const EmptyState(
                        icon: Icons.mode_comment_outlined,
                        title: 'No replies yet',
                        message: 'Say something kind to get things going.',
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
              Container(
                decoration: const BoxDecoration(
                  color: AppPalette.white,
                  border: Border(top: BorderSide(color: AppPalette.line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 2000,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Write a supportive reply',
                              counterText: '',
                              isDense: true,
                              fillColor: AppPalette.cream,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: AppPalette.forest,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isSending ? null : _sendReply,
                          style: IconButton.styleFrom(
                            backgroundColor: AppPalette.forest,
                            foregroundColor: Colors.white,
                            fixedSize: const Size(46, 46),
                          ),
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_upward_rounded),
                        ),
                      ],
                    ),
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
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialAvatar(comment.authorName, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 2, 12),
              decoration: BoxDecoration(
                color: isMine ? AppPalette.sage : AppPalette.white,
                border: isMine ? null : Border.all(color: AppPalette.line),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: isMine ? 'You' : comment.authorName,
                                style: text.titleSmall,
                              ),
                              TextSpan(
                                text: '  ${timeAgo(comment.createdAt)} ago',
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        child: ItemMenu(isMine: isMine, onSelected: onAction),
                      ),
                    ],
                  ),
                  if (comment.isHidden)
                    Text(
                      'Hidden while a moderator reviews reports.',
                      style: text.bodySmall!.copyWith(color: AppPalette.warn),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      comment.body,
                      style: text.bodyMedium!.copyWith(color: AppPalette.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
