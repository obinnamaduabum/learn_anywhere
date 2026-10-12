# Learn Anywhere

An offline-first Flutter learning companion with a calm teal interface and a Quarkus Java/PostgreSQL backend. The proof of concept supports resource discovery, lightweight lesson downloads, saved progress, quizzes, and practical completion tasks.

## Repository layout

```text
e-learning-system/
├── frontend/    Flutter app, tests, assets, and mobile projects
├── backend/     Quarkus Java API and PostgreSQL migrations
└── docs/        Shared content-review guidance
```

Run Flutter commands from `frontend/` and Maven commands from `backend/`.

The Flutter project explicitly enables Swift Package Manager in `frontend/pubspec.yaml`, matching the iOS workspace. Regenerate Flutter's iOS configuration after changing native dependencies so the generated package includes SQLite.

## Local iOS release

Xcode offers **Runner** for Debug and **Runner Release** for Release without debugger attachment. Select the scheme, choose your iPhone, and press Run. `ios/Flutter/Release.xcconfig` includes the explicit local-demo endpoint and HTTP opt-in. Replace these before public distribution.

For Wi-Fi access with the current Mac address, run from `frontend/`:

```sh
bash scripts/run-ios.sh --release --device <iPhone-ID>
bash scripts/run-ios.sh --debug --device <iPhone-ID>
```

The script checks backend health before launching. Both devices must use the same network, with client isolation disabled. Set `LEARNING_API_URL` explicitly if automatic Wi-Fi address detection is unavailable. For Xcode-only runs, update the endpoint in Debug/Release xcconfig when the Mac's address changes. Release is a build choice, not an in-app switch.

For an explicitly local demo release on a physical iPhone, use a reachable Mac LAN address:

```sh
flutter build ipa --release --dart-define=LEARNING_API_URL=http://192.168.1.32:8084 --dart-define=ALLOW_LOCAL_DEMO_HTTP=true
```

Replace the address when the Mac's network changes. The opt-in permits only private IPv4 HTTP addresses; public HTTP remains blocked. Omit it and configure an HTTPS backend for a public release. Archiving and IPA export require working Xcode services, signing credentials, and provisioning. A successful archive does not establish installation or launch on a phone.

## Current learning experience

Lesson references appear once in the dedicated reference card, including all distinct entries from multi-source packs. Authoring prompts keep bibliographies out of lesson body text; legacy sourceName/sourceUrl attribution remains supported.

Pages start at the top on forward and back navigation. Opening a lesson does not restore its saved scroll position or erase its reading progress and assessment answers.

The icon-only teal button substitutes explained content on the same lesson page and switches back to regular content. Learners can opt into starting with explanations during profile setup and edit that preference later. Explanation packs show their version, are saved for offline reading, and support checking for updates. Published course version 4 includes explanation version 1 in all seven languages for the three original AI courses.

Choose **Teal light** or **Teal dark** under Profile → Appearance. The preference is saved on the device and works offline.

- Startup shows the Learn Anywhere logo and a spinner while local learning materials initialize. On first launch, learners choose English, French, Portuguese, Arabic, Hausa, Yorùbá, or Igbo. The choice is saved locally.
- One language preference controls app labels and lesson selection. Arabic supports right-to-left layout. Bundled app labels work offline; some dynamic catalog metadata and supporting messages may still appear in English.
- Discovery supports normal courses and courses containing ordered series parts. Understanding AI appears as one course with 16 weekly parts and 80 lessons, designed for roughly four months at a flexible pace.
- Each part contains five short lessons. Any chapter or final quiz can be opened directly; skipped lessons stay unread. Read lessons have a mint highlight, checkmark, and Read label; series cards show the number of lessons read.
- One final assessment follows the five lessons. Answers save without revealing correctness, explanations, or earned points during the assessment. Submission shows the score; Review answers reveals the learner's answers, correct answers, and explanations.
- Quiz completion and reading are separate states. Completion is labeled Completed. Practice cannot duplicate rewards. A practical task follows the assessment.
- Applying a language downloads its published pack when it is missing from the device. A spinner appears while downloading; a progress bar shows received bytes when the pack size is known. An unpublished language produces an availability message.
- User-facing storage messages say Ready offline or Saved on this device.

