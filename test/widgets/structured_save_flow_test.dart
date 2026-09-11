import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/widgets/structured_save_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StructuredSaveFlow.buildDiffSection', () {
    testWidgets('added rows use success, removed rows use error', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StructuredSaveFlow.buildDiffSection(
              'Rules',
              const ['kept', 'gone'],
              const ['kept', 'new'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final added = tester.widget<Text>(find.text('+ new'));
      expect(added.style?.color, AppColors.success);
      final removed = tester.widget<Text>(find.text('- gone'));
      expect(removed.style?.color, AppColors.error);
    });
  });
}
