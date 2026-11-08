# Pathfinder

Pathfinder is a Flutter Web career guidance and roadmap app with personalized career discovery, a ten-question quiz, 43 career roadmaps, learning resources, progress tracking, Firebase sign-in, and AI career guidance.

## Start the app

See [docs/frontend-setup.md](docs/frontend-setup.md) for Firebase Web configuration, local run commands, and release build instructions.

## Production hosting

Firebase Hosting is configured to serve the Flutter Web release from `build/web`. Prepare and deploy with the Firebase CLI after registering the web app in Firebase App Check with reCAPTCHA Enterprise:

```sh
export FIREBASE_APPCHECK_SITE_KEY="your-production-recaptcha-v3-site-key"
./scripts/deploy_firebase_hosting.sh
```

The script builds without the local App Check debug provider and deploys only Hosting. See [the production checklist](docs/production-deployment.md) for first-time setup and GitHub deployment notes.

Career roadmaps and quiz content are bundled from `data/careers.seed.json` and `data/quiz.seed.json`. Guest learning progress is stored locally and can be merged into a Firebase account after sign-in. Do not commit `firebase.web.json`, `.env.local`, service account keys, or reCAPTCHA secret keys.
