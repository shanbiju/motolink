import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink/main.dart';

void main() {
  testWidgets('MotoLinkApp launches and renders Home Garage & Navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const MotoLinkApp());
    await tester.pumpAndSettle();

    // Verify app bar logo
    expect(find.byType(Image), findsWidgets);

    // Verify Garage elements
    expect(find.text('RTR 200 4V'), findsWidgets);
    expect(find.text('My Rides'), findsWidgets);

    // Verify bottom navigation items
    expect(find.text('Garage'), findsOneWidget);
    expect(find.text('Cockpit'), findsWidgets);
    expect(find.text('Navigation'), findsOneWidget);
    expect(find.text('Pairing'), findsOneWidget);

    // Switch to Pairing tab
    await tester.tap(find.text('Pairing'));
    await tester.pumpAndSettle();

    // Verify scan button on Pairing screen
    expect(find.text('SCAN FOR APACHE'), findsOneWidget);
  });
}
