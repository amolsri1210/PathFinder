#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f firebase.web.json ]]; then
  echo "Missing firebase.web.json. Copy firebase.web.example.json and add this Firebase web app's config." >&2
  exit 1
fi

if [[ -z "${FIREBASE_APPCHECK_SITE_KEY:-}" ]]; then
  echo "Set FIREBASE_APPCHECK_SITE_KEY to the production reCAPTCHA Enterprise site key before deploying." >&2
  exit 1
fi

flutter_bin="${PATHFINDER_FLUTTER_BIN:-flutter}"
firebase_bin="${PATHFINDER_FIREBASE_BIN:-firebase}"
"${flutter_bin}" build web \
  --release \
  --dart-define-from-file=firebase.web.json \
  --dart-define="FIREBASE_APPCHECK_SITE_KEY=${FIREBASE_APPCHECK_SITE_KEY}"

"${firebase_bin}" deploy --only hosting --project pathfinder-4de02
