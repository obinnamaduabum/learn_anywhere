-- Reading estimates belong to a language/version, not one global course label.
-- This fixed policy counts Unicode whitespace-delimited body words at 200/minute,
-- rounding each lesson up before summing. Quiz and activity execution are excluded.
CREATE FUNCTION learning_standard_read_time_minutes(pack jsonb)
RETURNS integer
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
AS $function$
    SELECT COALESCE(SUM(
        CASE WHEN normalized.body = '' THEN 0
             ELSE (cardinality(regexp_split_to_array(normalized.body,
                 U&'[\0009-\000D\001C-\0020\0085\00A0\1680\2000-\200A\2028\2029\202F\205F\3000]+')) + 199) / 200
        END
    ), 0)::integer
    FROM jsonb_array_elements(COALESCE(pack -> 'lessons', '[]'::jsonb)) AS lesson
    CROSS JOIN LATERAL (
        SELECT regexp_replace(COALESCE(lesson ->> 'body', ''),
            U&'^[\0009-\000D\001C-\0020\0085\00A0\1680\2000-\200A\2028\2029\202F\205F\3000]+|[\0009-\000D\001C-\0020\0085\00A0\1680\2000-\200A\2028\2029\202F\205F\3000]+$', '', 'g') AS body
    ) AS normalized;
$function$;

CREATE FUNCTION learning_pack_standard_read_time_minutes(pack bytea)
RETURNS integer
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
AS $function$
    SELECT learning_standard_read_time_minutes(convert_from(pack, 'UTF8')::jsonb);
$function$;

ALTER TABLE content_drafts
    ADD COLUMN standard_read_time_minutes integer
    GENERATED ALWAYS AS (learning_standard_read_time_minutes(payload)) STORED;

ALTER TABLE language_packs
    ADD COLUMN standard_read_time_minutes integer
    GENERATED ALWAYS AS (learning_pack_standard_read_time_minutes(payload)) STORED;

ALTER TABLE content_drafts
    ADD CONSTRAINT content_drafts_read_time_nonnegative CHECK (standard_read_time_minutes >= 0);

ALTER TABLE language_packs
    ADD CONSTRAINT language_packs_read_time_nonnegative CHECK (standard_read_time_minutes >= 0);

COMMENT ON COLUMN content_drafts.standard_read_time_minutes IS
    'Sum of lesson-body reading estimates: ceil(body words / 200) per lesson, in minutes. Not quiz/practice duration.';
COMMENT ON COLUMN language_packs.standard_read_time_minutes IS
    'Language/version-specific reading estimate from published body text, in minutes. Legacy payload labels are ignored.';
