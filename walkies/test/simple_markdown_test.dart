import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkies/widgets/simple_markdown.dart';

void main() {
  testWidgets('renders headings, lists, paragraphs and bold', (tester) async {
    const text = '''
## Why walk?

Walking **daily** helps.
It is free.

- Better sleep
- Better mood

1. Start small
''';
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SimpleMarkdown(text))),
    );

    expect(find.text('Why walk?'), findsOneWidget);
    // Consecutive lines join into one paragraph
    expect(find.text('Walking daily helps. It is free.', findRichText: true),
        findsOneWidget);
    expect(find.text('Better sleep', findRichText: true), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('1.'), findsOneWidget);
  });
}
