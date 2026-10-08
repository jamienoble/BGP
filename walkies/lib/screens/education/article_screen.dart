import 'package:walkies/services/error_reporter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walkies/config/app_config.dart';
import 'package:walkies/models/content.dart';
import 'package:walkies/screens/education_screen.dart' show contentLength, relativeDate;
import 'package:walkies/services/content_service.dart';
import 'package:walkies/theme/app_theme.dart';
import 'package:walkies/widgets/simple_markdown.dart';
import 'package:walkies/widgets/ui.dart';

class ArticleScreen extends StatefulWidget {
  final Article article;

  const ArticleScreen({super.key, required this.article});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  @override
  void initState() {
    super.initState();
    ContentService()
        .saveProgress(
          contentType: 'article',
          contentId: widget.article.id,
          completed: true,
        )
        .catchError((Object e, StackTrace stack) =>
            ErrorReporter.report(e, stack, context: 'Could not save view'));
  }

  Future<void> _openSource() async {
    final url = Uri.tryParse(widget.article.sourceUrl ?? '');
    if (url == null) return;
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final text = Theme.of(context).textTheme;
    final imageUrl = AppConfig.imageUrl(article.coverImage, width: 1200);
    final artwork = ArtworkPlaceholder(
      seed: article.categoryId ?? article.id,
      icon: article.isNews ? Icons.newspaper_rounded : Icons.menu_book_rounded,
      iconSize: 64,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppPalette.cream,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  foregroundColor: AppPalette.ink,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => artwork,
                    )
                  : artwork,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Pill(
                        article.isNews ? 'News summary' : contentLength(article),
                        icon: article.isNews
                            ? Icons.newspaper_rounded
                            : Icons.schedule_rounded,
                      ),
                      if (article.isAiDrafted)
                        const Pill(
                          'Reviewed summary',
                          icon: Icons.verified_outlined,
                          background: AppPalette.sand,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(article.title, style: text.headlineMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (article.authorName != null) ...[
                        InitialAvatar(article.authorName!, size: 28),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          [
                            article.authorName ?? article.sourceName,
                            relativeDate(article.sortDate),
                          ].whereType<String>().join('  ·  '),
                          style: text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  if (article.body != null && article.body!.trim().isNotEmpty)
                    SimpleMarkdown(article.body!)
                  else if (article.summary != null)
                    SimpleMarkdown(article.summary!),
                  if (article.sourceUrl != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _openSource,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(
                        'Read the original${article.sourceName != null ? ' at ${article.sourceName}' : ''}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const HealthDisclaimer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HealthDisclaimer extends StatelessWidget {
  const HealthDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return const NoticeCard(
      tone: NoticeTone.info,
      icon: Icons.health_and_safety_outlined,
      title: 'General information, not medical advice',
      message: 'If you\'re worried about your health, speak to your GP or '
          'pharmacist, or call NHS 111. In an emergency, call 999.',
    );
  }
}
