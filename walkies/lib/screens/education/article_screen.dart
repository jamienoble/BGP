import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walkies/config/app_config.dart';
import 'package:walkies/constants/app_colors.dart';
import 'package:walkies/models/content.dart';
import 'package:walkies/services/content_service.dart';
import 'package:walkies/widgets/simple_markdown.dart';

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
        .catchError((Object e) => debugPrint('Could not save view: $e'));
  }

  Future<void> _openSource() async {
    final url = Uri.tryParse(widget.article.sourceUrl ?? '');
    if (url == null) return;
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final imageUrl = AppConfig.imageUrl(article.coverImage, width: 1200);
    final date = article.sortDate;

    return Scaffold(
      appBar: AppBar(title: Text(article.isNews ? 'News' : 'Article')),
      body: ListView(
        children: [
          if (imageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (article.authorName != null) article.authorName!,
                    '${date.day}/${date.month}/${date.year}',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                if (article.body != null && article.body!.trim().isNotEmpty)
                  SimpleMarkdown(article.body!)
                else if (article.summary != null)
                  SimpleMarkdown(article.summary!),
                if (article.sourceUrl != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openSource,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      'Read the original${article.sourceName != null ? ' at ${article.sourceName}' : ''}',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const _Disclaimer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'General information, not medical advice. If you are worried about '
        'your health, speak to your GP or pharmacist, or call NHS 111. '
        'In an emergency, call 999.',
        style: TextStyle(fontSize: 13, color: AppColors.bodyText),
      ),
    );
  }
}
