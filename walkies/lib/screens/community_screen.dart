import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/theme/app_theme.dart';
import 'package:walkies/widgets/ui.dart';
import 'package:walkies/constants/app_constants.dart';
import 'package:walkies/constants/community_rules.dart';
import 'package:walkies/models/community.dart';
import 'package:walkies/screens/community/blocked_users_screen.dart';
import 'package:walkies/screens/community/community_widgets.dart';
import 'package:walkies/screens/community/new_post_screen.dart';
import 'package:walkies/screens/community/post_screen.dart';
import 'package:walkies/services/app_locker_service.dart';
import 'package:walkies/services/community_service.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/widgets/simple_markdown.dart';

enum _View { loading, error, locked, join, ready }

/// Community tab: join (18+, rules), then topic feeds with posts,
/// replies, support reactions, reporting and blocking. Can optionally be
/// locked until the daily step goal is met (Settings).
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with WidgetsBindingObserver {
  final _service = CommunityService();
  final _scrollController = ScrollController();
  StreamSubscription<int>? _stepSubscription;

  _View _view = _View.loading;
  int _stepsRemaining = 0;
  CommunityProfile? _profile;
  DateTime? _bannedUntil;
  List<CommunityTopic> _topics = [];
  CommunityTopic? _topic;
  List<CommunityPost> _posts = [];
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    // Re-check the lock as steps come in
    _stepSubscription = StepTrackingService().todayStepsStream.listen((_) {
      if (_view == _View.locked) _load();
    });
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _stepSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(AppConstants.prefCommunityLockedUntilGoal) ?? false) {
        final remaining = await AppLockerService().getStepsRemaining();
        if (remaining != null && remaining > 0) {
          if (mounted) {
            setState(() {
              _stepsRemaining = remaining;
              _view = _View.locked;
            });
          }
          return;
        }
      }

      final profile = await _service.getMyProfile();
      if (profile == null) {
        if (mounted) setState(() => _view = _View.join);
        return;
      }

      final results = await Future.wait([
        _service.getTopics(),
        _service.getMyRestriction(),
      ]);
      final topics = results[0] as List<CommunityTopic>;
      final topic = topics.isEmpty
          ? null
          : topics.firstWhere(
              (t) => t.id == _topic?.id,
              orElse: () => topics.firstWhere(
                (t) => !t.isLocked,
                orElse: () => topics.first,
              ),
            );
      final posts =
          topic == null ? <CommunityPost>[] : await _service.getPosts(topic.id);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _bannedUntil = results[1] as DateTime?;
        _topics = topics;
        _topic = topic;
        _posts = posts;
        _hasMore = posts.length >= CommunityService.pageSize;
        _view = _View.ready;
      });
    } catch (e) {
      debugPrint('Error loading community: $e');
      if (mounted && _view != _View.ready) setState(() => _view = _View.error);
    }
  }

  Future<void> _selectTopic(CommunityTopic topic) async {
    setState(() {
      _topic = topic;
      _posts = [];
      _hasMore = true;
    });
    await _load();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 400) _loadMore();
  }

  Future<void> _loadMore() async {
    final topic = _topic;
    if (_loadingMore || !_hasMore || topic == null || _posts.isEmpty) return;
    _loadingMore = true;
    try {
      final more =
          await _service.getPosts(topic.id, before: _posts.last.createdAt);
      if (!mounted) return;
      setState(() {
        _posts = [..._posts, ...more];
        _hasMore = more.length >= CommunityService.pageSize;
      });
    } catch (_) {
      // Try again on the next scroll
    } finally {
      _loadingMore = false;
    }
  }

  bool get _canPost =>
      _bannedUntil == null && _topic != null && !_topic!.isLocked;

  Future<void> _toggleReaction(CommunityPost post) async {
    final reacted = !post.reactedByMe;
    _replacePost(post.copyWith(
      reactedByMe: reacted,
      reactionCount: post.reactionCount + (reacted ? 1 : -1),
    ));
    try {
      await _service.setReaction(post.id, reacted);
    } catch (_) {
      _replacePost(post);
    }
  }

  void _replacePost(CommunityPost post) {
    setState(() {
      _posts = [for (final p in _posts) p.id == post.id ? post : p];
    });
  }

  Future<void> _onPostAction(CommunityPost post, ItemAction action) async {
    switch (action) {
      case ItemAction.report:
        await showReportSheet(context, postId: post.id);
      case ItemAction.block:
        if (await confirmBlock(context,
            userId: post.authorId, name: post.authorName)) {
          await _load();
        }
      case ItemAction.delete:
        if (!await confirmDelete(context, 'post')) return;
        try {
          await _service.deletePost(post.id);
          setState(() => _posts.removeWhere((p) => p.id == post.id));
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete. Please try again.')),
          );
        }
    }
  }

  Future<void> _openPost(CommunityPost post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PostScreen(post: post, canComment: _bannedUntil == null),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _newPost() async {
    final topic = _topic;
    if (topic == null) return;
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NewPostScreen(topic: topic)),
    );
    if (posted == true) await _load();
  }

  Future<void> _changeDisplayName() async {
    final controller = TextEditingController(text: _profile?.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.length < 2) return;
    try {
      await _service.updateDisplayName(name);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not change your name.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _View.loading:
        return const Center(child: CircularProgressIndicator());
      case _View.error:
        return Center(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Couldn\'t load the community',
            message: 'Check your connection and try again.',
            action: OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ),
        );
      case _View.locked:
        return Center(
          child: EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Unlocks at your goal',
            message: 'You chose to keep the community locked until you reach '
                'today\'s goal. ${formatNumber(_stepsRemaining)} steps to go.',
          ),
        );
      case _View.join:
        return _JoinCommunity(onJoined: _load);
      case _View.ready:
        return _feed();
    }
  }

  Widget _feed() {
    final text = Theme.of(context).textTheme;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Hi ${_profile?.displayName ?? 'there'}',
                          style: text.headlineLarge,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz_rounded),
                        onSelected: (value) {
                          if (value == 'rules') _showRules(context);
                          if (value == 'name') _changeDisplayName();
                          if (value == 'blocked') {
                            Navigator.of(context)
                                .push(MaterialPageRoute(
                                  builder: (_) => const BlockedUsersScreen(),
                                ))
                                .then((_) => _load());
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'rules', child: Text('Community rules')),
                          PopupMenuItem(value: 'name', child: Text('Change display name')),
                          PopupMenuItem(value: 'blocked', child: Text('Blocked people')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Text(
                    'Walking wins, questions and support from other members.',
                    style: text.bodyMedium,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      for (final t in _topics)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: t.isLocked
                                ? Icon(
                                    Icons.campaign_outlined,
                                    size: 18,
                                    color: t.id == _topic?.id
                                        ? Colors.white
                                        : AppPalette.muted,
                                  )
                                : null,
                            label: Text(t.name),
                            selected: t.id == _topic?.id,
                            onSelected: (_) => _selectTopic(t),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_bannedUntil != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: NoticeCard(
                      tone: NoticeTone.warning,
                      icon: Icons.block_rounded,
                      title: _bannedUntil!.year >= 9999
                          ? 'Your account can no longer post'
                          : 'Posting paused until '
                              '${_bannedUntil!.day}/${_bannedUntil!.month}/${_bannedUntil!.year}',
                      message: 'You can still read and react to posts.',
                    ),
                  ),
                ),
              if (_topic?.description != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Text(_topic!.description!, style: text.bodySmall),
                  ),
                ),
              if (_posts.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No posts yet',
                    message: _canPost
                        ? 'Be the first to share something here.'
                        : 'Check back soon.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                  sliver: SliverList.separated(
                    itemCount: _posts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final post = _posts[i];
                      return PostCard(
                        post: post,
                        isMine: post.authorId == _service.currentUserId,
                        onTap: () => _openPost(post),
                        onToggleReaction: () => _toggleReaction(post),
                        onAction: (a) => _onPostAction(post, a),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_canPost)
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton.extended(
              heroTag: 'new_post',
              onPressed: _newPost,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('New post'),
            ),
          ),
      ],
    );
  }
}