The current local catalog contains AI Foundations as a normal English course and Understanding AI as a series course. All 16 Understanding AI parts have published packs in seven languages: 112 packs representing the same 80 lessons and 240 questions across languages. The six new translations were machine-translated and explicitly approved by the owner for the local demo; bilingual expert certification has not been claimed.

The bundled Digital Safety starter remains available as an offline fallback. A preferred translation may be unavailable for a particular course; an available pack is used without discarding the saved preference.

## Offline storage and synchronization

Flutter uses SQLite for downloaded packs, cached catalog data, progress snapshots, and an event outbox. Installation tokens use iOS Keychain. Only an anonymous installation identity and necessary learning activity are collected; no learner account, email, or password is required.

Events remain pending until the backend acknowledges their IDs. Synchronization runs after app resume, periodically while active, and on manual request. PostgreSQL derives points and protects against duplicate rewards. Pack, lesson, question, and option identities remain stable across translations so changing languages preserves progress.

Sources remain visible under Reference for further reading. The current learner experience uses text packs. The backend accepts text, slides, and video metadata; Flutter slide/video playback and hosted media delivery are future work.

## Run locally

Use Flutter with Dart 3.10 or later, Xcode, and an installed iOS simulator runtime. Start the backend using [backend/README.md](backend/README.md).

```sh
cd frontend
flutter pub get
flutter config --enable-swift-package-manager
flutter devices
flutter run -d <ios-simulator-id> --dart-define=LEARNING_API_URL=http://127.0.0.1:8084
```

The Flutter development default is `http://127.0.0.1:8084`. Android emulators use `http://10.0.2.2:8084`; physical devices need a reachable service address. The client permits HTTP only for local development addresses. SQLite's iOS plugin uses Swift Package Manager in this project.

Local services:

| Service | Address |
|---|---|
| Updated backend | http://127.0.0.1:8084 |
| Swagger UI | http://127.0.0.1:8084/api/v1/swagger-ui/ |
| PostgreSQL | localhost:5432, database `learning` |
| Adminer database UI | http://127.0.0.1:8083 |

An older process on port 8082 may still expose a previous API; use port 8084 for the current catalog structure.

## API

| Request | Purpose |
|---|---|
| `GET /api/v1/courses` | Normal courses (`type: course`) and series courses (`type: series`) with ordered `parts` |
| `GET /api/v1/packs/{course-or-part-id}/{language}?version=1` | Download a versioned language pack; supports ETags |
| `POST /api/v1/installations` | Create an anonymous installation and issue its token |
| `POST /api/v1/progress/sync` | Submit idempotent learning events and receive acknowledged IDs and confirmed points |
| `POST /api/v1/admin/drafts` | Import content for review |
| `GET /api/v1/admin/drafts/{id}` | Inspect a draft |
| `POST /api/v1/admin/drafts/{id}/approve` | Explicitly approve and publish a draft |

Download and sync using a series part's ID, not the parent course ID. Draft content remains absent from learner download and catalog routes until approval.

## Validate

```sh
cd frontend
flutter analyze
flutter test test/ui_test.dart test/store_test.dart
cd ../backend
mvn clean install
```

The latest focused Flutter suite passes 24 tests, including startup ordering, language preference persistence, reading progression, delayed quiz feedback, answer review, and offline progress. The backend has seven backend tests (learning rules and transaction boundaries). Live checks verified the migrated course/series structure and all 112 Understanding AI pack downloads. Tests requiring a live service must use the current catalog rather than assume the original pilot records still exist.

## Proof-of-concept limits

Owner approval does not replace factual or bilingual expert review. Country-specific curricula, credentials, institutions, and opportunities need verified localization beyond translation. Cross-device restore, production staff authentication, media hosting, and secure high-stakes assessment remain future work.

See [backend architecture](backend/design/architecture.md) and the review documents under `frontend/assets/course-drafts/understanding-ai-languages/` for implementation and content details.

## Project guides

