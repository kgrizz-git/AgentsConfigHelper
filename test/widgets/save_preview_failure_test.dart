import 'dart:io';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/widgets/config_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

ToolConfig _config() => ToolConfig(
  toolName: 'Test Tool',
  filePath: '${Directory.systemTemp.path}/preview_failure.json',
  format: ConfigFormat.json,
  rules: const ['rule1'],
  permissions: const ['perm1'],
);

Future<void> _makeDirty(WidgetTester tester) async {
  await tester.tap(find.text('Add Item').first);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(1), 'new rule');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a non-conflict preview failure blocks the save', (tester) async {
    final config = _config();
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigEditor(
            config: config,
            onSave: (c, {rawContent, allowRewrite, overwriteConfirmed}) async {
              saveCalls++;
              return c;
            },
            resolvePath: (path) => path,
            onShowHistory: () {},
            previewSaveContent:
                (c, {rawContent, overwriteConfirmed = false}) async {
                  throw StateError('preview unavailable');
                },
          ),
        ),
      ),
    );

    await _makeDirty(tester);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Serialized result'), findsNothing);

    await tester.tap(find.text('Confirm & Save'));
    await tester.pumpAndSettle();

    expect(saveCalls, isZero);
    expect(find.textContaining('Could not compute a preview'), findsOneWidget);
  });

  testWidgets('a null preview blocks the save', (tester) async {
    final config = _config();
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigEditor(
            config: config,
            onSave: (c, {rawContent, allowRewrite, overwriteConfirmed}) async {
              saveCalls++;
              return c;
            },
            resolvePath: (path) => path,
            onShowHistory: () {},
            previewSaveContent: (
              c, {
              rawContent,
              overwriteConfirmed = false,
            }) async => null,
          ),
        ),
      ),
    );

    await _makeDirty(tester);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm & Save'));
    await tester.pumpAndSettle();

    expect(saveCalls, isZero);
    expect(find.textContaining('Could not compute a preview'), findsOneWidget);
  });

  testWidgets('a failed overwrite re-preview blocks the save', (tester) async {
    final config = _config();
    final overwriteValues = <bool?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigEditor(
            config: config,
            onSave: (c, {rawContent, allowRewrite, overwriteConfirmed}) async {
              overwriteValues.add(overwriteConfirmed);
              throw SaveConflictException.stale(config.filePath, 'external');
            },
            resolvePath: (path) => path,
            onShowHistory: () {},
            previewSaveContent:
                (c, {rawContent, overwriteConfirmed = false}) async {
                  if (!overwriteConfirmed) {
                    throw SaveConflictException.stale(c.filePath, 'external');
                  }
                  throw StateError('re-preview unavailable');
                },
          ),
        ),
      ),
    );

    await _makeDirty(tester);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm & Save'));
    await tester.pumpAndSettle();
    expect(find.text('File changed on disk'), findsOneWidget);

    await tester.tap(find.text('Overwrite'));
    await tester.pumpAndSettle();
    expect(find.text('Serialized result'), findsNothing);

    await tester.tap(find.text('Confirm & Save'));
    await tester.pumpAndSettle();

    expect(overwriteValues, [false]);
    expect(find.textContaining('Could not compute a preview'), findsOneWidget);
  });
}