void _showRules(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: const [SimpleMarkdown(communityRules)],
      ),
    ),
  );
}

class _JoinCommunity extends StatefulWidget {
  final VoidCallback onJoined;

  const _JoinCommunity({required this.onJoined});

  @override
  State<_JoinCommunity> createState() => _JoinCommunityState();
}

class _JoinCommunityState extends State<_JoinCommunity> {
  final _nameController = TextEditingController();
  bool _isAdult = false;
  bool _acceptsRules = false;
  bool _isJoining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SupabaseService().getPreferredName().then((name) {
      if (mounted && name != null && _nameController.text.isEmpty) {
        _nameController.text = name;
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Display name needs at least 2 characters.');
      return;
    }
    setState(() {
      _isJoining = true;
      _error = null;
    });
    try {
      await CommunityService().createProfile(name);
      widget.onJoined();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not join. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canJoin = _isAdult && _acceptsRules && !_isJoining;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: AppSpacing.page,
      children: [
        const SizedBox(height: 8),
        const _CommunityHero(),
        const SizedBox(height: 22),
        Text('Walk together', style: text.headlineLarge),
        const SizedBox(height: 8),
        Text(
          'Share walking wins, swap routes and support each other. Other '
          'members see your display name, never your email.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 22),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  helperText: 'Doesn\'t need to be your real name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 4),
              _Agreement(
                value: _isAdult,
                onChanged: (v) => setState(() => _isAdult = v),
                title: 'I am 18 or over',
              ),
              _Agreement(
                value: _acceptsRules,
                onChanged: (v) => setState(() => _acceptsRules = v),
                title: 'I agree to the community rules',
                link: 'Read the rules',
                onLink: () => _showRules(context),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: text.bodySmall!.copyWith(color: AppPalette.danger),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canJoin ? _join : null,
                  child: _isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Join the community'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Agreement extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String? link;
  final VoidCallback? onLink;

  const _Agreement({
    required this.value,
    required this.onChanged,
    required this.title,
    this.link,
    this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall),
                  if (link != null)
                    GestureDetector(
                      onTap: onLink,
                      child: Text(
                        link!,
                        style: text.bodySmall!.copyWith(
                          color: AppPalette.forest,
                          decoration: TextDecoration.underline,
                          decorationColor: AppPalette.forest,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlapping member avatars around a walking icon
class _CommunityHero extends StatelessWidget {
  const _CommunityHero();

  @override
  Widget build(BuildContext context) {
    const names = ['Sophie', 'Aisha', 'Megan', 'Priya'];
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: AppPalette.sage,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.diversity_3_rounded,
                size: 56, color: AppPalette.forest),
          ),
          for (var i = 0; i < names.length; i++)
            Align(
              alignment: const [
                Alignment(-0.62, -0.7),
                Alignment(0.6, -0.85),
                Alignment(-0.48, 0.85),
                Alignment(0.66, 0.6),
              ][i],
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppPalette.cream,
                  shape: BoxShape.circle,
                ),
                child: InitialAvatar(names[i], size: 38),
              ),
            ),
        ],
      ),
    );
  }
}
