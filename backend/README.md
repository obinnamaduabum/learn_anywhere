# Quarkus Java learning backend

Java 17+ and Maven are required. Quarkus CDI connects `ILearningResource` → `ILearningService` → `ILearningRepository`. PostgreSQL stores course structure, immutable language packs, anonymous installations, progress, idempotent events, and reviewable content drafts. Flyway manages migrations. Java imports use explicit classes.

## Start

From this directory, with Docker Desktop running:

```sh
docker compose -p learn-anywhere up -d postgres adminer
export APP_PORT=8084
export APP_HOST=0.0.0.0
export JDBC_DATABASE_URL='jdbc:postgresql://localhost:5432/learning'
export POSTGRES_USER=learning
export POSTGRES_PASSWORD=local-dev-only
export ADMIN_TOKEN='replace-with-a-strong-random-token'
mvn quarkus:dev
```

Use the existing private local admin token when continuing an existing demo; do not commit or document its value. The PostgreSQL credentials above are development defaults.

On this machine Maven may select Java 8. Select a supported JDK and remove incompatible legacy Maven JVM options:

```sh
export JAVA_HOME=$(/usr/libexec/java_home -v 22)
export MAVEN_OPTS=''
mvn clean install
```

Quarkus dev mode reloads source changes and enables debugger attachment on port 5005 by default. IntelliJ should use a Java 17+ project/Maven SDK. A packaged server is not in debugger mode unless explicitly launched with JDWP.

For a packaged server with Swagger and migrations:

```sh
SWAGGER_ENABLED=true mvn package
APP_PORT=8084 MIGRATE_AT_START=true java -jar target/quarkus-app/quarkus-run.jar
```

Keep `ADMIN_TOKEN` in the process environment for administration. `SWAGGER_ENABLED` is a build-time setting. Dev mode enables Flyway migration automatically; packaged mode requires `MIGRATE_AT_START=true` when migrations should run. Configuration is in `src/main/resources/application.properties`, `.env.example`, and `LearningConfig`.

## Courses and series

The learner catalog distinguishes normal courses from series courses:

```json
[
  {
    "id": "ai-foundations-v1",
    "type": "course",
    "title": "AI Foundations",
    "lessonCount": 5,
    "packs": [{"language": "en", "version": 1}]
  },
  {
    "id": "understanding-ai",
    "type": "series",
    "title": "Understanding AI",
    "lessonCount": 80,
    "packs": [{"language": "en", "version": 1}],
    "parts": [
      {
        "id": "understanding-ai-week-01",
        "partIndex": 1,
        "title": "Understanding AI — Week 1: Recognising AI",
        "lessonCount": 5,
        "packs": [{"language": "en", "version": 1}]
      }
    ]
  }
]
```

This abbreviated example omits descriptions, additional languages, pack review status/size, and the remaining 15 parts. The actual Understanding AI response includes seven languages for every part.

`courses` contains two top-level courses. `course_series` owns the 16 weekly part records, with titles, descriptions, ordered indices, and stable content identities. `content_units` preserves IDs referenced by releases and progress; weekly parts are no longer top-level `courses` records. See [architecture](design/architecture.md).

## API and Swagger

Swagger: http://127.0.0.1:8084/api/v1/swagger-ui/

OpenAPI 3.0.3: http://127.0.0.1:8084/api/v1/openapi

- `GET /api/v1/health`
- `GET /api/v1/courses`
- `GET /api/v1/packs/{course-or-part-id}/{language}?version=1`, with conditional ETag downloads.
- `POST /api/v1/installations`, issuing an anonymous identity and token once.
- `POST /api/v1/progress/sync`, authenticated by the installation bearer token.
- `POST /api/v1/admin/drafts`, authenticated by the staff bearer token.
- `GET /api/v1/admin/drafts/{id}`.
- `POST /api/v1/admin/drafts/{id}/approve`.

Use a part ID for downloads and synchronization; the parent Understanding AI ID does not have a direct lesson pack. Port 8082 may belong to an older running process and should not be used for the updated demo.

## Offline events and rewards

```json
{
  "courseId": "understanding-ai-week-01",
  "version": 1,
  "language": "en",
  "events": [
    {"id": "stable-event-id", "type": "lesson_read", "lessonId": 0}
  ]
}
```

Supported events are `lesson_read`, `quiz_answered` (question ID and selected option), `quiz_completed`, and `task_completed` (checklist). Batches contain 1–100 ordered events. The server locks the installation and commits each batch atomically. Repeating an event ID with identical data is idempotent; changed data returns 409.

Reading unlocks the next lesson. Flutter presents one assessment after all five lessons and reveals feedback only after the score. Internally, answers and completion remain associated with their original lesson IDs to preserve existing pack identities and progress.

Rewards are derived from unique keys: 10 points for each first correct question, 50 for each first lesson-question-group completion, and 100 for the final task. A five-lesson assessment includes five such completion groups. Wrong answers do not block completion, and practice cannot repeat rewards.

The Digital Safety starter uses checklist keys `screen_lock`, `unique_password`, `mfa`, `backup`. Other courses use `recap`, `practice`, `plan`, `demonstrate`. Flutter keeps an SQLite outbox and acknowledges events only after successful server acknowledgement; iOS installation tokens use Keychain.

## Content, languages, and approval

Understanding AI contains 16 parts, 80 distinct lessons, and 240 questions. Each part has English, French, Portuguese, Arabic, Hausa, Yorùbá, and Igbo packs: 112 published packs. The six translated versions were generated with automated Google translation, imported as 96 drafts, and explicitly approved by the owner for the local demo on 4 October 2026. Bilingual expert review has not been claimed.

