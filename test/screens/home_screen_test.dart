import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snaphunt/screens/home_screen.dart';

void main() {
  const deviceChannel = MethodChannel('snaphunt/device_id');

  setUpAll(() {
    // Stub device id (HomeScreen initState -> rejoin prompt path)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, (call) async {
      if (call.method == 'getDeviceId') return 'test-device';
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, null);
  });

  testWidgets('Home renders and has a 3-item bottom nav', (tester) async {
    // Set large surface INSIDE the test (avoids inTest assertion)
    await tester.binding.setSurfaceSize(const Size(800, 1400));

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    // Let post-frame callback run once
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Snaphunt'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);

    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bar.items.length, 3);

    // Reset surface
    await tester.binding.setSurfaceSize(null);
  });
}
