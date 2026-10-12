-- Optional approver metadata for catalog records; does not publish lesson packs.
ALTER TABLE courses ADD COLUMN approved_by text;

UPDATE courses
SET approved_by = 'AI'
WHERE id IN (
  'elements-of-ai-introduction',
  'cisco-introduction-to-modern-ai',
  'kaggle-intro-to-machine-learning'
);
