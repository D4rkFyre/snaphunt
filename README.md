# SnapHunt

SnapHunt is an AI-powered scavenger hunt mobile app built with Flutter.  
Hosts take photos of real-world locations or objects within a designated play zone, and players must find and capture matching photos. The app uses an AI backend to evaluate similarity, verify location, and award points.

---

## Introduction

SnapHunt transforms the classic scavenger hunt into a high-tech, location-based mobile experience.  
Instead of relying on manual judging or pre-written clues, SnapHunt uses AI image comparison and geofencing to verify matches in real time.

Why it’s useful:
- **For players:** Fun, competitive, and interactive outdoor gameplay.
- **For hosts:** Easy game creation with automatic AI scoring and geolocation checks.
- **For events:** Perfect for team-building, campus activities, tourism, or family outings.

---

## Features

- **Host Game Creation** – Create a scavenger hunt by taking pictures of "Snap Targets".
- **Player Participation** – Join games via a unique host code, take pictures to match the host's Snap Target pictures.
- **Geofencing Validation** – Only allows gameplay inside the designated zone.
- **AI Image Comparison** – Scores similarity between player pictures and host Snap Targets.
- **Score Tracking** – Real-time point updates.
- **Tie-Break Review Mode** – Hosts can manually decide winners in case of ties.

---

## Technologies

- **Frontend:** [Flutter](https://flutter.dev/) (cross-platform UI framework)
- **Backend:** [FastAPI](https://fastapi.tiangolo.com/) for AI image similarity scoring
- **Database & Storage:** [Firebase Firestore](https://firebase.google.com/docs/firestore) + Firebase Storage
- **Authentication:** [Firebase Auth](https://firebase.google.com/docs/auth) (anonymous sign-in for quick play)
- **AI Model (Planned):** [DINOv2](https://huggingface.co/facebook/dinov2-base) served via [Hugging Face Inference API](https://huggingface.co/inference-api) for image embeddings and cosine similarity scoring  
  *(Planned implementation – API keys and permissions not yet set up)*
- **Geolocation & Geofencing:** [geolocator](https://pub.dev/packages/geolocator) & [geofencing](https://pub.dev/packages/geofencing) Flutter packages

---

## Installation (Future Version 1.0)

End-user installation:
1. Download the latest release of **SnapHunt** from the provided distribution link (TBD).
2. Install the app on your Android device.
3. Launch SnapHunt and either:
    - **Host** a new game (requires camera + location permissions).
    - **Join** an existing game using the host’s game code.

Requirements:
- Android device with camera and GPS enabled.
- Internet connection.
- Location permissions enabled.

---

## Development Setup

This section is for developers who want to work on SnapHunt.

### 1. Clone the Repository

git clone https://github.com/D4rkFyre/snaphunt.git
cd SnapHunt

### 2. Install Flutter Dependencies

flutter pub get

### 3. Configure Firebase (Log in to Firebase CLI/ Configure Flutterfire)

firebase login
flutterfire configure

### 4. Run the App (Android/ Windows)

flutter run -d android

or

flutter run -d windows

---

## License
This project is licensed under the **MIT License**.  
You are free to use, modify, and distribute this software with attribution.

---

## Contributors
- **Aaron Woods** – Backend, AI integration, Firebase setup
- **Danah Alkhodari** – UI/UX design, Flutter screens
- **Robert Cox** – Game flow logic, geofencing

Maintained by the **SnapHunt Development Team (Full Sail University Capstone Project)**.

---

## Project Status
**Alpha** – Core game creation and join/lobby flows in progress.

**Upcoming features:**
- Clue photo uploads
- Player photo submissions
- AI image comparison scoring
- Geofence validation
- Leaderboard system
- Host review mode

