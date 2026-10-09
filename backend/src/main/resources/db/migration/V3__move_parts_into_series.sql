-- Stable content identities retain release, pack, event and progress references.
ALTER TABLE courses RENAME TO content_units;

CREATE TABLE courses (
    id text PRIMARY KEY REFERENCES content_units(id),
    title text NOT NULL,
    description text NOT NULL
);

INSERT INTO courses (id, title, description)
SELECT id, title, description FROM content_units
WHERE id NOT IN (SELECT part_course_id FROM course_series);

ALTER TABLE course_series
    DROP CONSTRAINT course_series_course_id_fkey;
ALTER TABLE course_series
    ADD CONSTRAINT course_series_course_id_fkey
    FOREIGN KEY (course_id) REFERENCES courses(id);

ALTER TABLE course_series ADD COLUMN title text;
ALTER TABLE course_series ADD COLUMN description text;
UPDATE course_series series
SET title = unit.title, description = unit.description
FROM content_units unit WHERE unit.id = series.part_course_id;
ALTER TABLE course_series ALTER COLUMN title SET NOT NULL;
ALTER TABLE course_series ALTER COLUMN description SET NOT NULL;
