import 'package:flutter/material.dart';
import 'package:walkies/config/app_config.dart';
import 'package:walkies/constants/app_colors.dart';
import 'package:walkies/models/content.dart';
import 'package:walkies/screens/education/article_screen.dart';
import 'package:walkies/screens/education/video_screen.dart';
import 'package:walkies/services/content_service.dart';

/// Education tab: the latest news summary, then articles and videos
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Women\'s Health Insights',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          if (_news != null) ...[
            _NewsCard(article: _news!, onTap: () => _open(_news!)),
            const SizedBox(height: 20),
          ],
          if (_categories.isNotEmpty) _categoryChips(),
          const SizedBox(height: 12),
          ..._body(),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All', null),
          for (final c in _categories) _chip(c.name, c.id),
        ],
      ),
    );
  }

  Widget _chip(String label, String? id) {
    final selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _selectCategory(id),
        selectedColor: AppColors.sage,
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }

  List<Widget> _body() {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_hasError) {
      return [
        _Message(
          text: 'Could not load content. Check your connection.',
          action: TextButton(onPressed: _load, child: const Text('Try again')),
        ),
      ];
    }
    if (_items.isEmpty) {
      return const [_Message(text: 'New articles and videos are on the way.')];
    }
    return [
      for (final item in _items)
        _ContentCard(
          item: item,
          progress: _progress['${item.contentType}:${item.id}'],
          onTap: () => _open(item),
        ),
    ];
  }
}

class _NewsCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;

  const _NewsCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.sage,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.health_and_safety,
                        color: AppColors.forest, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Latest in Women\'s Health',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        Text(
                          article.sourceName != null
                              ? 'Summary of ${article.sourceName}'
                              : 'News summary',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              if (article.summary != null) ...[
                const SizedBox(height: 6),
                Text(
                  article.summary!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.bodyText,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Read more',
                style: TextStyle(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final ContentItem item;
  final ContentProgress? progress;
  final VoidCallback onTap;

  const _ContentCard({
    required this.item,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppConfig.imageUrl(item.imageRef);
    final video = item is Video ? item as Video : null;
    final duration = video?.durationSeconds;
    final fraction = (duration != null && duration > 0 && progress != null)
        ? (progress!.completed ? 1.0 : progress!.progressSeconds / duration)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                          errorBuilder: (_, _, _) => _placeholder(video),
                        )
                      : _placeholder(video),
                  if (video != null)
                    const Center(
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.play_arrow,
                            color: Colors.white, size: 32),
                      ),
                    ),
                  if (duration != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (fraction != null)
              LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 3,
                color: AppColors.accent,
                backgroundColor: AppColors.sand,
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video != null ? 'VIDEO' : 'ARTICLE',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  if (item.summary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.bodyText),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(Video? video) => Container(
        color: AppColors.sage,
        child: Icon(
          video != null ? Icons.ondemand_video : Icons.article_outlined,
          color: AppColors.forest,
          size: 40,
        ),
      );
}

class _Message extends StatelessWidget {
  final String text;
  final Widget? action;

  const _Message({required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          ?action,
        ],
      ),
    );
  }
}

String _formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
