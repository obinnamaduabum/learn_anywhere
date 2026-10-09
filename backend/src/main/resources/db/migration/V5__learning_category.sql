ALTER TABLE courses ADD COLUMN category text NOT NULL DEFAULT 'General Learning' CHECK (length(trim(category)) BETWEEN 1 AND 80);
UPDATE courses SET category = 'Artificial Intelligence' WHERE id IN ('understanding-ai', 'ai-foundations-v1');
