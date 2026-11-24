import 'dart:async';

import 'package:agents_config_helper/widgets/structured_save_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('review dialog renders the serialized result', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  unawaited(
                    StructuredSaveFlow.showDiffModal(
                      context: context,
                      isMounted: () => true,
                      isCurrentRevision: () => true,
                      pendingFidelityAssessment: () async => null,
                      pendingSavePreview: () async => '{"rules": ["new"]}',
                      supportsStructuredFields: true,
                      rawOnly: false,
                      currentRules: const ['old'],
                      currentPermissions: const [],
                      rules: const ['new'],
                      permissions: const [],
                      originalContent: '{"rules": ["old"]}',
                      rawContent: '{"rules": ["old"]}',
                      buildDiffSection: StructuredSaveFlow.buildDiffSection,
                      buildRawDiffSection:
                          StructuredSaveFlow.buildRawDiffSection,
                      saving: false,
                      onSaveChanges: () async {},
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Serialized result'), findsOneWidget);
    expect(find.textContaining('"new"'), findsWidgets);
  });
}
