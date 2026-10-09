-- Existing records use their earliest recorded approval when available.
-- Records without historical timestamps use this migration's timestamp.
ALTER TABLE courses ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE course_series ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();

UPDATE course_series s SET created_at = history.created_at
FROM (SELECT course_id, min(reviewed_at) AS created_at FROM content_drafts
      WHERE status = 'approved' AND reviewed_at IS NOT NULL GROUP BY course_id) history
WHERE s.part_course_id = history.course_id;

UPDATE courses c SET created_at = history.created_at
FROM (SELECT COALESCE(s.course_id, d.course_id) AS course_id, min(d.reviewed_at) AS created_at
      FROM content_drafts d LEFT JOIN course_series s ON s.part_course_id = d.course_id
      WHERE d.status = 'approved' AND d.reviewed_at IS NOT NULL
      GROUP BY COALESCE(s.course_id, d.course_id)) history
WHERE c.id = history.course_id;

CREATE INDEX courses_created_at_idx ON courses (created_at DESC, id);
