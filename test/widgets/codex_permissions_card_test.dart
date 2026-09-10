import 'package:agents_config_helper/schemas/codex_permissions.dart';
import 'package:agents_config_helper/widgets/codex_permissions_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CodexPermissionsPresentation presentation({
    String? sandboxMode,
    String? approvalPolicy,
    String? defaultPermissions,
    List<CodexPermissionProfile>? profiles,
    bool hasSandboxWorkspaceWriteTable = false,
    bool hasConfiguredPermissions = true,
  }) {
    return CodexPermissionsPresentation(
      sandboxMode: sandboxMode,
      approvalPolicy: approvalPolicy,
      defaultPermissions: defaultPermissions,
      profiles: profiles,
      hasSandboxWorkspaceWriteTable: hasSandboxWorkspaceWriteTable,
      hasConfiguredPermissions: hasConfiguredPermissions,
    );
  }

  CodexPermissionProfile profile() {
    return CodexPermissionProfile(
      name: 'project-edit',
      description: 'Edits.',
      extendsProfile: ':workspace',
      workspaceRoots: const {'~/code/app': true},
      globScanMaxDepth: 3,
      filesystem: [
        CodexFilesystemEntry(path: ':minimal', access: 'read'),
        CodexFilesystemEntry(
          path: ':workspace_roots',
          subpaths: const {'.': 'write', '**/*.env': 'deny'},
        ),
      ],
      network: CodexNetworkPolicy(
        enabled: true,
        domains: const {'api.openai.com': 'allow'},
        unixSockets: const {'/var/run/docker.sock': 'allow'},
        allowLocalBinding: false,
      ),
    );
  }

  Future<void> pumpCard(
    WidgetTester tester,
    CodexPermissionsPresentation value, {
    void Function(Uri uri)? onOpen,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CodexPermissionsCard(
              presentation: value,
              onOpenDocumentation: onOpen == null
                  ? null
                  : (uri) async {
                      onOpen(uri);
                      return true;
                    },
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'renders stored entries and opens documentation through callback',
    (tester) async {
      Uri? openedUri;
      await pumpCard(
        tester,
        presentation(
          sandboxMode: 'workspace-write',
          approvalPolicy: 'on-request',
          defaultPermissions: 'project-edit',
          profiles: [profile()],
        ),
        onOpen: (uri) => openedUri = uri,
      );

      expect(find.text('Codex permissions'), findsOneWidget);
      expect(find.text('sandbox_mode → workspace-write'), findsOneWidget);
      expect(find.text('approval_policy → on-request'), findsOneWidget);
      expect(find.text('project-edit'), findsWidgets);
      expect(find.text('• :minimal → read'), findsOneWidget);
      expect(find.text('• . → write'), findsOneWidget);
      expect(find.text('• **/*.env → deny'), findsOneWidget);
      expect(find.text('• api.openai.com → allow'), findsOneWidget);
      expect(find.text('• /var/run/docker.sock → allow'), findsOneWidget);
      expect(find.text('glob_scan_max_depth → 3'), findsOneWidget);

      await tester.ensureVisible(
        find.text('Codex permissions documentation'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Codex permissions documentation'));
      await tester.pump();
      expect(
        openedUri,
        CodexPermissionsAdapter.documentationUri,
      );
    },
  );

  testWidgets('shows a note for a selection missing from this file', (
    tester,
  ) async {
    await pumpCard(
      tester,
      presentation(defaultPermissions: 'other-layer'),
    );

    expect(find.text('other-layer'), findsOneWidget);
    expect(find.text('Not defined in this file.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the empty state with no configured entries', (
    tester,
  ) async {
    await pumpCard(
      tester,
      presentation(hasConfiguredPermissions: false),
    );

    expect(
      find.text('No permission settings stored in this file.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the legacy-table note only with co-existing keys', (
    tester,
  ) async {
    await pumpCard(
      tester,
      presentation(
        sandboxMode: 'workspace-write',
        hasSandboxWorkspaceWriteTable: true,
      ),
    );
    expect(
      find.text(
        'A [sandbox_workspace_write] table is present but not shown.',
      ),
      findsOneWidget,
    );

    await pumpCard(
      tester,
      presentation(
        hasSandboxWorkspaceWriteTable: true,
        hasConfiguredPermissions: false,
      ),
    );
    expect(
      find.text('No permission settings stored in this file.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'A [sandbox_workspace_write] table is present but not shown.',
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows help dialogs and stays read-only', (tester) async {
    await pumpCard(tester, presentation(profiles: [profile()]));

    expect(find.byType(TextField), findsNothing);
    final helpButton = find.byTooltip(
      CodexPermissionsHelp.network.description,
    );
    await tester.ensureVisible(helpButton.first);
    await tester.pumpAndSettle();
    await tester.tap(helpButton.first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text(CodexPermissionsHelp.network.description),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
