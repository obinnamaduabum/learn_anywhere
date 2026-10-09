# Project agent guide

Learn Anywhere combines a Flutter frontend with a Quarkus Java/PostgreSQL backend.

## Choose the component guide

- **Frontend:** [frontend/AGENTS.md](frontend/AGENTS.md), covering Flutter UI, languages, offline storage, progress, and frontend validation. It also applies to frontend tests, assets, and platform integration.
- **Backend:** [backend/AGENTS.md](backend/AGENTS.md), covering Java interfaces, HTTP APIs, PostgreSQL, migrations, synchronization, and publication.

For changes spanning both components, read both guides and preserve their API and data contracts. The frontend lives in `frontend/`; backend code lives in `backend/`.

## Shared rules

Follow the user's current instructions and preserve unrelated work. Keep changes focused. Do not replace the stack, reset the database, publish content, or deploy services without authorization. Never expose tokens or private learner data in output or commits.

Generated content and translations require explicit approval before publication. Previous approval covers only the stated material. See [content review](docs/content-review.md).

Update affected documentation and run checks appropriate to the changed component. Report checks actually performed and remaining limitations; do not claim unverified builds, simulator runs, or publication.

## Release requests

Follow the [frontend release workflow](frontend/AGENTS.md) and [backend mobile release checks](backend/AGENTS.md) for release build, install, or run requests. Distinguish Debug/Release, simulator/physical device, successful build/install/launch, exported IPA, and verified phone-to-backend connectivity. Preserve app and database data; report only outcomes actually verified.

## Supporting documentation

- [Project overview](README.md)
- [Contribution workflow](CONTRIBUTING.md)
- [Security and privacy](SECURITY.md)
- [Backend setup](backend/README.md)
- [Architecture](backend/design/architecture.md)

## Backend service on run requests

When the user requests running or rerunning Learn Anywhere, check `http://127.0.0.1:8084/api/v1/health` before launching the iOS app. If the project backend is not running, start it from `backend/` using the existing configuration and the startup procedure in `backend/README.md` with Java 17 or later. Check required PostgreSQL availability and start the project's existing development dependency only as needed. Preserve the database, credentials, and configured ports; never reset or reseed data. Reuse a healthy service. After backend code changes, ensure it has reloaded or restart only the process identified as this project's backend. Never terminate an unrelated process occupying a port. Keep long-running service startup in a managed terminal session and verify the health endpoint before claiming it is running. Report missing configuration, dependency, permissions, or startup errors explicitly. The iOS-only app-run rule remains in effect.
