-- Prefer "Hard Disk" name match (catalog products do not use "HDD" in title).
UPDATE calculator_rules
SET action = jsonb_set(action, '{match,name_contains}', '"Hard Disk"'::jsonb)
WHERE rule_type = 'suggest'
  AND (
    name ILIKE '%HDD%'
    OR action -> 'match' ->> 'name_contains' ILIKE '%HDD%'
  );
