# Contributing

Read [the project overview](README.md), [agent guide](AGENTS.md), and [backend setup](backend/README.md). This repository is a working proof of concept; keep changes small enough to review and preserve offline learning behavior.

## Component guides

Use the [frontend guide](frontend/AGENTS.md) for Flutter changes and the [backend guide](backend/AGENTS.md) for Java/API/database changes. Read both when changing synchronization or catalog contracts.

## Development setup

Use Flutter with the Dart version required by `pubspec.yaml`, Xcode for iOS, Java 17 or later, Maven, and Docker for the documented PostgreSQL/Adminer services. Follow the backend README for environment variables, migrations, and startup. Keep local secrets in ignored environment files.

The current development API is `http://127.0.0.1:8084`. Pass `--dart-define=LEARNING_API_URL=http://127.0.0.1:8084` when running Flutter on the iOS simulator. Android emulator networking uses `10.0.2.2`; physical devices need a reachable address.

## Before submitting a change

1. Explain the user-visible problem and resulting behavior.
2. Format changed Dart files with `dart format`; keep Java readable and use explicit imports.
3. Run checks appropriate to the changed component:

```sh
cd frontend
flutter analyze
flutter test test/ui_test.dart test/store_test.dart
```

For backend changes, from `backend`:

```sh
mvn clean install
```

4. Update affected setup, architecture, or API documentation.
5. Record checks that passed and anything that could not be verified.

Live tests require a running service and compatible catalog data. Do not reset the database merely to make a test pass. New schema changes belong in new Flyway migrations.

## Learning content

Follow [content review](docs/content-review.md). Keep generated content in drafts until explicit approval. A translation must preserve lesson/question identities and correct option positions. Published content changes require a new version rather than replacing immutable packs.

## Review information

Include a concise description, relevant validation, screenshots for material UI changes when available, and migration or compatibility implications. Do not commit build output, credentials, installation tokens, or learner activity exports.
