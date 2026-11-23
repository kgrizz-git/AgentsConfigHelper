import 'dart:async';

import 'package:agents_config_helper/models/tool_config.dart';
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
}
