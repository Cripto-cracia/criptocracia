// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:criptocracia/main.dart';

void main() {
  testWidgets('Criptocracia app renders basic UI', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CriptocraciaApp());
    
    // Just pump once to avoid network timeouts
    await tester.pump();

    // Verify the bottom navigation elements are present
    expect(find.text('Elections'), findsOneWidget);
    expect(find.text('Results'), findsOneWidget);
    
    // Verify the drawer menu is accessible
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });
}
