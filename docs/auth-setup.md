# Pathfinder authentication setup

Pathfinder uses Firebase Authentication for email/password and Google sign-in. Passwords are managed by Firebase Authentication and are never stored in Firestore.

## Firebase Console setup

1. Enable Email/Password and Google providers in Firebase Authentication.
2. Add the production Hosting domains to the authorized domains list.
3. Configure the web app values in a local `firebase.web.json` copied from `firebase.web.example.json`.

## User data

Signed-in users can sync their profile, saved careers, roadmap progress, study log, and quiz results under their own `users/{uid}` document paths. Firestore rules restrict those paths to the authenticated owner. Firebase Auth remains the source of account identity.

Guest progress stays in browser storage and is merged into the account after sign-in. Shared career and quiz content is bundled locally for the current app release; Firestore seed records remain drafts until reviewed and published.

Never commit Firebase service-account credentials, reCAPTCHA secret keys, App Check debug tokens, or the local `firebase.web.json` file.
