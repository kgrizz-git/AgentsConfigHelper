import 'package:agents_config_helper/schemas/cursor_permissions.dart';
import 'package:agents_config_helper/widgets/cursor_permissions_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CursorPermissionsPresentation presentation({
    List<String>? mcpAllowlist,
    List<String>? terminalAllowlist,
    List<String>? allowInstructions,
    List<String>? blockInstructions,
    bool hasUnclassifiedSettings = false,
  }) {
    return CursorPermissionsPresentation(
      mcpAllowlist: mcpAllowlist,
      terminalAllowlist: terminalAllowlist,
      allowInstructions: allowInstructions,
      blockInstructions: blockInstructions,
      hasUnclassifiedSettings: hasUnclassifiedSettings,
    );
  }

  testWidgets(
    'renders a read-only policy and opens documentation through callback',
    (tester) async {
      Uri? openedUri;
      final value = presentation(
        mcpAllowlist: const ['github:*', 'linear:list_issues'],
        terminalAllowlist: const ['git'],
        allowInstructions: const ['Read-only inspections are fine.'],
        blockInstructions: const [],
        hasUnclassifiedSettings: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CursorPermissionsCard(
                presentation: value,
                onOpenDocumentation: (uri) async {
                  openedUri = uri;
                  return true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Cursor Agent permissions'), findsOneWidget);
      expect(find.text('MCP allowlist (2)'), findsOneWidget);
      expect(find.text('Terminal allowlist (1)'), findsOneWidget);
      expect(find.text('Allow instructions (1)'), findsOneWidget);
      expect(find.text('Block instructions (0)'), findsOneWidget);
      expect(find.text('• github:*'), findsOneWidget);
      expect(
        find.text(
          'Additional permission settings are available only in raw content.',
        ),
        findsOneWidget,
      );

      expect(
        find.byTooltip(CursorPermissionsHelp.mcpAllowlist.description),
        findsOneWidget,
      );

      await tester.tap(
        find.byTooltip(CursorPermissionsHelp.mcpAllowlist.description),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable,
        isTrue,
      );
      expect(
        find.text(
          'Lists MCP server:tool patterns declared in this file. '
          'Cursor decides how these match MCP calls at runtime.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Lists MCP server:tool patterns declared in this file. '
          'Cursor decides how these match MCP calls at runtime.',
        ),
        findsNothing,
      );

      await tester.ensureVisible(
        find.text('Cursor Agent permissions documentation'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cursor Agent permissions documentation'));
      await tester.pump();

      expect(openedUri, CursorPermissionsAdapter.documentationUri);
    },
  );

  testWidgets(
    'distinguishes omitted, explicitly empty, and populated fields',
    (tester) async {
      final value = presentation(
        mcpAllowlist: const ['github:*'],
        allowInstructions: const [],
        blockInstructions: const ['Pause delete operations for review.'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CursorPermissionsCard(presentation: value),
          ),
        ),
      );

      expect(find.text('MCP allowlist (1)'), findsOneWidget);
      expect(find.text('Terminal allowlist'), findsOneWidget);
      expect(find.text('Not set.'), findsOneWidget);
      expect(find.text('Allow instructions (0)'), findsOneWidget);
      expect(find.text('No entries.'), findsOneWidget);
      expect(find.text('Block instructions (1)'), findsOneWidget);
      expect(
        find.text('• Pause delete operations for review.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Additional permission settings are available only in raw content.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets('keeps headers within a narrow, scaled layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CursorPermissionsCard(
                presentation: presentation(
                  mcpAllowlist: const ['github:*'],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows feedback when documentation cannot be opened', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CursorPermissionsCard(
            presentation: presentation(),
            onOpenDocumentation: (_) async => false,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cursor Agent permissions documentation'));
    await tester.pump();

    expect(
      find.text('Unable to open Cursor Agent permissions documentation.'),
      findsOneWidget,
    );
  });

  testWidgets('handles a documentation failure without a scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CursorPermissionsCard(
          presentation: presentation(),
          onOpenDocumentation: (_) async => false,
        ),
      ),
    );

    await tester.tap(find.text('Cursor Agent permissions documentation'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
