import 'package:agents_config_helper/screens/shell_sidebar_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('labels overview and refresh actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ShellSidebarHeader(
              onShowOverview: () {},
              onAddManualPath: null,
              onAddProjectRoot: null,
              onManageProjectRoots: null,
              onOpenBackups: null,
              onRefresh: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Show config overview report'), findsOneWidget);
    expect(find.byTooltip('Refresh discovery'), findsOneWidget);
  });
}
