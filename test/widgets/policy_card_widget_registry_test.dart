import 'package:agents_config_helper/schemas/claude_code_permissions.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:agents_config_helper/schemas/policy_card_registry.dart';
import 'package:agents_config_helper/widgets/claude_code_permissions_card.dart';
import 'package:agents_config_helper/widgets/policy_card_widget_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _OtherPresentation extends PolicyCardPresentation {
  const _OtherPresentation();

  @override
  List<Object?> get props => [];
}

void main() {
  ClaudeCodePermissionsPresentation claudePresentation() {
    return ClaudeCodePermissionsPresentation(
      defaultMode: 'default',
      allow: const ['Read(./fixtures/**)'],
      ask: const [],
      deny: const [],
      hasConfiguredPolicy: true,
      hasUnclassifiedSettings: false,
    );
  }

  group('PolicyCardWidgetRegistry', () {
    testWidgets('maps a known adapterId to the Claude card', (tester) async {
      final selection = PolicyCardSelection(
        adapterId: ClaudeCodePermissionsAdapter.adapterId,
        status: PolicyCardStatus.available,
        presentation: claudePresentation(),
      );

      final card = PolicyCardWidgetRegistry.shared.buildCard(selection);

      expect(card, isA<ClaudeCodePermissionsCard>());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));
      expect(find.text('Claude Code permissions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('returns null for an unknown adapterId without throwing', () {
      final selection = PolicyCardSelection(
        adapterId: 'unknown.adapter',
        status: PolicyCardStatus.available,
        presentation: claudePresentation(),
      );

      expect(PolicyCardWidgetRegistry.shared.buildCard(selection), isNull);
    });

    test('returns null for a non-available selection without throwing', () {
      const unsupported = PolicyCardSelection(
        adapterId: ClaudeCodePermissionsAdapter.adapterId,
        status: PolicyCardStatus.unsupported,
        unsupportedReason: 'not supported here',
      );
      const notApplicable = PolicyCardSelection(
        adapterId: PolicyCardRegistry.noAdapterId,
        status: PolicyCardStatus.notApplicable,
      );

      expect(
        PolicyCardWidgetRegistry.shared.buildCard(unsupported),
        isNull,
      );
      expect(
        PolicyCardWidgetRegistry.shared.buildCard(notApplicable),
        isNull,
      );
    });

    test(
      'returns null for an available selection with a null presentation '
      'without throwing',
      () {
        const selection = PolicyCardSelection(
          adapterId: ClaudeCodePermissionsAdapter.adapterId,
          status: PolicyCardStatus.available,
        );

        expect(
          PolicyCardWidgetRegistry.shared.buildCard(selection),
          isNull,
        );
      },
    );

    test('rejects a wrong-type presentation without throwing', () {
      const selection = PolicyCardSelection(
        adapterId: ClaudeCodePermissionsAdapter.adapterId,
        status: PolicyCardStatus.available,
        presentation: _OtherPresentation(),
      );

      expect(PolicyCardWidgetRegistry.shared.buildCard(selection), isNull);
    });
  });
}
