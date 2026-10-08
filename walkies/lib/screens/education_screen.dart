import 'package:flutter/material.dart';
import 'package:walkies/config/app_config.dart';
import 'package:walkies/models/content.dart';
import 'package:walkies/screens/education/article_screen.dart';
import 'package:walkies/screens/education/video_screen.dart';
import 'package:walkies/services/content_service.dart';
import 'package:walkies/theme/app_theme.dart';
import 'package:walkies/widgets/ui.dart';

/// Learn (Education) tab: the latest news summary, then articles and videos
/// published from the CMS, filterable by category.
class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final _contentService = ContentService();

  List<ContentCategory> _categories = [];
  List<ContentItem> _items = [];
  Article? _news;
  Map<String, ContentProgress> _progress = {};
  String? _selectedCategoryId;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _hasError = false;
    });
    try {
      final results = await Future.wait([
        _contentService.getCategories(),
        _contentService.getFeed(categoryId: _selectedCategoryId),
        _contentService.getLatestNews(),
        _contentService.getProgress(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<ContentCategory>;
        _items = results[1] as List<ContentItem>;
        _news = results[2] as Article?;
        _progress = results[3] as Map<String, ContentProgress>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading education content: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _selectCategory(String? id) {
    if (id == _selectedCategoryId) return;
    setState(() {
      _selectedCategoryId = id;
      _isLoading = true;
    });
    _load();
  }

  Future<void> _open(ContentItem item) async {
    final route = item is Video
        ? MaterialPageRoute(
            builder: (_) => VideoScreen(
              video: item,
              startAt: _progress['video:${item.id}']?.progressSeconds ?? 0,
            ),
          )
        : MaterialPageRoute(
            builder: (_) => ArticleScreen(article: item as Article),
          );
    await Navigator.of(context).push(route);
    // Pick up new progress
    final progress = await _contentService.getProgress().catchError((_) => _progress);
    if (mounted) setState(() => _progress = progress);
  }

  String? _categoryName(String? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: AppSpacing.page,
        children: [
          Text('Women\'s health, explained', style: text.headlineLarge),
          const SizedBox(height: 6),
          Text(
            'Short reads and videos, checked by health professionals.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (_news != null) ...[
            _NewsCard(article: _news!, onTap: () => _open(_news!)),
            const SizedBox(height: 24),
          ],
          if (_categories.isNotEmpty) ...[
            _categoryChips(),
            const SizedBox(height: 16),
          ],
          ..._body(),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _chip('All', null),
          for (final c in _categories) _chip(c.name, c.id),
        ],
      ),
    );
  }

  Widget _chip(String label, String? id) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedCategoryId == id,
        onSelected: (_) => _selectCategory(id),
      ),
    );
  }

  List<Widget> _body() {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_hasError) {
      return [
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load content',
          message: 'Check your connection and try again.',
          action: OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ),
      ];
    }
    if (_items.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.auto_stories_outlined,
          title: 'More on the way',
          message: 'New articles and videos are added every week.',
        ),
      ];
    }
    return [
      for (final item in _items) ...[
        _ContentCard(
          item: item,
          categoryName: _categoryName(item.categoryId),
          progress: _progress['${item.contentType}:${item.id}'],
          onTap: () => _open(item),
        ),
        const SizedBox(height: AppSpacing.gap),
      ],
    ];
  }
}

/// "6 min" for a video, "2 min read" for an article
String contentLength(ContentItem item) {
  if (item is Video) {
    final seconds = item.durationSeconds;
    return seconds == null ? 'Video' : '${(seconds / 60).ceil()} min';
  }
  final words = ((item as Article).body ?? item.summary ?? '')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .length;
  return '${(words / 200).ceil().clamp(1, 60)} min read';
}

/// "3h ago", "Yesterday", "4 Oct"
String relativeDate(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 2) return 'Yesterday';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]}';
}

class _NewsCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;

  const _NewsCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(Icons.newspaper_rounded, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  [
                    'LATEST NEWS',
                    if (article.sourceName != null) article.sourceName!.toUpperCase(),
                    relativeDate(article.sortDate).toUpperCase(),
                  ].join('  ·  '),
                  style: text.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(article.title, style: text.titleLarge),
          if (article.summary != null) ...[
            const SizedBox(height: 8),
            Text(
              article.summary!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Read summary',
                style: text.labelLarge!.copyWith(color: AppPalette.forest),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 18, color: AppPalette.forest),
              const Spacer(),
              if (article.isAiDrafted)
                const Pill('Reviewed summary', icon: Icons.verified_outlined),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final ContentItem item;
  final String? categoryName;
  final ContentProgress? progress;
  final VoidCallback onTap;

  const _ContentCard({
    required this.item,
    required this.categoryName,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final imageUrl = AppConfig.imageUrl(item.imageRef);
    final isVideo = item is Video;
    final duration = isVideo ? (item as Video).durationSeconds : null;
    final fraction = (duration != null && duration > 0 && progress != null)
        ? (progress!.completed ? 1.0 : progress!.progressSeconds / duration)
        : null;
    final artwork = ArtworkPlaceholder(
      seed: item.categoryId ?? item.id,
      icon: isVideo ? Icons.play_lesson_outlined : Icons.menu_book_rounded,
      iconSize: 52,
    );

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => artwork,
                      )
                    : artwork,
                Positioned(
                  left: 12,
                  top: 12,
                  child: Pill(
                    '${isVideo ? 'Video' : 'Article'} · ${contentLength(item)}',
                    icon: isVideo ? Icons.play_arrow_rounded : Icons.article_outlined,
                    background: AppPalette.white,
                  ),
                ),
                if (isVideo)
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 16),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          size: 36, color: AppPalette.forest),
                    ),
                  ),
                if (fraction != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.0, 1.0),
                      minHeight: 4,
                      color: AppPalette.terracotta,
                      backgroundColor: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (categoryName != null) ...[
                  Text(categoryName!.toUpperCase(), style: text.labelSmall),
                  const SizedBox(height: 6),
                ],
                Text(item.title, style: text.titleLarge),
                if (item.summary != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium,
                  ),
                ],
                if (fraction != null && fraction < 1) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Continue watching',
                    style: text.labelMedium!.copyWith(color: AppPalette.terracotta),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
