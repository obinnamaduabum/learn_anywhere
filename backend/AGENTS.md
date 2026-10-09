# Backend agent guide

## Scope and architecture

This guide covers `backend/`: Quarkus Java, PostgreSQL, migrations, API contracts, configuration, and backend tests. Read the [root guide](../AGENTS.md), [backend README](README.md), and [architecture](design/architecture.md).


Use Java 17 or later, Quarkus, and the resource → service → repository interfaces. Import explicit classes; never use wildcard Java imports. Keep HTTP handling, business rules, and SQL concerns in their respective layers.

Use a new versioned Flyway migration for schema changes. Do not edit already-applied migrations. `courses` contains root catalog entries; `course_series` relates ordered parts to parents; `content_units` preserves identities used by packs and progress. Use part IDs for downloads and synchronization. Preserve existing records and foreign keys. A destructive reset requires explicit authorization and a recoverable backup.

The documented development API is port 8084, Adminer is 8083, and PostgreSQL database `learning` is on 5432. Do not stop an unrelated process merely because it occupies an older port.

## Synchronization rules

Preserve installation locking, event digest validation, acknowledgment semantics, and transactional reward deduplication. Replaying an identical event must remain idempotent; a reused ID with a changed payload must be rejected. Calculate confirmed points on the server and preserve progress across language changes through stable content identities.

## Content publication


Generated material and translations must remain drafts until the user explicitly approves publication. Earlier approval covers only the stated content, not future changes. Follow [content review](../docs/content-review.md). Preserve immutable published pack versions and quiz identities. Cite credible sources and distinguish owner approval from factual or bilingual expert review. Do not invent credentials, opportunities, source verification, or a free ChatGPT API integration.

The admin pack API does not implement series management. Do not claim otherwise or add a live AI provider without a defined requirement.

## Backend checks for mobile releases

For a local mobile release/run, reuse a healthy API or start the existing `learn-anywhere` Compose stack with its current configuration. Preserve the PostgreSQL volume and credentials; never reset or reseed for a release. The API publishes port 8084 on the Mac's network interfaces; PostgreSQL 5432 and Adminer 8083 remain localhost-only. Host dev runs use `APP_HOST=0.0.0.0 APP_PORT=8084` for Wi-Fi access. Verify `/api/v1/health` and `/api/v1/courses` at both loopback and the app's configured Mac LAN address. State whether verification was from the Mac or from the phone. If Docker, firewall rules, or wireless client isolation block access, report the concrete failure. Do not claim the phone connected based only on a running container. Recreate only the project API when applying its port mapping, and do not remove database volumes. Refer to the frontend release workflow for signing, build mode, installation, and launch checks.

## Validation and documentation

Run `mvn clean install` from `backend` using a supported JDK. Compatibility edits do not make Quarkus compatible with Java 8. Run relevant integration checks against the current catalog and document any checks that could not run. Never reset or reseed learner data as a routine build step.

Update OpenAPI documentation for changed endpoints or payloads, and update the backend README and architecture document for schema or configuration changes.