Content review documents and JSON packs are under `../frontend/assets/course-drafts/understanding-ai-languages/`. URLs, lesson IDs, question IDs, option ordering, and correct-answer indices are preserved across translations.

ChatGPT Free remains a manual authoring option, not an automatically callable free ChatGPT API. `IContentGenerator` is the extension point for an integrated provider. Current translation scripts are an authoring workflow; the running backend does not automatically generate or publish content.

```json
{
  "topics": ["AI fundamentals"],
  "provider": "manual authoring or translation provider",
  "model": "authoring method",
  "pack": {
    "id": "example-course",
    "language": "en",
    "version": 1,
    "lessons": []
  }
}
```

Replace the empty array with five ordered lessons, accessible text, HTTPS source attribution, and valid questions. Structural checks do not verify factual correctness or translation quality. Drafts cannot be downloaded through learner routes.

Approval body:

```json
{
  "reviewer": "reviewer identity",
  "title": "Course title",
  "description": "Course description"
}
```

Approval records reviewer/time and publishes in one transaction. Existing version/language packs cannot be overwritten. Publishing a translation of an existing series part retains that part's relationship to its parent. Creating new series structures currently requires a database migration; there is no series-management admin endpoint yet.

Supported pack formats are `text`, `slides`, and `video`, with an accessible text body. Video hosting, compression, and Flutter media viewers remain separate work. Local relevance requires verified country-specific examples and opportunity information, beyond translation.

## Local database UI

Open http://127.0.0.1:8083:

| Field | Value |
|---|---|
| System | PostgreSQL |
| Server | postgres |
| Username | learning |
| Password | local-dev-only |
| Database | learning |

Adminer connects through the Compose network; its browser port is bound to localhost. Browse `courses` for parent courses, `course_series` for weekly parts, `language_packs` for published content, and `content_drafts` for approval history.

## Validation and limits

The latest build passes seven backend tests (learning rules and transaction boundaries). Live PostgreSQL checks verified two top-level courses, 16 series parts, and all 112 Understanding AI language packs. Flutter integration uses the current event API, rather than the old snapshot endpoint.

Production staff accounts, cross-device restore, comprehensive concurrency testing, rate limiting, media delivery, bilingual certification, and secure high-stakes assessment remain future work.

Catalog entries expose `created_at` as a UTC timestamp and are ordered newest first, with ID as a stable tie-breaker. Series parts remain ordered by `partIndex`. Migration V4 adds timestamps without resetting records; historical records use the earliest available approved-draft timestamp, or the migration time when history is unavailable. New courses use their insertion time.

Course catalog entries and series parts include `category`. Flutter displays it as Learning Category. Approval accepts an optional category (1–80 characters); new courses default to General Learning. Existing course categories remain unchanged when publishing translations.

`POST /api/v1/progress/restore` returns confirmed progress for the authenticated installation without modifying backend records. Flutter Clear local progress resets device display state after confirmation and keeps pending events; the next successful sync retrieves confirmed progress.

### Optional AI learning companion

`POST /api/v1/learning-companion` requires an installation Bearer token. Body: `courseId`, `version`, `language`, `lessonId`, and `action` (`explain`, `practice`, `suggestions`, or `prerequisites`). Returns `text` and up to three short `suggestions`. Configure `GROQ_API_KEY` and `GROQ_MODEL` on the backend; the default model is `llama-3.3-70b-versatile`; no provider call is possible without a key. The provider receives only published lesson title/body/takeaways and language, never profile, activity, or assessment answers. Groq receives the lesson content; provider retention policies apply. Supplementary AI responses do not publish or modify course content.

Each backend process limits authenticated installations to ten attempts per UTC day (provider failures also count). This development limit resets on restart and is not a distributed production spending limit; configure account spend limits and durable quotas before production. Flutter caches successful responses on-device. No automatic background AI requests are made. Users explicitly confirm before a new request and can opt to use generated messages for local course reminders.

Prerequisite help is explicitly labeled suggested preparation, not authoritative course requirements. It does not infer user knowledge or completion. Saving reminder suggestions updates pending random course reminders without changing their schedule; noon reminders retain their normal text.

Reviewed explanation downloads: published course packs may include `explanations: {version: 1, lessons: [{id: 0, text: "..."}, ...]}` with all five ordered lessons. `GET /api/v1/explanations/{course}/{language}?version=N` returns `available`, course identity, and (when available) `explanationVersion` and lesson texts. This endpoint never calls AI. Explanations follow the existing draft review/approval process; changing published explanations requires a new immutable course version. Flutter downloads the whole explanation pack, saves it in device state, displays its version, and supports offline reading and checking for updates. Existing courses without explanations return `available:false`; no generated content has been published automatically.

### Docker API for iOS Simulator
Build current source with `mvn clean install`, then `docker compose -p learn-anywhere up -d --build backend`. Stop the identified host API first if it occupies 8084. The API binds 0.0.0.0 inside Docker and publishes port 8084 on the Mac's network interfaces. PostgreSQL remains at postgres:5432 with the existing learning_pg volume. Compose reads secrets from the private .env, excluded from the image. The simulator uses http://127.0.0.1:8084. Never use down -v for this switch.

### Same Wi-Fi access

Apply the port mapping with `docker compose -p learn-anywhere up -d backend`. For a host Maven run, set `APP_HOST=0.0.0.0 APP_PORT=8084`; dev mode also defaults to binding all interfaces. PostgreSQL and Adminer remain bound to localhost. On the iPhone, use `http://<Mac-Wi-Fi-IP>:8084`; loopback addresses refer to the phone itself. Verify `/api/v1/health` from Safari on the phone. Allow incoming connections for Docker or Java if the Mac firewall asks, and avoid guest networks with client isolation. This configuration is for the trusted local demo; public deployments require HTTPS.
