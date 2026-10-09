BEGIN;
CREATE TABLE courses(id text PRIMARY KEY,title text NOT NULL,description text NOT NULL);
CREATE TABLE course_releases(course_id text REFERENCES courses(id),version integer CHECK(version>0),lesson_count integer CHECK(lesson_count>0),PRIMARY KEY(course_id,version));
CREATE TABLE language_packs(course_id text,version integer,language text,review_status text NOT NULL,payload bytea NOT NULL,PRIMARY KEY(course_id,version,language),FOREIGN KEY(course_id,version) REFERENCES course_releases(course_id,version));
CREATE TABLE installations(id uuid PRIMARY KEY,token_hash bytea UNIQUE NOT NULL,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE course_progress(installation_id uuid REFERENCES installations(id) ON DELETE CASCADE,course_id text,version integer,state jsonb NOT NULL,points integer NOT NULL CHECK(points>=0),updated_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(installation_id,course_id,version),FOREIGN KEY(course_id,version) REFERENCES course_releases(course_id,version));
CREATE TABLE activity_events(installation_id uuid REFERENCES installations(id) ON DELETE CASCADE,event_id text,course_id text,version integer,digest text NOT NULL,payload jsonb NOT NULL,received_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(installation_id,event_id),FOREIGN KEY(course_id,version) REFERENCES course_releases(course_id,version));
CREATE TABLE content_drafts(id bigserial PRIMARY KEY,course_id text NOT NULL,language text NOT NULL,provider text NOT NULL,model text NOT NULL,status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','approved','rejected')),topics jsonb NOT NULL,reviewed_by text,reviewed_at timestamptz,payload jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT now());
COMMIT;
