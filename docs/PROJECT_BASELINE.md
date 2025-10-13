# SnapHunt — Project Baseline (Aug 2025)

## Stack
- Flutter (Dart)
- Firebase: Core 2.x, Cloud Firestore 4.x (Test Mode)
- Tests: `flutter_test`, `fake_cloud_firestore 2.x`

## App Structure (key files)
- `lib/models/game_model.dart` — Game data class (`id`, `joinCode`, `status`, `createdAt`, `players`)
- `lib/services/firestore_refs.dart` — Centralized Firestore paths (`/games`, `/codes/{code}`)
- `lib/services/join_code.dart` — 6-char uppercase join code generator (excludes I/O/1/0)
- `lib/repositories/game_repository.dart` — Atomic game creation + unique code reservation (transaction)
- `lib/dev/dev_host_screen.dart` — Dev-only screen; FAB creates a game and shows the code
- `lib/main.dart` — Initializes Firebase and launches the dev screen

## Firestore Layout (runtime-created)
- `games/{autoId}`:
    - `joinCode: STRING` (A–Z, 2–9; 6 chars; no I/O/1/0)
    - `status: "waiting" | "active" | "ended"`
    - `createdAt: Timestamp`
    - `players: STRING[]`
- `codes/{JOINCODE}` (doc id is the code):
    - `status: "reserved"`
    - `createdAt: serverTimestamp()`

## Behavior Notes
- Unique join code is enforced by reserving `/codes/{JOINCODE}` inside a Firestore **transaction**, then creating `/games/{autoId}` in the same transaction.
- Dev screen (FAB) lets us exercise the flow before real UI lands.
- Widget tests inject `FakeFirebaseFirestore` into the repository to avoid real Firebase in tests.

## Regions
- Firestore & Storage: **`nam5`** (multi-region). Keep both in the same region.

## What’s next (likely)
- Real host screen calls `GameRepository().createGame()`
- Player join flow + basic security rules (when moving off Test Mode)
