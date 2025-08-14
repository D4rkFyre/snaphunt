import 'lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HostGameScreen extends StatefulWidget {
  const HostGameScreen({super.key});

  @override
  State<HostGameScreen> createState() => _HostGameScreenState();
}

class _HostGameScreenState extends State<HostGameScreen> {
  int _selectedIndex = 0;
  final TextEditingController _usernameController = TextEditingController();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Add navigation logic based on index if needed
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3E2C8B),
      appBar: AppBar(
        title: const Text(
          "Host Game",
          style: TextStyle(
            color: Colors.yellowAccent,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF3E2C8B),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Username',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Enter your username',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF5D4BB2),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 18.0,
                    horizontal: 20.0,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: const BorderSide(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final username = _usernameController.text.trim();
                  if (username.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter a username")),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateGameLobbyScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 32,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Create Game',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFFFC943),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/book.svg',
              color: const Color(0xFF3E2C8B),
              width: 28,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/trophy-fill.svg',
              color: const Color(0xFF3E2C8B),
              width: 28,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/person-circle.svg',
              color: const Color(0xFF3E2C8B),
              width: 28,
            ),
            label: '',
          ),
        ],
      ),
    );
  }
}
