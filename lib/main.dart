import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:snaphunt/screens/home_screen.dart';
import 'firebase_options.dart';  // FlutterFire CLI generated Firebase config file


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
      debugShowCheckedModeBanner: false,
      title: 'SnapHunt (Dev)',  // App title
      theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal  // Theme color
      ),
      home: const HomeScreen(), // Temporary dev entry: tap + to create a game and see the join code.

    );
  }
}
