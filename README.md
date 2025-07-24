# SnapHunt

SnapHunt is an AI-powered scavenger hunt mobile app built with Flutter.  
Hosts take photos of locations or objects within a designated play zone, and players must locate and take matching photos. The app uses an AI backend to evaluate similarity and award points.

---

## 🚧 Project Status

> 🧱 **Current Phase:** Project Scaffold & Setup  
All directory structure, placeholder files, and Git flow have been initialized.  
Development will begin on feature branches starting in the next sprint.

---

## 📁 Project Structure

```plaintext
lib/
├── main.dart                  # Entry point of the app
│
├── screens/                  # Major UI pages
│   ├── home_screen.dart
│   ├── host_screen.dart
│   ├── player_screen.dart
│   ├── match_result_screen.dart
│   └── splash_screen.dart
│
├── widgets/                  # Reusable UI components
│   ├── custom_button.dart
│   ├── photo_card.dart
│   └── loading_indicator.dart
│
├── models/                   # Data models
│   ├── user_model.dart
│   ├── game_model.dart
│   ├── submission_model.dart
│   └── clue_model.dart
│
├── services/                 # Platform services (camera, location, permissions)
│   ├── location_service.dart
│   ├── camera_service.dart
│   ├── permission_service.dart
│   └── firebase_service.dart
│
├── providers/                # State management with Provider
│   ├── game_provider.dart
│   ├── user_provider.dart
│   └── auth_provider.dart
│
├── ai_backend/               # Handles AI backend requests
│   ├── image_matcher.dart
│   └── api_client.dart
│
├── constants/                # App-wide constants and styles
│   ├── colors.dart
│   ├── strings.dart
│   └── app_routes.dart
│
└── utils/                    # General-purpose helper functions
    ├── image_utils.dart
    └── location_utils.dart
