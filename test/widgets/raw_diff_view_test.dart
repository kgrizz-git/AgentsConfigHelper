import 'package:agents_config_helper/widgets/raw_diff_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RawDiffView', () {
    testWidgets('renders before and after labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RawDiffView(original: 'old content', updated: 'new content'),
          ),
        ),
      );

      expect(find.text('Before:'), findsOneWidget);
      expect(find.text('After:'), findsOneWidget);
      expect(find.text('old content'), findsOneWidget);
      expect(find.text('new content'), findsOneWidget);
    });

    testWidgets('shows empty placeholder for empty content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RawDiffView(original: '', updated: ''),
          ),
        ),
      );

      expect(find.text('(Empty)'), findsNWidgets(2));
    });

    testWidgets('truncates long content and shows expand button', (
      tester,
    ) async {
      final longContent = List.generate(25, (i) => 'line $i').join('\n');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RawDiffView(
                original: longContent,
                updated: 'short',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Show full content'), findsOneWidget);
      expect(find.text('Show less'), findsNothing);
    });

    testWidgets('toggle expands content', (tester) async {
      final longContent = List.generate(25, (i) => 'line $i').join('\n');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RawDiffView(
                original: longContent,
                updated: 'short',
              ),
            ),
          ),
        ),
      );

      // Initially truncated — button says "Show full content".
      expect(find.text('Show full content'), findsOneWidget);

      // Tap to expand.
      await tester.tap(find.text('Show full content'));
      await tester.pump();

      // Now shows "Show less".
      expect(find.text('Show less'), findsOneWidget);
    });
  });
}
