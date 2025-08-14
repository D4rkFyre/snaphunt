import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CreateGameLobbyScreen extends StatelessWidget {
  const CreateGameLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> users = [
      {"name": "PlayerOne"},
      {"name": "PlayerTwo"},
      {"name": "PlayerThree"},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF3E2C8B),
      appBar: AppBar(
        title: const Text(
          "Game Lobby",
          style: TextStyle(
            color: Colors.yellowAccent,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF3E2C8B),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Game code in yellow pill with copy icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC943),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "ABC123",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E2C8B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: "ABC123"));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Game code copied to clipboard!"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: SvgPicture.asset(
                      'assets/icons/copy.svg',
                      width: 24,
                      height: 24,
                      color: const Color(0xFF3E2C8B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Auto-expanding yellow player list box
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC943),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/person-circle.svg',
                          width: 50,
                          height: 50,
                          color: const Color(0xFF3E2C8B),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          users[index]["name"]!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E2C8B),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Start Game button
            ElevatedButton(
              onPressed: () {
                print("Start Game tapped");
                // Navigation or game start logic goes here
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text("Start Game"),
            ),
          ],
        ),
      ),
    );
  }
}
