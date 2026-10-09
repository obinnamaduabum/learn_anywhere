# Flutter frontend agent guide

## Scope

This guide covers Flutter code in `frontend/`. Follow it also when changing frontend tests, assets, `pubspec.yaml`, or platform integration. Read the [root guide](../AGENTS.md) and [project README](../README.md). Run Flutter commands from `frontend/`.

## Learning experience


- Preserve the calm teal interface and Learn Anywhere startup logo. Support saved Teal light and Teal dark choices under Profile → Appearance.
- First launch asks for English, French, Portuguese, Arabic, Hausa, Yorùbá, or Igbo. One saved preference controls the app and content. Support Arabic right-to-left layout.
- Download a missing published language pack with a persistent spinner and progress bar; prevent dismissal during download and application. Show a clear availability message if it is unavailable. Retain the preference when using fallback content.
- Show normal courses and series courses. Open a series parent to show its ordered parts.
- Keep category filters in Discover, not Profile settings. Show preferred-language availability from each content unit's currently advertised packs; a parent language union does not mean every series part is translated.
- Course-reading reminders are Debug-only. Release/Profile must hide the setting and block native/Dart scheduling, canceling only existing course-reading reminders. Preserve other notification features.
- Highlight read lessons and show partial reading progress. Reading unlocks the next lesson; reading and quiz completion are separate states.
- Put the assessment after all five lessons in a part. Reveal the score after submission and correctness/explanations only in answer review. Keep Next/Submit accessible without scrolling.
- Keep source references visible. Use learner-facing messages such as “Ready offline” or “Saved on this device”; do not expose SQLite terminology in the UI.
- Do not advertise slide or video playback as implemented until it works.

## Offline data and synchronization

Persist packs, preferences, reading progress, answers, and pending events on the device. Preserve stable course/part, lesson, question, and option identities across translations. Retain pending events until the server acknowledges their IDs. Keep retry behavior idempotent and prevent repeated rewards. Treat backend-confirmed points as authoritative; do not lose unsynchronized activity during language changes or downloads. Keep installation tokens in platform secure storage.

## MCP QA improvements

The user authorizes the MCP QA agent to implement focused frontend UI improvements found during review. Inspect and prioritize findings, preserve unrelated work, implement the authorized improvement, validate with relevant analysis/tests, automatically rerun the selected iOS app, capture fresh screenshots when tooling permits, and update the living `mcp.md` QA record. Report source-only findings and blocked visual checks accurately. Preserve separate lesson autoplay and VoiceOver accessibility behavior. This permission does not authorize destructive data resets, publication of generated learning content, unrelated package installation, or privacy-sensitive changes.

## Implementation and validation

Keep UI, catalog models, localized labels, and persistent learning state consistent. Use the existing store and offline database rather than introducing a second source of progress state. Maintain loading, unavailable-content, and retry states.

Format changed Dart files with `dart format`. Run:

```sh
flutter analyze
flutter test test/ui_test.dart test/store_test.dart
```

Use live synchronization tests only with a running backend and a compatible current catalog. Verify relevant startup, navigation, reading, assessment, localization, and offline behavior. Update the project README when the learner experience changes.

The development API is `http://127.0.0.1:8084`. Use `10.0.2.2:8084` for an Android emulator and a reachable address for a physical device. See the backend README for server setup.

## Release workflow

When the user requests a release build or installation:

1. Read the root and frontend guides, inspect the current version, signing team, bundle ID, and backend endpoint. Honor the latest selected iOS target; the user selected iPhone 17 for the current UI evaluation. Do not silently switch platforms.
2. Use **Runner Release** for an optimized physical-device build without debugger attachment. Keep **Runner** as Debug for hot reload and Flutter MCP inspection. iOS simulators require Debug for this workflow; do not claim a simulator Debug build is a Release build.
3. For the explicitly authorized local demo, retain `ALLOW_LOCAL_DEMO_HTTP=true` and a reachable Mac Wi-Fi endpoint in Release configuration. Public distribution must omit this opt-in and use HTTPS. Never bake provider keys, admin credentials, or reset flags into mobile defines.
4. Verify the existing backend health endpoint before app launch. Start the existing Compose stack if needed, preserve its database volume, and apply the API's Wi-Fi port mapping. Confirm both loopback health and health/catalog access at the configured LAN address. A successful Mac request does not establish phone connectivity.
5. Confirm Swift Package Manager is enabled for the project and the generated plugin package includes `sqflite_darwin`. Regenerate iOS configuration after dependency changes and after Flutter commands that leave the generated package empty. Resolve existing package versions in Xcode. Clean only generated build products if stale modules remain; preserve app data.
6. Run relevant analysis/tests for changes before regenerating final native configuration. Prefer the normal Flutter release command. If command-line Apple services are inaccessible, inspect Xcode's actual state and report the limitation. Never bypass an explicit permission denial.
7. Build, install over the existing app, and launch on the selected connected physical iPhone. Use Xcode when the authorized GUI workflow is available. Cancel a blocked run when switching targets. If the phone is locked, report that it must be unlocked; do not reset/uninstall to solve a launch issue.
8. Verify Release configuration and debugger settings, successful build, installed artifact, and Xcode's running status or another supported launch confirmation. Report build, installation, launch, and backend connectivity separately. Inspect the phone UI or successful in-app sync when permitted before claiming end-to-end connection.
9. Export an IPA only when requested/needed and signing permits it. A running Release app is not an exported IPA or an App Store submission. Never claim distribution or production readiness from build success alone.
10. Update affected documentation and state the selected device, actual outcomes, and remaining blockers. For MCP evaluation, temporarily use Debug and restore Release afterward unless the user chooses a new simulator target. MCP attachment requires a reachable VM service; connection errors are not passed UI checks.

Useful commands: `bash scripts/run-ios.sh --release --device <iPhone-ID>` and `bash scripts/run-ios.sh --debug --device <iPhone-ID>`. The script checks backend health and detects the current Mac Wi-Fi address; use `LEARNING_API_URL` when automatic detection is unavailable. Xcode-only runs use the endpoint in the relevant xcconfig, which must be updated when the Mac's LAN address changes.

## Automatically rerun the mobile app

After changing Flutter code, mobile assets, or platform integration, complete the relevant validation and automatically rebuild and rerun the app without asking for another confirmation. Use the user's selected connected iPhone 14 Pro Max (Kobi’s iPhone) unless they select another target. Include documentation-only changes when the user explicitly requests a rerun; otherwise documentation edits do not require a rebuild.

Preserve device data and preferences. Verify that the latest build is running on the selected device before claiming completion. If the phone is locked, disconnected, or signing prevents launch, report the specific blocker and the action needed from the user. Do not claim that a successful build alone proves the app launched.

For app run/rerun requests, check backend health and start it if unavailable according to the root guide. Reuse a healthy backend; restart it only when backend changes require it or the user explicitly requests a restart. Preserve the existing database and use the current versioned API configuration.
