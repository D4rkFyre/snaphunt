// lib/main.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // If no Firebase app yet, initialize appropriately per platform:
  if (Firebase.apps.isEmpty) {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // ✅ Bind to the native default created by google-services (avoids duplicate-app)
      await Firebase.initializeApp();
    } else {
      // Web/Windows/Linux need explicit options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  // Ensure we are authenticated (anonymous is fine for this project)
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }

  // Optional quick sanity logs while debugging:
  // debugPrint('Firebase apps count: ${Firebase.apps.length}');
  // debugPrint('Current UID: ${FirebaseAuth.instance.currentUser?.uid}');

  runApp(const SnaphuntApp());
}

class SnaphuntApp extends StatelessWidget {
  const SnaphuntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snaphunt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF3E2C8B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC943),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
