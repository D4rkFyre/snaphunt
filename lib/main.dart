import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';  // FlutterFire CLI generated Firebase config file
import 'dev/dev_host_screen.dart';  // Temp dev host screen to test logic


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Init Flutter bindings/plugins
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform  // Platform config
  );
  runApp(const SnapHuntApp());  // Launch app
}

class SnapHuntApp extends StatelessWidget {
  const SnapHuntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      title: 'SnapHunt (Dev)',  // App title
      theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal  // Theme color
      ),
      home: const DevHostScreen(), // Temporary dev entry: tap + to create a game and see the join code.

    );
  }
}
