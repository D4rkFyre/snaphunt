import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/screens/home_screen.dart';

void main() {
  testWidgets('Home renders and has a 3-item bottom nav', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(); // first frame

    // Home should render without throwing and have a BottomNavigationBar.
    final navFinder = find.byType(BottomNavigationBar);
    expect(navFinder, findsOneWidget);

    // Read the widget to assert item count without relying on labels/icons.
    final nav = tester.widget<BottomNavigationBar>(navFinder);
    expect(nav.items.length, 3);
  });
}
