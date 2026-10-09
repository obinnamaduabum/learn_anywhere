CREATE TABLE course_requests (
 id uuid PRIMARY KEY, installation_id uuid NOT NULL REFERENCES installations(id),
 title text NOT NULL CHECK(length(title) BETWEEN 1 AND 160), language text NOT NULL,
 source text NOT NULL CHECK(source IN ('ai','human')), status text NOT NULL,
 draft_id bigint REFERENCES content_drafts(id), created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(installation_id,id)
);
CREATE INDEX course_requests_quota_idx ON course_requests(installation_id,created_at) WHERE source='ai';
