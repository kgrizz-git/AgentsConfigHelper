import 'package:agents_config_helper/schemas/claude_code_permissions.dart';
import 'package:agents_config_helper/widgets/claude_code_permissions_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders a read-only policy and opens documentation through callback',
    (
      tester,
    ) async {
      Uri? openedUri;
      final presentation = ClaudeCodePermissionsPresentation(
        defaultMode: 'default',
        allow: const ['Read(./fixtures/**)'],
        ask: const ['Bash(git status)'],
        deny: const ['Read(./private/**)'],
        hasConfiguredPolicy: true,
        hasUnclassifiedSettings: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClaudeCodePermissionsCard(
              presentation: presentation,
              onOpenDocumentation: (uri) async {
                openedUri = uri;
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Claude Code permissions'), findsOneWidget);
      expect(find.text('Default mode: default'), findsOneWidget);
      expect(find.text('Allow (1)'), findsOneWidget);
      expect(find.text('Ask (1)'), findsOneWidget);
      expect(find.text('Deny (1)'), findsOneWidget);
      expect(find.text('• Read(./fixtures/**)'), findsOneWidget);
      expect(
        find.text(
          'Additional permission settings are available only in raw content.',
        ),
        findsOneWidget,
      );

      expect(
        find.byTooltip(ClaudeCodePermissionsHelp.defaultMode.description),
        findsOneWidget,
      );

      await tester.tap(
        find.byTooltip(ClaudeCodePermissionsHelp.allow.description),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Lists rules that pre-approve matching actions.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(
        find.text('Lists rules that pre-approve matching actions.'),
        findsNothing,
      );

      await tester.tap(find.text('Claude Code permissions documentation'));
      await tester.pump();

      expect(openedUri, ClaudeCodePermissionsAdapter.documentationUri);
    },
  );

  testWidgets('shows feedback when documentation cannot be opened', (
    tester,
  ) async {
    final presentation = ClaudeCodePermissionsPresentation(
      defaultMode: null,
      allow: const [],
      ask: const [],
      deny: const [],
      hasConfiguredPolicy: false,
      hasUnclassifiedSettings: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClaudeCodePermissionsCard(
            presentation: presentation,
            onOpenDocumentation: (_) async => false,
          ),
        ),
      ),
    );

    expect(
      find.textContaining('No Claude Code permissions policy is configured'),
      findsOneWidget,
    );

    await tester.tap(find.text('Claude Code permissions documentation'));
    await tester.pump();

    expect(
      find.text('Unable to open Claude Code permissions documentation.'),
      findsOneWidget,
    );
  });

  testWidgets('handles a documentation failure without a scaffold', (
    tester,
  ) async {
    final presentation = ClaudeCodePermissionsPresentation(
      defaultMode: null,
      allow: const [],
      ask: const [],
      deny: const [],
      hasConfiguredPolicy: false,
      hasUnclassifiedSettings: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClaudeCodePermissionsCard(
          presentation: presentation,
          onOpenDocumentation: (_) async => false,
        ),
      ),
    );

    await tester.tap(find.text('Claude Code permissions documentation'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
