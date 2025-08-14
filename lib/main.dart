import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

import 'dev/dev_host_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SnapHuntApp());
}

class SnapHuntApp extends StatelessWidget {
  const SnapHuntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapHunt (Dev)',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      // Temporary dev entry: tap + to create a game and see the join code.
      home: const HomeScreen(),
    );
  }
}
