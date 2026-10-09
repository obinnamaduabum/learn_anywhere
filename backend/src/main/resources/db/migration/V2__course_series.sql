-- A course can own ordered study parts. Existing pack identities stay stable,
-- so downloaded lessons, sync events and earned points remain valid.
CREATE TABLE course_series (
    course_id text NOT NULL REFERENCES courses(id),
    part_course_id text PRIMARY KEY REFERENCES courses(id),
    part_index integer NOT NULL CHECK (part_index > 0),
    UNIQUE (course_id, part_index),
    CHECK (course_id <> part_course_id)
);

INSERT INTO courses (id, title, description)
VALUES ('understanding-ai', 'Understanding AI',
        'A four-month learning journey through 16 weekly parts, from AI foundations to a practical project.');

INSERT INTO course_series (course_id, part_course_id, part_index)
SELECT 'understanding-ai', id, substring(id FROM 'week-([0-9]+)$')::integer
FROM courses
WHERE id ~ '^understanding-ai-week-[0-9]+$';
