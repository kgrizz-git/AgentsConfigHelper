import 'package:agents_config_helper/schemas/kiro_permissions.dart';
import 'package:agents_config_helper/widgets/kiro_permissions_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  KiroPermissionsPresentation presentation({
    List<KiroPermissionRule> rules = const [],
    bool hasUnclassifiedSettings = false,
  }) {
    return KiroPermissionsPresentation(
      rules: rules,
      hasUnclassifiedSettings: hasUnclassifiedSettings,
    );
  }

  testWidgets(
    'renders stored rules, effects, patterns, and help',
    (tester) async {
      final value = presentation(
        rules: [
          KiroPermissionRule(
            capability: 'shell',
            effect: 'allow',
            match: const ['git *', 'npm *'],
            exclude: const ['git push *'],
          ),
          KiroPermissionRule(
            capability: 'fs_read',
            effect: 'deny',
          ),
          KiroPermissionRule(
            capability: 'web_fetch',
            effect: 'evaluate',
            match: const [],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KiroPermissionsCard(presentation: value),
            ),
          ),
        ),
      );

      expect(find.text('Kiro permissions'), findsOneWidget);
      expect(find.text(KiroPermissionsHelp.policy.description), findsOneWidget);
      expect(
        find.text(KiroPermissionsHelp.readOnly.description),
        findsOneWidget,
      );
      expect(find.text('Shell'), findsOneWidget);
      expect(find.text('shell'), findsOneWidget);
      expect(find.text('allow'), findsOneWidget);
      expect(find.text('Match (2)'), findsOneWidget);
      expect(find.text('• git *'), findsOneWidget);
      expect(find.text('• npm *'), findsOneWidget);
      expect(find.text('Exclude (1)'), findsOneWidget);
      expect(find.text('• git push *'), findsOneWidget);
      expect(find.text('Filesystem read'), findsOneWidget);
      expect(find.text('deny'), findsOneWidget);
      expect(find.text('Web fetch'), findsOneWidget);
      expect(find.text('evaluate'), findsOneWidget);
      expect(find.text('No patterns.'), findsOneWidget);
      expect(find.text('Not set.'), findsNWidgets(3));
      expect(find.text(KiroPermissionsHelp.rule.description), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows the empty state and an unclassified notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KiroPermissionsCard(
            presentation: presentation(hasUnclassifiedSettings: true),
          ),
        ),
      ),
    );

    expect(
      find.text('No Kiro permission rules are stored in this file.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Additional Kiro permission settings are available only in raw '
        'content.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('opens capability and effect help dialogs', (tester) async {
    final value = presentation(
      rules: [
        KiroPermissionRule(capability: 'shell', effect: 'allow'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KiroPermissionsCard(presentation: value),
          ),
        ),
      ),
    );

    final capabilityTooltip = KiroPermissionsHelp.capability('shell')
        .description;
    await tester.tap(find.byTooltip(capabilityTooltip).first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(capabilityTooltip), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final effectTooltip = KiroPermissionsHelp.effect('allow').description;
    await tester.tap(find.byTooltip(effectTooltip).first);
    await tester.pumpAndSettle();
    expect(find.text(effectTooltip), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the documentation through the injected launcher', (
    tester,
  ) async {
    Uri? openedUri;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KiroPermissionsCard(
            presentation: presentation(
              rules: [
                KiroPermissionRule(capability: 'shell', effect: 'allow'),
              ],
            ),
            onOpenDocumentation: (uri) async {
              openedUri = uri;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.text('Kiro permissions documentation'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiro permissions documentation'));
    await tester.pump();

    expect(openedUri, KiroPermissionsAdapter.documentationUri);
  });

  testWidgets('shows feedback when documentation cannot be opened', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KiroPermissionsCard(
            presentation: presentation(
              rules: [
                KiroPermissionRule(capability: 'shell', effect: 'allow'),
              ],
            ),
            onOpenDocumentation: (_) async => false,
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.text('Kiro permissions documentation'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiro permissions documentation'));
    await tester.pump();

    expect(
      find.text('Unable to open Kiro permissions documentation.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('handles a documentation failure without a scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KiroPermissionsCard(
          presentation: presentation(
            rules: [
              KiroPermissionRule(capability: 'shell', effect: 'allow'),
            ],
          ),
          onOpenDocumentation: (_) async => throw StateError('launcher failed'),
        ),
      ),
    );

    await tester.tap(find.text('Kiro permissions documentation'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps headers and rules within a narrow, scaled layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KiroPermissionsCard(
                presentation: presentation(
                  rules: [
                    KiroPermissionRule(
                      capability: 'sandbox_network',
                      effect: 'evaluate',
                      match: const ['api.example.com'],
                      exclude: const [],
                    ),
                    KiroPermissionRule(
                      capability: 'fs_write',
                      effect: 'deny',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('offers no write or edit controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KiroPermissionsCard(
            presentation: presentation(
              rules: [
                KiroPermissionRule(capability: 'shell', effect: 'allow'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Add Item'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
