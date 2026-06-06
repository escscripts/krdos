import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Material shell pumps', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('KrdOS test harness')),
        ),
      ),
    );
    expect(find.text('KrdOS test harness'), findsOneWidget);
  });
}
