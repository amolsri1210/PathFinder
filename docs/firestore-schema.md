# Pathfinder Firestore content model

This schema follows the PRD's Firebase sign-in and synchronized progress requirements. The checked-in seed is draft content; publish only after a content review.

## Shared content

### `pathfinder/content/careers/{careerId}`

Career catalog metadata: `name`, `category`, `summary`, `difficulty`, `timeToEntry`, `dayInLife`, `relatedCareerIds`, `skills[]`, `isFeatured`, `contentStatus`, `contentVersion`, and `activeRoadmapVersionId`.

Skills are embedded on the career for simple catalog/detail reads. Each has a stable `id`, `name`, `type` (`core`, `tool`, or `soft`), `level`, and `importance`.

### `pathfinder/content/careers/{careerId}/roadmapVersions/{versionId}`

Versioned shared learning content. A roadmap contains ordered `stages[]`; each stage contains ordered `tasks[]` and `resources[]`. Task IDs are stable within a career version and tasks link to career skill IDs. A four-stage roadmap is small enough to read with one Firestore document and makes the career detail screen a single content read. Split stages into their own documents only if roadmap documents approach Firestore's 1 MiB document limit or partial updates become common.

The seed writes `v1` as `draft`, so the application should show only roadmaps with `status == "published"`. The `activeRoadmapVersionId` points to the current draft in the seed; switch it to the reviewed version when publishing.

### `pathfinder/content/professionalExperiences/{experienceId}` (Release 1 display, Release 2 submission)

Experience card fields include `careerId`, `displayName`, `role`, `yearsExperience`, `companyType`, `quote`, `pros[]`, `cons[]`, `advice`, `verified`, `status`, and consent metadata. Only approved records with documented consent should be visible. Release 2 adds contributor submission and moderation workflows.

## User-owned data

- `users/{uid}` — profile and preferences such as `displayName`, `interests[]`, `weeklyHours`, `theme`, `language`, and notification preferences. Firebase Auth remains the source for credentials and sign-in identity.
- `users/{uid}/careerTracks/{trackId}` — `careerId`, `roadmapVersionId`, `status`, `startedAt`, and optional `weeklyGoal`. Keep the selected roadmap version on the track so later content updates do not move a learner's checklist.
- `users/{uid}/careerTracks/{trackId}/taskProgress/{taskId}` — `status`, `completedAt`, and optional `updatedAt`. The nested path scopes progress to one user's track and version.
- `users/{uid}/savedCareers/{careerId}` — bookmark timestamp and optional note.
- `users/{uid}/quizResults/{resultId}` — quiz version, answers, recommended career IDs, and creation time. Do not store sensitive inferences that the product does not need.

## Quiz content and matching

- `pathfinder/content/quizVersions/{versionId}` — version, status, question count, trait descriptions, and per-career trait weights.
- `pathfinder/content/quizVersions/{versionId}/questions/{questionId}` — ordered single-select question, helper text, and options. Each option adds interest points to one or more traits.

The current bank has 10 questions across 12 preference traits and weights all 43 careers. For a user's selected options, sum each option's trait points multiplied by that career's weights. Normalize by the highest score that career could receive across the answered questions, rank descending, and return the top three. Explain results using the strongest trait overlaps. Ties use career ID for stable ordering. This is an interest-match score, not an aptitude, eligibility, or employment prediction. The bank avoids questions that imply that one level of math comfort or prior experience rules out a career.

## Access rules to implement

- Published content under `pathfinder/content` is readable by signed-in and guest users as appropriate; draft content is admin-only.
- A user can read and write only documents under their own `users/{uid}` path.
- Professional experience cards are public only when approved; contributors can submit only their own records and cannot approve them.
- Admin content writes should use a trusted server/admin workflow, not client-side rules that let ordinary users edit shared career content.

## Seed data and import

`data/careers.seed.json` contains 43 career records, each with a draft v1 four-stage roadmap. `data/quiz.seed.json` contains the draft 10-question bank and all career-match weights. From `scripts/`, run `npm install` once, then `npm run seed:dry-run`. To write, configure Application Default Credentials and `FIREBASE_PROJECT_ID`, inspect the target project, then run `npm run seed:apply`. Re-running replaces the same career, v1 roadmap, and v1 quiz documents; it does not delete other data.

Roadmap time estimates are planning ranges, not promises. Content and links should be reviewed by practitioners and adapted to the learner's market before publication.
