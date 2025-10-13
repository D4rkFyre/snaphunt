// lib/widgets/onboarding_gate.dart
import 'package:flutter/material.dart';
import '../services/launch_prefs.dart';

/// Shows [gameInfoBuilder] the very first time the app launches, then always
/// shows [homeBuilder] after the user taps "Got it".
///
/// Important:
/// - When user opens Game Info later via your GameNavBar, there is no "Got it"
///   button injected (that path doesn't use this gate).
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.homeBuilder,
    required this.gameInfoBuilder,
  });

  final WidgetBuilder homeBuilder;
  final WidgetBuilder gameInfoBuilder;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final seen = await LaunchPrefs.hasSeenGameInfo();
    if (!mounted) return;
    setState(() => _seen = seen);
  }

  Future<void> _markSeenAndGoHome() async {
    await LaunchPrefs.setSeenGameInfo(true);
    if (!mounted) return;
    setState(() => _seen = true);
  }

  @override
  Widget build(BuildContext context) {
    // Minimal splash during prefs read
    if (_seen == null) {
      return const Material(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_seen == true) {
      return widget.homeBuilder(context);
    }

    // First ever launch → show Game Info with a lightweight "Got it" affordance.
    return _GameInfoWithDone(
      child: widget.gameInfoBuilder(context),
      onDone: _markSeenAndGoHome,
    );
  }
}

/// Adds a small "Got it" button only in the first-launch context.
/// When Game Info is opened via the nav bar later, this wrapper is NOT used.
class _GameInfoWithDone extends StatelessWidget {
  const _GameInfoWithDone({required this.child, required this.onDone});
  final Widget child;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),

        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Got it'),
            ),
          ),
        ),
      ],
    );
  }
}