- [AGENTS.md](AGENTS.md): shared instructions and component guide index.
- [Frontend guide](frontend/AGENTS.md): Flutter UI, offline behavior, and validation.
- [Backend guide](backend/AGENTS.md): Java APIs, database, and synchronization.
- [CONTRIBUTING.md](CONTRIBUTING.md): setup, validation, and review workflow.
- [SECURITY.md](SECURITY.md): privacy, secrets, and reporting guidance.
- [Content review](docs/content-review.md): generation, approval, and publication workflow.

### Connected iPhone development

The current iOS Debug configuration uses `http://192.168.1.32:8084`. Run the backend with `APP_HOST=192.168.1.32 APP_PORT=8084`; keep the phone and Mac on the same Wi-Fi network and allow the app’s local-network permission. Update the Debug configuration if the Mac address changes. Private IPv4 HTTP is accepted only in debug builds.

Language changes keep the download panel open until download, validation, local saving, and application finish. Closing and repeat submission are disabled while it is busy; errors leave the panel open for retry.

The bell icon beside the series part count opens that series’s language download notifications with active transfer progress, saving status, completed packs, and failed downloads. Saved packs reappear after restarting the app; failed transfer notices are kept for the current session. The language picker also provides access to this list during a download.

Final assessment question numbering runs continuously across all lesson groups, with one progress bar for the full assessment.

Lessons include Read aloud, pause/resume, stop, and speed controls on iPhone. Native text-to-speech uses matching device voices; no per-lesson audio pack or cloud speech service is required. Voice availability varies by language and device; unavailable voices produce a clear message. Playback stops when leaving the lesson or backgrounding the app. Android speech integration remains future work.

## Local Wi-Fi sharing

On Device A, open a series and choose **Share over Wi-Fi → Start sharing this course**. On Device B, open **Downloads → Receive over Wi-Fi**, then enter A’s displayed address and sharing code. Keep both devices on the same Wi-Fi and the sender’s sharing page open. Allow Local Network access if iOS asks.

Only downloaded published lesson packs are copied; personal progress, installation tokens, and draft/preview packs are excluded. Device B saves them atomically and can study offline. Existing immutable pack versions cannot be overwritten with conflicting content. The sharing server closes when the sender leaves the page or backgrounds the app.

This proof of concept uses paired HTTP transfers over private IPv4 Wi-Fi addresses, with a random per-session access code and a 25 MB bundle limit. It shares the current text/diagram packs; hosted video/slides and automatic nearby discovery are not implemented. This is a local content transfer, not progress/account synchronization between learners.

Course catalog entries and series parts include `category`. Flutter displays it as Learning Category. Approval accepts an optional category (1–80 characters); new courses default to General Learning. Existing course categories remain unchanged when publishing translations.

## Course reading reminders

In Debug builds on iPhone, enable Course reading reminders under Profile. Notifications are opt-in and work offline. Release and Profile builds hide this setting, refuse reminder scheduling in Dart and native iOS, and cancel existing course-reading reminders without affecting other notifications. A recurring noon reminder says “[Selected course] — one chapter a day goes a long way.” Its course name follows the selected course. A second reminder is scheduled per day at a random local time between 9 AM and 7 PM, starting tomorrow. The next 30 days are scheduled, and reopening the app extends that window without changing existing times. Turning the setting off cancels pending course reminders. Notification permission and iOS Focus settings control delivery. Android and macOS notification support, server push delivery, and localized reminder messages are not implemented.

## Learning engagement and learner profile

After choosing a language, learners can optionally enter their age (1–120), gender, and a learning category. Skip for now continues without demographic details. Profile → Your learner profile allows changing or clearing those fields. They are stored locally and are not included in installation, course-request, or progress-sync API payloads. Category choices come from available catalog entries; Discover uses search without category filters.

Home has a daily challenge: read the selected goal of 1–3 lessons and try one optional lesson checkpoint. A weekly goal covers 1–7 study days. Goals and interest are saved offline; study streaks use local calendar days. Reading or practicing the same lesson repeatedly cannot increase the daily count or farm rewards. Scroll position is saved so Continue learning resumes the current unread lesson. Completing a lesson for the first time shows a short celebration that respects reduced-motion settings.

