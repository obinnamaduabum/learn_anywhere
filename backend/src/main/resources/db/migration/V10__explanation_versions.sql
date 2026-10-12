CREATE TABLE explanation_versions (
  id bigserial PRIMARY KEY,
  course_id text NOT NULL,
  course_version integer NOT NULL,
  language text NOT NULL,
  explanation_version integer NOT NULL CHECK (explanation_version > 0),
  payload jsonb NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','approved')),
  reviewed_by text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(course_id,course_version,language,explanation_version),
  FOREIGN KEY(course_id,course_version,language) REFERENCES language_packs(course_id,version,language)
);
