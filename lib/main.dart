// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

// TODO: change this import to your real home screen:
import 'screens/home_screen.dart';

Future<void> _bootstrapFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for current platform
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ensure we have a user (anonymous is fine for now)
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
}

void main() async {
  await _bootstrapFirebase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snaphunt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF3E2C8B),
        useMaterial3: true,
      ),
      home: const HomeScreen(), // or your entry screen
    );
  }
}
