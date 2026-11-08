# Pathfinder Flutter Web frontend

The app is a responsive Flutter Web PWA using Dart 3, Riverpod, `go_router`, Material 3, Google Fonts, Firebase Auth, Cloud Firestore, and Hive for guest storage.

## Run locally

1. Install Flutter with Dart 3.12 or newer.
2. Create `firebase.web.json` in the workspace root from `firebase.web.example.json` and fill its values from the Firebase Web app configuration. This file is gitignored.
3. Run:

```sh
flutter pub get
flutter run -d chrome --dart-define-from-file=firebase.web.json
```

To run without Firebase, use `flutter run -d chrome`; discovery, quiz, saved careers, and progress still work in guest mode and stay in the browser.

## Included screens and behavior

- Home, searchable Explore, career detail and vertical task roadmap for all 43 careers.
- Ten-question quiz scored from `data/quiz.seed.json` and its trait weights.
- My Journey, Saved, Profile/settings, email/password and Google sign-in.
- Guest progress is stored in Hive/IndexedDB and merged with the account's saved careers, task progress, and latest quiz result after sign-in.
- Draft career and quiz content is loaded from local JSON. Firestore contains draft seed records, and the security rules intentionally expose only published shared content.

## Release build

```sh
flutter analyze
flutter build web --release --dart-define-from-file=firebase.web.json
```

The build output is `build/web`. Firebase Hosting can serve that directory after the review/publish flow for shared career and quiz content is ready. Enable Email/Password and Google providers in Firebase Authentication before using those sign-in buttons.
