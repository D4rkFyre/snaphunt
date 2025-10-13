// lib/widgets/progress_overlay.dart
import 'package:flutter/material.dart';

class ProgressOverlayController extends ChangeNotifier {
  final List<String> _steps = [];
  bool _visible = false;

  bool get visible => _visible;
  List<String> get steps => List.unmodifiable(_steps);

  void show() {
    if (_visible) return;
    _visible = true;
    _steps.clear();
    notifyListeners();
  }

  void hide() {
    if (!_visible) return;
    _visible = false;
    _steps.clear();
    notifyListeners();
  }

  void addStep(String text) {
    _steps.add(text);
    notifyListeners();
  }
}

class ProgressOverlay extends StatefulWidget {
  const ProgressOverlay({
    super.key,
    required this.controller,
    this.title = 'Submitting & Scoring',
  });

  final ProgressOverlayController controller;
  final String title;

  @override
  State<ProgressOverlay> createState() => _ProgressOverlayState();
}

class _ProgressOverlayState extends State<ProgressOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.visible) return const SizedBox.shrink();

    return Stack(
      children: [
        ModalBarrier(dismissible: false, color: Colors.black.withOpacity(0.35)),
        Center(
          child: Container(
            width: 320,
            constraints: const BoxConstraints(minHeight: 160),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(blurRadius: 20, spreadRadius: 2, offset: Offset(0, 6))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...widget.controller.steps.map(
                      (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
