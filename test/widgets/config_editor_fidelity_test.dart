import 'dart:async';
import 'dart:io';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/json_config_parser.dart';
import 'package:agents_config_helper/widgets/config_editor.dart';
import 'package:agents_config_helper/widgets/formatting_fidelity_notice.dart';
import 'package:agents_config_helper/widgets/string_list_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _editor(
  ToolConfig config, {
  bool rawOnly = false,
  bool Function(ToolConfig)? hasUsableBaseline,
  bool Function(ToolConfig, String)? rawContentParsedAsJsonc,
  Future<bool> Function(ToolConfig)? currentSourceParsedAsJsonc,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ConfigEditor(
        config: config,
        rawOnly: rawOnly,
        onSave: (updatedConfig, [rawContent]) async => updatedConfig,
        resolvePath: (path) => path,
        hasUsableBaseline: hasUsableBaseline,
        rawContentParsedAsJsonc: rawContentParsedAsJsonc,
        currentSourceParsedAsJsonc: currentSourceParsedAsJsonc,
        onShowHistory: () {},
      ),
    ),
  );
}

void main() {
  group('ConfigEditor formatting fidelity', () {
    testWidgets('shows the shared TOML warning when structured fields change', (
      tester,
    ) async {
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${Directory.systemTemp.path}/config.toml',
        format: ConfigFormat.toml,
        rules: const ['rule1'],
        permissions: const ['perm1'],
      );

      await tester.pumpWidget(_editor(config, hasUsableBaseline: (_) => true));

      await tester.tap(find.text('Add Item').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'new rule');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Changes'));
      await tester.pumpAndSettle();

      expect(
        find.text('Structured save will reconstruct this TOML file'),
        findsWidgets,
      );
      expect(
        find.textContaining('Existing comments will be discarded'),
        findsWidgets,
      );
    });

    testWidgets(
      'does not show a review warning when a TOML raw save has no usable '
      'baseline',
      (tester) async {
        final config = ToolConfig(
          toolName: 'Test Tool',
          filePath: '${Directory.systemTemp.path}/stale-baseline.toml',
          format: ConfigFormat.toml,
          originalContent: 'rules = ["rule1"]\n',
          rules: const ['rule1'],
          permissions: const ['perm1'],
        );
        var checkedBaseline = false;

        await tester.pumpWidget(
          _editor(
            config,
            hasUsableBaseline: (_) {
              checkedBaseline = true;
              return false;
            },
          ),
        );

        await tester.tap(find.text('Add Item').first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(1), 'new rule');
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        final rawEditor = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.controller?.text == config.originalContent,
        );
        await tester.ensureVisible(rawEditor);
        await tester.enterText(rawEditor, 'rules = ["raw"]\n');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Review Changes'));
        await tester.pumpAndSettle();

        expect(checkedBaseline, isTrue);
        expect(find.text('Raw File Content'), findsOneWidget);
        expect(
          find.text('Structured save will reconstruct this TOML file'),
          findsOneWidget,
        );
        expect(find.byType(FormattingFidelityNotice), findsOneWidget);
      },
    );

    testWidgets('shows a caution, not the TOML warning, for JSON configs', (
      tester,
    ) async {
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${Directory.systemTemp.path}/config.json',
        format: ConfigFormat.json,
        rules: const ['rule1'],
        permissions: const ['perm1'],
      );

      await tester.pumpWidget(_editor(config));

      await tester.tap(find.text('Add Item').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'new rule');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Changes'));
      await tester.pumpAndSettle();

      expect(
        find.text('Formatting may change on structured save'),
        findsWidgets,
      );
      expect(
        find.text('Structured save will reconstruct this TOML file'),
        findsNothing,
      );
    });

    testWidgets('uses the edited raw buffer to label a pending JSONC merge', (
      tester,
    ) async {
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${Directory.systemTemp.path}/config.json',
        format: ConfigFormat.json,
        originalContent: '{"rules": ["rule1"]}',
        rules: const ['rule1'],
      );

      await tester.pumpWidget(
        _editor(
          config,
          hasUsableBaseline: (_) => true,
          rawContentParsedAsJsonc: (_, rawContent) => rawContent.contains('//'),
        ),
      );

      await tester.tap(find.text('Add Item').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'new rule');
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      final rawEditor = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == config.originalContent,
      );
      await tester.enterText(rawEditor, '// raw comment\n{"rules": ["rule1"]}');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Changes'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('this JSONC file can fall back to rebuilding'),
        findsOneWidget,
      );
    });

    testWidgets('uses the current source to label a structured JSONC save', (
      tester,
    ) async {
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${Directory.systemTemp.path}/config.json',
        format: ConfigFormat.json,
        originalContent: '{"rules": ["rule1"]}',
        rules: const ['rule1'],
      );

      await tester.pumpWidget(
        _editor(
          config,
          currentSourceParsedAsJsonc: (_) async => true,
        ),
      );

      await tester.tap(find.text('Add Item').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'new rule');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Changes'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('this JSONC file can fall back to rebuilding'),
        findsOneWidget,
      );
    });

    testWidgets(
      'does not open a stale review dialog after edits during lookup',
      (
        tester,
      ) async {
        final sourceStatus = Completer<bool>();
        final config = ToolConfig(
          toolName: 'Test Tool',
          filePath: '${Directory.systemTemp.path}/config.json',
          format: ConfigFormat.json,
          originalContent: '{"rules": ["rule1"]}',
          rules: const ['rule1'],
        );

        await tester.pumpWidget(
          _editor(
            config,
            currentSourceParsedAsJsonc: (_) => sourceStatus.future,
          ),
        );

        await tester.tap(find.text('Add Item').first);
        await tester.pumpAndSettle();
        final ruleEditor = find.byType(TextField).at(1);
        await tester.enterText(ruleEditor, 'first change');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Review Changes'));
        await tester.pump();
        await tester.enterText(ruleEditor, 'changed during lookup');
        await tester.pump();
        sourceStatus.complete(true);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets('renders an accessible persistent warning when TOML opens', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${Directory.systemTemp.path}/config.toml',
        format: ConfigFormat.toml,
      );

      await tester.pumpWidget(_editor(config));

      expect(
        find.text('Structured save will reconstruct this TOML file'),
        findsOneWidget,
      );
      expect(
        find.text('Opening this file does not change it on disk.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp('Structured save will reconstruct this TOML file'),
        ),
        findsOneWidget,
      );
      expect(find.byType(FormattingFidelityNotice), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('keeps JSONC parse and fidelity notices separate', (
      tester,
    ) async {
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${Directory.systemTemp.path}/settings.json',
        format: ConfigFormat.json,
        originalContent: '// comment\n{"rules": []}',
        parseWarnings: const [JsonConfigParser.jsoncFallbackWarning],
        parsedAsJsonc: true,
      );

      await tester.pumpWidget(_editor(config));

      expect(
        find.text('Formatting may change on structured save'),
        findsOneWidget,
      );
      expect(
        find.textContaining('comments or trailing commas) was detected'),
        findsOneWidget,
      );
      expect(
        find.textContaining('discard comments or trailing commas'),
        findsOneWidget,
      );
    });

    testWidgets('suppresses fidelity notices for raw-only recovery editors', (
      tester,
    ) async {
      final tomlConfig = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${Directory.systemTemp.path}/broken.toml',
        format: ConfigFormat.toml,
        originalContent: 'not = [valid',
      );

      await tester.pumpWidget(_editor(tomlConfig, rawOnly: true));

      expect(find.byType(FormattingFidelityNotice), findsNothing);
      expect(find.byType(StringListEditor), findsNothing);

      final jsonConfig = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${Directory.systemTemp.path}/broken.json',
        format: ConfigFormat.json,
        originalContent: '{ not valid json',
      );
      await tester.pumpWidget(_editor(jsonConfig, rawOnly: true));

      expect(find.byType(FormattingFidelityNotice), findsNothing);
      expect(find.byType(StringListEditor), findsNothing);
    });
  });
}
