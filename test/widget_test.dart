import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cw3/main.dart'; // Matches pubspec.yaml name

void main() {
  testWidgets('Add and remove task test', (WidgetTester tester) async {
    await tester.pumpWidget(const TaskApp());

    expect(find.text('No tasks yet!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Buy groceries');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('Buy groceries'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();

    expect(find.text('Buy groceries'), findsNothing);
  });
}
