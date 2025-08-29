// lib/main.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase exactly once.
  if (Firebase.apps.isEmpty) {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // Attach to the native default app created by google-services.* to avoid duplicate-app errors.
      await Firebase.initializeApp();
    } else {
      // Web/Windows/Linux need explicit options from firebase_options.dart
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

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
