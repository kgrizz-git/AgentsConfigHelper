import 'package:agents_config_helper/schemas/opencode_permissions.dart';
import 'package:agents_config_helper/widgets/opencode_permissions_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OpencodePermissionsPresentation presentation({
    String? globalAction,
    Map<String, OpencodeToolPermission> tools = const {},
    bool hasConfiguredPermission = true,
  }) {
    return OpencodePermissionsPresentation(
      globalAction: globalAction,
      tools: tools,
      hasConfiguredPermission: hasConfiguredPermission,
    );
  }

  testWidgets(
    'renders a read-only policy and opens documentation through callback',
    (tester) async {
      Uri? openedUri;
      final value = presentation(
        globalAction: 'ask',
        tools: {
          'bash': OpencodeToolPermission(action: 'allow'),
          'edit': OpencodeToolPermission(
            patterns: const {
              '*': 'deny',
              'packages/web/src/content/docs/*.mdx': 'allow',
            },
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OpencodePermissionsCard(
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

      expect(find.text('Opencode permissions'), findsOneWidget);
      expect(find.text('Global'), findsOneWidget);
      expect(find.text('ask'), findsOneWidget);
      expect(find.text('bash'), findsOneWidget);
      expect(find.text('allow'), findsOneWidget);
      expect(find.text('edit (2)'), findsOneWidget);
      expect(find.text('• * → deny'), findsOneWidget);

      expect(
        find.byTooltip(
          OpencodePermissionsHelp.toolPermission('bash').description,
        ),
        findsNWidgets(2),
      );

      await tester.tap(
        find.byTooltip(
          OpencodePermissionsHelp.toolPermission('bash').description,
        ).first,
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable,
        isTrue,
      );
      expect(
        find.text(
          'The action or rules stored for this tool in this file. Opencode '
          'applies them at runtime; for granular pattern rules, the last '
          'matching rule wins.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The action or rules stored for this tool in this file. Opencode '
          'applies them at runtime; for granular pattern rules, the last '
          'matching rule wins.',
        ),
        findsNothing,
      );

      await tester.ensureVisible(
        find.text('Opencode permissions documentation'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Opencode permissions documentation'));
      await tester.pump();

      expect(openedUri, OpencodePermissionsAdapter.documentationUri);
    },
  );

  testWidgets('shows the exact empty state when no permission is configured', (
    tester,
  ) async {
    final value = presentation(hasConfiguredPermission: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OpencodePermissionsCard(presentation: value),
          ),
        ),
      ),
    );

    expect(
      find.textContaining(
        'No Opencode permissions policy is configured. Legacy tools settings '
        'are not shown.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps headers within a narrow, scaled layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OpencodePermissionsCard(
                presentation: presentation(
                  globalAction: 'allow',
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
    final value = presentation(globalAction: 'allow');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpencodePermissionsCard(
            presentation: value,
            onOpenDocumentation: (_) async => false,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Opencode permissions documentation'));
    await tester.pump();

    expect(
      find.text('Unable to open Opencode permissions documentation.'),
      findsOneWidget,
    );
  });

  testWidgets('handles a documentation failure without a scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OpencodePermissionsCard(
          presentation: presentation(globalAction: 'allow'),
          onOpenDocumentation: (_) async => false,
        ),
      ),
    );

    await tester.tap(find.text('Opencode permissions documentation'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