Lesson checkpoints offer a revealable recap and a short fill-in-the-blank practice based on existing published takeaways. They do not reveal final-assessment answers, award XP, or write quiz-answer events. Lessons without enough distinct takeaway words use reflection practice instead. Discover keeps catalog creation order without recommendation sections or category controls. New helper text follows the existing English fallback when a bundled translation is unavailable.

### On-device personalization and Ask ChatGPT

The adaptive coach is a small local policy, not an embedded ChatGPT model. It uses recent reading/practice activity, daily goals, and Helpful/Not for me feedback to suggest reading, recall practice or a recap. It keeps at most 90 activity records, considers the last 30 days, and estimates a daytime study hour only after at least five distinct study days. Completed daily goals offer rest or optional recap. Profile can disable activity collection and erase learned coaching patterns. Notification times are not silently changed.

Ask ChatGPT opens a preview of a short aggregate learning summary. The learner can copy it and open ChatGPT separately on iPhone (other platforms show the URL). Nothing is automatically submitted. Age, gender, course titles, assessment answers, raw logs and installation tokens are excluded. Users choose whether to paste the summary into their own ChatGPT account; its normal access and usage limits apply. The app does not embed the free ChatGPT service or add paid API inference for engagement.

Profile → Course reading reminders includes a test button that schedules one example of each reminder type after 60 seconds. Allow notifications and background the app to see them. Test requests replace earlier test requests and do not change the regular reminder schedule.

The optional learner profile now uses a date-of-birth picker with a clear action. Date of birth stays on-device and is excluded from the manual ChatGPT summary. Previously entered ages are not converted into guessed birth dates.

Learning Coach is now located in Profile settings alongside its controls. The Ask ChatGPT feature has been removed.

Lesson bookmarks are saved on-device with course progress. Use the lesson bookmark icon to save/remove a lesson, and the main toolbar bookmarks icon to view saved lessons in the selected course. Bookmarks do not mark lessons read or award XP.

Discover uses search without category filters or badges; the learning category control has been removed from Profile settings. Existing saved learning preferences remain preserved. The optional learner profile contains date of birth and gender only.

Optional AI learning help is available inside lessons: Explain this, Help me practise, and Reading suggestions. New requests require explicit confirmation and internet; saved replies remain on-device for offline reuse. Profile data, reading patterns, and assessment answers are excluded. Generated suggestions can be explicitly saved for local course reminders. Backend API configuration and billing are required; this is not a free embedded ChatGPT connection.

Reviewed explanation downloads: published course packs may include `explanations: {version: 1, lessons: [{id: 0, text: "..."}, ...]}` with all five ordered lessons. `GET /api/v1/explanations/{course}/{language}?version=N` returns `available`, course identity, and (when available) `explanationVersion` and lesson texts. This endpoint never calls AI. Explanations follow the existing draft review/approval process; changing published explanations requires a new immutable course version. Flutter downloads the whole explanation pack, saves it in device state, displays its version, and supports offline reading and checking for updates. Existing courses without explanations return `available:false`; no generated content has been published automatically.

On lesson pages, Explain this downloads the reviewed explanation pack with a loading indicator, then displays the selected lesson explanation. Saved explanations open immediately offline without an AI request.

Discover listens for catalog updates. Pull down or tap Refresh to fetch newly published courses; the refresh button shows a spinner during the request.

Catalog refresh completes independently of progress sync and confirms success or failure. Discover displays the preferred-language content version; open series pages use refreshed catalog parts rather than their original snapshot.

Profile settings include Font size decrease/increase controls (85–140%) and reset. The preference persists on-device and combines with system accessibility text scaling across the app.

The home screen uses a compact header and continuation card, with a language icon opening the existing language chooser. Legacy English lesson instructions are adapted for the current end-of-part assessment flow in both displayed text and read-aloud content.

Profile has a Settings heading and expandable VoiceOver help. Discover keeps search without category controls. Sharing is managed from Settings; lesson autoplay remains independent of VoiceOver.

Discover preserves catalog creation order, searches learner-facing course/part text, shows per-part quiz timing, and offers a request action for empty searches. Search and request controls use the active theme.

