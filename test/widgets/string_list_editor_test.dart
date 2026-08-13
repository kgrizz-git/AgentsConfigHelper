import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agents_config_helper/widgets/string_list_editor.dart';

void main() {
  group('StringListEditor', () {
    testWidgets('renders list and allows typing', (WidgetTester tester) async {
      final items = ['initial'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StringListEditor(
              values: items,
              hintText: 'Hint',
              onChanged: (newItems) {},
            ),
          ),
        ),
      );

      expect(find.text('initial'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));

      await tester.enterText(find.byType(TextField).last, 'new item');
      await tester.pumpAndSettle();

      expect(find.text('new item'), findsOneWidget);
    });
  });
}
