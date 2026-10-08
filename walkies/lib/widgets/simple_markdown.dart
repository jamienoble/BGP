import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walkies/constants/app_colors.dart';

/// Renders the small Markdown subset editors use in the CMS:
/// '#'/'##'/'###' headings, '-'/'*' and '1.' lists, paragraphs separated by
/// blank lines, **bold** and [links](https://...).
class SimpleMarkdown extends StatelessWidget {
  final String text;

  const SimpleMarkdown(this.text, {super.key});

  static final _inline = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)\s]+)\)');
  static final _ordered = RegExp(r'^(\d+)\.\s+');

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(_textBlock(paragraph.join(' '), _bodyStyle));
      paragraph.clear();
    }

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) {
        flushParagraph();
      } else if (trimmed.startsWith('### ')) {
        flushParagraph();
        blocks.add(_textBlock(trimmed.substring(4), _h3Style));
      } else if (trimmed.startsWith('## ')) {
        flushParagraph();
        blocks.add(_textBlock(trimmed.substring(3), _h2Style));
      } else if (trimmed.startsWith('# ')) {
        flushParagraph();
        blocks.add(_textBlock(trimmed.substring(2), _h1Style));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        flushParagraph();
        blocks.add(_listItem('•', trimmed.substring(2)));
      } else if (_ordered.hasMatch(trimmed)) {
        flushParagraph();
        final match = _ordered.firstMatch(trimmed)!;
        blocks.add(
          _listItem('${match.group(1)}.', trimmed.substring(match.end)),
        );
      } else {
        paragraph.add(trimmed);
      }
    }
    flushParagraph();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  static const _bodyStyle = TextStyle(
      fontFamily: 'Inter', fontSize: 16.5, height: 1.65, color: AppColors.bodyText);
  static const _h1Style = TextStyle(
      fontFamily: 'Fraunces', fontSize: 26, height: 1.2, fontWeight: FontWeight.w600, color: AppColors.forest);
  static const _h2Style = TextStyle(
      fontFamily: 'Fraunces', fontSize: 22, height: 1.25, fontWeight: FontWeight.w600, color: AppColors.forest);
  static const _h3Style = TextStyle(
      fontFamily: 'Inter', fontSize: 17, height: 1.3, fontWeight: FontWeight.w700, color: AppColors.forest);

  Widget _textBlock(String text, TextStyle style) => Padding(
        padding: EdgeInsets.only(
          bottom: 14,
          top: identical(style, _bodyStyle) ? 0 : 10,
        ),
        child: Text.rich(TextSpan(style: style, children: _spans(text))),
      );

  Widget _listItem(String marker, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Text(
                marker,
                style: _bodyStyle.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(style: _bodyStyle, children: _spans(text)),
              ),
            ),
          ],
        ),
      );

  List<InlineSpan> _spans(String text) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else {
        final url = Uri.tryParse(m.group(3)!);
        spans.add(TextSpan(
          text: m.group(2),
          style: const TextStyle(
            color: AppColors.forest,
            decoration: TextDecoration.underline,
          ),
          recognizer: url == null || !url.hasScheme
              ? null
              : (TapGestureRecognizer()
                ..onTap = () =>
                    launchUrl(url, mode: LaunchMode.externalApplication)),
        ));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }
}