Discover shows the selected language name without a leading icon. Availability for all, some, or no current series parts remains available through accessibility labels and tooltips. Older translated versions do not imply availability for the current version.

Offline reading opens saved course and series packs before contacting the service, including saved older versions and available downloaded translations. Startup never requires an extra English download for an already-saved course. Series offers **Save all parts offline** while connected; parts not previously downloaded still require a connection. Language chooser actions use an icon on every screen, with the current language available to accessibility tools.

**Auto-download** in Settings is off by default. When enabled, opening a series saves its parts in the selected language. Each batch keeps the language selected at its start; an unavailable language is reported without silently downloading another translation. Offline reading continues using already-saved packs. **Save all parts** is hidden when all current parts are saved in the selected language and reappears when a part or translation is missing.

Teal dark uses charcoal teal backgrounds, distinct card surfaces, soft white headings, muted secondary text, and mint accents. Appearance supports switching back to Teal light and saves the chosen theme.

Course contents uses a compact reading-progress header and numbered lesson rows. Lesson reading separates the explanation, practice activity, and recap into spaced sections without changing the approved material. Source references remain visible. The course language control appears only in the toolbar; the duplicate footer control and prototype-format message are removed.

Learners can open any chapter, use Next lesson or swipe forward (left; right for Arabic), and open the final quiz directly. Skipping keeps unread lessons unread. Quiz results can sync independently of reading order.

Course and series contents show only languages saved on this device. Series language labels include the number of saved parts, so partial downloads are visible. Saved older versions remain represented for offline access.

QA refinements: Discover keeps the title and bookmark in one compact row and offers Clear search. Profile identifies the selected course; progress totals follow its lesson count. Downloads lists every locally saved course, its saved languages and storage size. Open course resumes offline learning; Manage languages opens course-specific download controls. Active transfers and download history are separate from saved content. Language availability is announced once by accessibility tools. Companion reminder actions appear only in Debug builds.

Courses and series parts have a material-dependent number of lessons, with ordered IDs starting at zero. Downloads, local sharing, progress, completion and the final quiz use the actual lesson count. Existing published packs remain unchanged.

Next lesson and forward swipes open the next chapter at the beginning, including previously read chapters. Opening a lesson directly retains its saved reading position. Reading progress is not cleared by moving to the next chapter.

New generated/imported drafts require each lesson to declare 5–15 minutes of reading, excluding quizzes and practice. Authoring must provide enough substantive text for that estimate; human review verifies pacing. The app displays pack duration metadata. Previously published packs are retained unchanged.

Home prioritizes a resume card with the next chapter and its reading estimate, followed by compact XP/streak stats and a straight chapter list. Reading progress is shown separately from quiz completion; the final quiz remains directly accessible.

For first use, Home invites the learner to Discover courses. Automatic language downloads do not count as course selection. Explicitly selected unopened courses show Start course; courses with reading activity show Continue learning. Course choices persist locally.

Lesson narration retains its active playback controls while scrolling offscreen and back; leaving the lesson still stops narration.

Home also lists other saved courses with reading activity, each with separate read progress and an offline resume action. Cards select the saved course version before opening its next unread lesson; untouched automatic downloads remain absent.

Course titles on Home and Discover use a consistent 20px hierarchy. Each course card shows its catalog category; long category labels truncate and reveal the full text on tap. Discover retains text search without category filters. Home labels the course group and identifies the active chapter list.

Discover course cards omit the standalone language label; language selection remains in the toolbar and course-level language controls.

Pages now open at the top on forward/back navigation and tab selection. Lessons retain reading progress while starting their scroll position at the beginning. Horizontal swipes/carousels are not reset by the page-start observer.

The lesson explanation toggle prefers reviewed explanations, can use saved supplementary AI help offline, and shows a spinner while loading. If no reviewed pack or configured provider exists, it keeps the regular lesson available and reports unavailability. New generated explanation drafts require approval before publication.

Toast feedback stays on its originating page. Navigating or changing tabs clears it; delayed responses from pages that are no longer active do not display messages elsewhere.
