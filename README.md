# 📸 SnapHunt

SnapHunt is an AI-powered scavenger hunt mobile app built with Flutter.  
Hosts capture photos in a real-world location, and players must physically navigate to these spots and take matching photos. The app uses an AI backend to compare images and score them based on similarity. Designed for students, educators, and explorers alike.

---

## 🚧 Project Status

> 🛠️ **Phase:** Environment & Backend Setup  
✅ GitHub project initialized  
✅ Firebase configured (Firestore + Storage)  
✅ FlutterFire CLI & SDKs integrated  
✅ Hive local storage setup  
🟡 Next step: Implement player and host game logic on feature branches

---

## 🏗️ Project Structure

```plaintext
lib/
├── main.dart                      # Entry point & Firebase initialization
│
├── screens/                      # UI pages
│   ├── splash_screen.dart
│   ├── home_screen.dart
│   ├── host_screen.dart
│   ├── player_screen.dart
│   └── match_result_screen.dart
│
├── widgets/                      # Reusable components
│   ├── custom_button.dart
│   ├── photo_card.dart
│   └── loading_indicator.dart
│
├── models/                       # App data models
│   ├── user_model.dart
│   ├── game_model.dart
│   ├── submission_model.dart
│   └── clue_model.dart
│
├── services/                     # Device and platform integrations
│   ├── location_service.dart
│   ├── camera_service.dart
│   ├── permission_service.dart
│   └── firebase_service.dart
│
├── providers/                    # State management via Provider
│   ├── auth_provider.dart
│   ├── user_provider.dart
│   └── game_provider.dart
│
├── ai_backend/                   # AI interaction for image comparison
│   ├── image_matcher.dart
│   └── api_client.dart
│
├── constants/                    # App-wide constants & theme configs
│   ├── colors.dart
│   ├── strings.dart
│   └── app_routes.dart
│
├── utils/                        # Helpers and utilities
│   ├── image_utils.dart
│   └── location_utils.dart
│
└── firebase_options.dart         # Auto-generated config for Firebase platforms


