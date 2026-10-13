# Learn Anywhere database tables

Verified against Flyway migrations V1–V10 and the current Flutter SQLite creation statements. This is the schema defined by source, not an inspection of a running database. No records or credentials were read.

## PostgreSQL content and publication

```mermaid
erDiagram
    content_units ||--o| courses : "id"
    courses ||--o{ course_series : "parent course_id"
    content_units ||--o| course_series : "part_course_id"
    content_units ||--o{ course_releases : "course_id"
    course_releases ||--o{ language_packs : "course_id + version"
    language_packs ||--o{ explanation_versions : "course_id + version + language"
    content_units {
        text id PK
        text title
        text description
    }
    courses {
        text id PK,FK
        text title
        text description
        timestamptz created_at
        text category
        text approved_by
    }
    course_series {
        text course_id FK
        text part_course_id PK,FK
        integer part_index UK
        text title
        text description
        timestamptz created_at
    }
    course_releases {
        text course_id PK,FK
        integer version PK
        integer lesson_count
    }
    language_packs {
        text course_id PK,FK
        integer version PK,FK
        text language PK
        text review_status
        bytea payload
        integer standard_read_time_minutes
    }
    explanation_versions {
        bigint id PK
        text course_id FK,UK
        integer course_version FK,UK
        text language FK,UK
        integer explanation_version UK
        jsonb payload
        text status
        text reviewed_by
        timestamptz reviewed_at
        timestamptz created_at
    }
    content_drafts {
        bigint id PK
        text course_id
        text language
        text provider
        text model
        text status
        jsonb topics
        text reviewed_by
        timestamptz reviewed_at
        jsonb payload
        timestamptz created_at
        integer standard_read_time_minutes
    }
```

## PostgreSQL activity and administration

```mermaid
erDiagram
    installations ||--o{ course_progress : "installation_id"
    installations ||--o{ activity_events : "installation_id"
    installations ||--o{ course_requests : "installation_id"
    course_releases ||--o{ course_progress : "course_id + version"
    course_releases |o--o{ activity_events : "nullable release FK"
    content_drafts |o--o{ course_requests : "nullable draft_id"
    admin_users ||--o{ admin_sessions : "user_id"
    installations {
        uuid id PK
        bytea token_hash UK
        timestamptz created_at
    }
    course_progress {
        uuid installation_id PK,FK
        text course_id PK,FK
        integer version PK,FK
        jsonb state
        integer points
        timestamptz updated_at
    }
    activity_events {
        uuid installation_id PK,FK
        text event_id PK
        text course_id FK
        integer version FK
        text digest
        jsonb payload
        timestamptz received_at
    }
    course_requests {
        uuid id PK
        uuid installation_id FK,UK
        text title
        text language
        text source
        text status
        bigint draft_id FK
        timestamptz created_at
    }
    admin_users {
        uuid id PK
        text email UK
        text password_hash
        integer failed_logins
        timestamptz locked_until
        timestamptz created_at
    }
    admin_sessions {
        bytea token_hash PK
        uuid user_id FK
        timestamptz expires_at
        timestamptz created_at
    }
    course_releases {
        text course_id PK,FK
        integer version PK
        integer lesson_count
    }
    content_drafts {
        bigint id PK
        text course_id
        text language
        text provider
        text model
        text status
        jsonb topics
        text reviewed_by
        timestamptz reviewed_at
        jsonb payload
        timestamptz created_at
        integer standard_read_time_minutes
    }
```

## Key and relationship notes

- Solid relationships are declared foreign keys. `content_drafts.course_id` logically identifies `content_units.id`, but has **no enforced foreign key**. Drafts can precede creation of catalog records.
- V3 renames the original `courses` table to `content_units`; existing release and part foreign keys therefore point to `content_units`, not the new root catalog table.
- Composite primary keys: releases `(course_id, version)`; packs `(course_id, version, language)`; progress `(installation_id, course_id, version)`; events `(installation_id, event_id)`. Composite foreign keys use these same release/pack identities.
- Unique groups: series `(course_id, part_index)`; explanations `(course_id, course_version, language, explanation_version)`; requests `(installation_id, id)` (redundant with its globally unique primary key). UK markers within these groups do not mean each column is individually unique.
- `activity_events.course_id` and `version` are nullable in the migration; the release relationship is optional. `course_requests.draft_id` is nullable.
- Installation deletion cascades to progress and events; requests do not specify a delete cascade. Admin user deletion cascades to sessions.
- Lessons, questions, answers and explained lesson bodies are inside pack payloads rather than separate PostgreSQL lesson tables. Explanation versions reference a particular published language pack. `approved_by` is catalog metadata, not a publication action.
- Reading estimates in drafts and packs are generated stored columns, calculated from lesson-body words.

## Phone SQLite (separate database)

```mermaid
erDiagram
    state {
        INTEGER id PK
        TEXT json
    }
    catalog {
        INTEGER id PK
        TEXT json
    }
    packs {
        TEXT pack_key PK
        TEXT course_id
        INTEGER version
        TEXT language
        TEXT json
        TEXT saved_at
    }
    outbox {
        INTEGER sequence PK
        TEXT event_id UK
        TEXT course_id
        INTEGER version
        TEXT language
        TEXT event_json
    }
```

SQLite schema version 3 declares no foreign keys between these four tables. JSON state holds preferences and local progress; packs hold saved learning content; catalog caches discovery metadata; outbox retains activity awaiting acknowledgment. Pack identity and event payloads provide application-level links to backend content. Installation tokens are stored in platform secure storage, not a SQLite token table.

## Verification sources

- `backend/src/main/resources/db/migration/V1__initial.sql` through `V10__explanation_versions.sql` (all ten migrations read).
- `frontend/lib/store.dart`: current onCreate statements around lines 485–516 and pack/outbox schemas around lines 1452–1456.
- Root, backend and frontend `AGENTS.md`; architecture notes used as background, migrations used as authority.
