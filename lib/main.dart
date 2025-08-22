// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';

/// A single, top-level Future that runs exactly once per process.
/// Even if hot restart tries to re-enter main, this remains initialized.
final Future<FirebaseApp> _firebaseInit = (() async {
  WidgetsFlutterBinding.ensureInitialized();

  // If already initialized, just return the default app.
  try {
    return Firebase.app();
  } catch (_) {
    // Not initialized yet: try to init.
    try {
      return await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      // If another path initialized in parallel, reuse it.
      if (e.code == 'duplicate-app') {
        return Firebase.app();
      }
      rethrow;
    }
  }
})();

Future<void> main() async {
  await _firebaseInit; // ensure once
  try {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  } on FirebaseAuthException catch (e) {
    // If Anonymous is disabled or something odd happens, you’ll see it.
    debugPrint('Anon sign-in failed: ${e.code}');
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