// lib/dev/dev_host_screen.dart
import 'package:flutter/material.dart';
import 'package:snaphunt/repositories/game_repository.dart';
import 'package:snaphunt/models/game_model.dart';

/// Minimal dev-only screen: tap the FAB to create a game with a unique join code.
/// Will be removed once real UI is ready.
class DevHostScreen extends StatefulWidget {
  const DevHostScreen({super.key, GameRepository? repo}) : _repo = repo;

  final GameRepository? _repo;  // Optional repo for testing

  @override
  State<DevHostScreen> createState() => _DevHostScreenState();
}

class _DevHostScreenState extends State<DevHostScreen> {
  // Game repo instance (uses provided repo or the default one)
  late final GameRepository _repo = widget._repo ?? GameRepository();
  // Local states for game status/errors
  bool _busy = false;
  Game? _lastGame;
  String? _error;

  // Create a game and update the UI with results or errors
  Future<void> _createGame() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Call repo to create game
      final game = await _repo.createGame();
      setState(() => _lastGame = game);

      // Show confirmation as a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created game ${game.id} with code ${game.joinCode}'),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      // Reset busy flag if widget is still mounted
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('[DEV] Host Game')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tap the + button to create a new game with a unique join code.',
              ),
              const SizedBox(height: 12),
              if (_busy) const Text('Working...'),
              if (_lastGame != null) ...[
                Text('Last game id: ${_lastGame!.id}'),
                Text('Last join code: ${_lastGame!.joinCode}'),
                Text('Status: ${_lastGame!.status}'),
              ],
              if (_error != null)
                Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : _createGame,  // Disabled while busy
        child: const Icon(Icons.add),
      ),
    );
  }
}
