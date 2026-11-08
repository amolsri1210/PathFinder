/**
 * Seed Pathfinder career content into Firestore.
 *
 * Dry run by default. Add --apply to write. Configure FIREBASE_PROJECT_ID and
 * Application Default Credentials before applying. Deterministic document IDs
 * are replaced on each run; this script does not delete any documents.
 */
import { readFile } from 'node:fs/promises';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const apply = process.argv.includes('--apply');
const projectId = process.env.FIREBASE_PROJECT_ID;
if (apply && !projectId) {
  throw new Error('Set FIREBASE_PROJECT_ID before using --apply.');
}

const dataUrl = new URL('../data/careers.seed.json', import.meta.url);
const seed = JSON.parse(await readFile(dataUrl, 'utf8'));
const quizUrl = new URL('../data/quiz.seed.json', import.meta.url);
const quizSeed = JSON.parse(await readFile(quizUrl, 'utf8'));
const records = seed.records;

if (!apply) {
  console.log(`Dry run: ${records.length} careers, ${records.length} roadmaps, 1 quiz version, and ${quizSeed.questions.length} quiz questions are ready.`);
  console.log('No Firebase writes made. Add --apply with Firebase credentials to write these drafts.');
  process.exit(0);
}

initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();
const batch = db.batch();
const pathfinderRef = db.collection('pathfinder').doc('content');
batch.set(pathfinderRef, {
  schemaVersion: seed.schemaVersion,
  description: 'Pathfinder shared career and quiz content namespace',
  updatedAt: FieldValue.serverTimestamp(),
});

for (const { career, roadmap } of records) {
  const careerRef = pathfinderRef.collection('careers').doc(career.id);
  const roadmapRef = careerRef.collection('roadmapVersions').doc(roadmap.id);
  batch.set(careerRef, {
    ...career,
    activeRoadmapVersionId: roadmap.id,
    updatedAt: FieldValue.serverTimestamp(),
  });
  batch.set(roadmapRef, {
    ...roadmap,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

const quizVersionRef = pathfinderRef.collection('quizVersions').doc(quizSeed.version.id);
batch.set(quizVersionRef, {
  ...quizSeed.version,
  maxPointsByTrait: quizSeed.maxPointsByTrait,
  updatedAt: FieldValue.serverTimestamp(),
});
for (const question of quizSeed.questions) {
  batch.set(quizVersionRef.collection('questions').doc(question.id), question);
}

await batch.commit();
console.log(`Wrote ${records.length} career documents, ${records.length} draft roadmaps, and ${quizSeed.questions.length} quiz questions to ${projectId}.`);
