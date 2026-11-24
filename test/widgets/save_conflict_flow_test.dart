import 'dart:async';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/widgets/structured_save_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('conflict dialog retries with a fresh save on overwrite', (
    tester,
  ) async {
    final config = ToolConfig(
      toolName: 'Test Tool',
      filePath: '/tmp/conflict.json',
      format: ConfigFormat.json,
      originalContent: '{"rules": ["old"]}',
      rules: const ['old'],
    );
    final preview = SavePreview(
      config: config,
      content: '{"rules": ["new"]}',
      sourceContent: '{"rules": ["old"]}',
      sourceExists: true,
      parsed: config,
      usedFallback: false,
    );

    var calls = 0;
    var repreviewed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  unawaited(
                    StructuredSaveFlow.run(
                      context: context,
                      isMounted: () => true,
                      rawContent: () => null,
                      buildUpdatedConfig: () => config,
                      onSave:
                          (
                            config, {
                            rawContent,
                            allowRewrite,
                            overwriteConfirmed,
                          }) async {
                            calls++;
                            throw SaveConflictException(preview, 'external');
                          },
                      onSuccess: (_) {},
                      onError: (_) {},
                      setSavingFalse: () {},
                      onRepreview: () => repreviewed = true,
                    ),
                  );
                },
                child: const Text('save'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(find.text('File changed on disk'), findsOneWidget);

    await tester.tap(find.text('Overwrite'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(repreviewed, isTrue);
  });

  testWidgets(
    'a conflict during the fallback retry shows the overwrite dialog',
    (
      tester,
    ) async {
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: '/tmp/conflict-retry.toml',
        format: ConfigFormat.toml,
        originalContent: 'rules = ["old"]\n',
        rules: const ['old'],
      );
      final preview = SavePreview(
        config: config,
        content: 'rules = ["new"]\n',
        sourceContent: 'rules = ["old"]\n',
        sourceExists: true,
        parsed: config,
        usedFallback: true,
      );
      var calls = 0;
      var repreviewed = false;
      var errorShown = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    unawaited(
                      StructuredSaveFlow.run(
                        context: context,
                        isMounted: () => true,
                        rawContent: () => null,
                        buildUpdatedConfig: () => config,
                        onSave:
                            (
                              config, {
                              rawContent,
                              allowRewrite,
                              overwriteConfirmed,
                            }) async {
                              calls++;
                              if (allowRewrite != true) {
                                throw const SerializationFallbackException(
                                  format: 'TOML',
                                  wouldBeLost: 'comments',
                                );
                              }
                              throw SaveConflictException(preview, 'external');
                            },
                        onSuccess: (_) {},
                        onError: (_) => errorShown = true,
                        setSavingFalse: () {},
                        onRepreview: () => repreviewed = true,
                      ),
                    );
                  },
                  child: const Text('save'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(find.text('Save would change formatting'), findsOneWidget);

      await tester.tap(find.text('Rewrite document'));
      await tester.pumpAndSettle();
      expect(find.text('File changed on disk'), findsOneWidget);

      await tester.tap(find.text('Overwrite'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(repreviewed, isTrue);
      expect(errorShown, isFalse);
    },
  );
}
