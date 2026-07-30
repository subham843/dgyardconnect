-- How family attribute options become calculator questions:
--   select     = one dropdown question with options
--   per_option = one number question per selected option (e.g. Dome qty, Bullet qty)

ALTER TABLE calculator_family_attributes
  ADD COLUMN IF NOT EXISTS question_mode TEXT NOT NULL DEFAULT 'select';

ALTER TABLE calculator_family_attributes
  DROP CONSTRAINT IF EXISTS calculator_family_attributes_question_mode_check;

ALTER TABLE calculator_family_attributes
  ADD CONSTRAINT calculator_family_attributes_question_mode_check
  CHECK (question_mode IN ('select', 'per_option'));

COMMENT ON COLUMN calculator_family_attributes.question_mode IS
  'select = one select question; per_option = separate number question per option';
