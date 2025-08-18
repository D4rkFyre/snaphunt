// test/screens/home_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/screens/home_screen.dart';

/// ---------------------------------------------------------------------------
/// HomeScreen smoke test
/// ---------------------------------------------------------------------------
/// Purpose
/// - Ensure the Home screen renders without errors and shows a bottom
///   navigation bar with exactly 3 items (icons only).
///
/// Why this matters
/// - This is a lightweight “does it boot?” check for the landing page.
/// - We don’t assert labels or icons here—just the presence and count of items,
///   so the test won’t break if we swap artwork later.
/// ---------------------------------------------------------------------------
void main() {
  testWidgets('Home renders and has a 3-item bottom nav', (tester) async {
    // Pump the Home screen in a MaterialApp shell (gives us theme + Navigator)
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();   // settle the first frame

    // Home should render and include a BottomNavigationBar
    final navFinder = find.byType(BottomNavigationBar);
    expect(navFinder, findsOneWidget);

    // Read the widget to assert item count (robust against icon/label changes)
    final nav = tester.widget<BottomNavigationBar>(navFinder);
    expect(nav.items.length, 3);
  });
}
