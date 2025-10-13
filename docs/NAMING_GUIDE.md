# Naming & Structure Guide

## Folders (purpose)
- `models/` — Pure data classes (no I/O)
- `services/` — Low-level helpers (SDK refs, utilities)
- `repositories/` — App/data logic that composes services (Firestore ops)
- `dev/` — Dev-only screens/harnesses; safe to delete later
- `screens/` — Real app routes (UI)
- `widgets/` — Reusable UI pieces
- `providers/` — State mgmt (Provider/BLoC) exposed to UI
- `constants/` — Route names, string keys, theme constants

## File naming
- Models: `*_model.dart` → `game_model.dart`
- Repositories: `*_repository.dart` → `game_repository.dart`
- Services: descriptive task names → `firestore_refs.dart`, `join_code.dart`
- Tests mirror lib paths → `test/<folder>/<file>_test.dart`

## Code style
- Classes: `PascalCase` (e.g., `GameRepository`)
- Methods/vars: `camelCase`
- Firestore field names: `lowerCamelCase` (match Dart fields)
- Join code: 6 chars, A–Z + 2–9 (no I/O/1/0)
