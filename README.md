```markdown
# Virtual Study Room

[![Flutter](https://img.shields.io/badge/Framework-Flutter-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Language-Dart-0175C2.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](./LICENSE)

Professional, feature-rich Flutter app that helps students collaborate, study, and gamify learning in a virtual classroom environment.

## Project Snapshot

- Platform: Flutter (mobile, web, desktop directories present)
- Real-time collaboration: audio/video and shared whiteboard/notes
- Productivity features: Pomodoro timer, task lists, flashcards, goals
- Social features: Leaderboards, profiles, rewards

## Key Features

- Create and join virtual study rooms
- Real-time shared whiteboard and collaborative notes
- AI-powered flashcard generation and smart study suggestions
- Pomodoro timer and daily study goals
- Avatar customization and rewards system
- Authentication and user profiles (Firebase-ready)

## Tech Stack & Integrations

- Flutter (Dart)
- Firebase (auth, analytics, remote config — `firebase_options.dart` included)
- 100ms (presence of `100ms_web.html` suggests web RTC / conferencing integration)
- Platform targets: Android, iOS, Web, Windows, macOS, Linux

## Screens / Notable Modules

The `lib/` folder contains the main app and screens including:
- `home_screen.dart`, `study_room_screen.dart`, `flashcards_screen.dart`, `flashcard_quiz_screen.dart`
- Productivity: `pomodoro_timer_screen.dart`, `daily_study_goals_screen.dart`, `task_list_screen.dart`
- Social & UX: `profile_screen.dart`, `leaderboard_screen.dart`, `avatar_customization_screen.dart`
- Services: `lib/services/` contains `ai_service.dart`, `avatar_service.dart`, `rewards_service.dart`, `shared_notes_service.dart`, `whiteboard_service.dart`

## Getting Started (for recruiters / evaluators)

Prerequisites
- Flutter SDK (stable channel, tested on Flutter 3.x+)
- Dart
- Platform toolchains for Android/iOS if testing on devices/emulators

Quick local run

1. Clone the repository

```bash
git clone https://github.com/Haschwalt29/Virtual-Study-Room.git
cd Virtual-Study-Room
```

2. Install dependencies

```bash
flutter pub get
```

3. (Optional) Add Firebase configuration for Android/iOS/web if you want full backend functionality. Example files are expected in `android/app/` and `ios/Runner/`.

4. Run the app

```bash
flutter run
# or for web
flutter run -d chrome
```

Run tests

```bash
flutter test
```

## Project Structure (high level)

- `lib/` — core app code and UI
- `lib/services/` — business logic and integrations (AI, whiteboard, shared notes)
- `assets/` — images, web integration files (e.g., `100ms_web.html`)
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` — platform-specific code

## Architecture & Design Notes

- UI is organized by screens under `lib/` and re-usable widgets under `lib/widgets/`.
- Backend integrations are abstracted in `lib/services/` to keep UI code clean and testable.
- The app includes Firebase configuration scaffolding (`firebase_options.dart`) so it can be connected to a real backend quickly.

## How to Evaluate (quick checklist for recruiters)

- Launch the app on an emulator or device with `flutter run`.
- Inspect `lib/services/` for integration patterns and separation of concerns.
- Review `lib/widgets/` for reusable UI components and consistent theming (`theme_provider.dart`).
- Run `flutter analyze` and `flutter test` to review static analysis and unit/widget tests.

## Contribution & Extensibility

This project is structured to be extensible. To contribute:

- Fork the repo, create a feature branch, add tests, and open a pull request.
- Keep changes focused and add documentation for new features.

## Contact

Replace with your contact details in the project before sharing with recruiters:

- Name: Your Name
- Email: your.email@example.com
- GitHub: https://github.com/Haschwalt29

## License

This repository is provided under the MIT License. See `LICENSE` for details.

```# study_room

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
