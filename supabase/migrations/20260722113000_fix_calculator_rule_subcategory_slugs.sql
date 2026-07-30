-- Fix calculator suggest rules to match real shop subcategory slugs.
-- Old seed used dvr/smps/hdd/nvr/poe-switch; catalog uses recording-devices, power-supply, etc.

UPDATE calculator_rules
SET action = jsonb_set(
  action,
  '{match,sub_category_slug}',
  '"recording-devices"'::jsonb
)
WHERE rule_type = 'suggest'
  AND action -> 'match' ->> 'sub_category_slug' = 'dvr';

UPDATE calculator_rules
SET action = jsonb_set(
  action,
  '{match,sub_category_slug}',
  '"recording-devices"'::jsonb
)
WHERE rule_type = 'suggest'
  AND action -> 'match' ->> 'sub_category_slug' = 'nvr';

UPDATE calculator_rules
SET action = jsonb_set(
  action,
  '{match,sub_category_slug}',
  '"power-supply"'::jsonb
)
WHERE rule_type = 'suggest'
  AND action -> 'match' ->> 'sub_category_slug' = 'smps';

UPDATE calculator_rules
SET action = jsonb_set(
  action,
  '{match,sub_category_slug}',
  '"storage-devices"'::jsonb
)
WHERE rule_type = 'suggest'
  AND action -> 'match' ->> 'sub_category_slug' = 'hdd';

UPDATE calculator_rules
SET action = jsonb_set(
  action,
  '{match,sub_category_slug}',
  '"network-switches"'::jsonb
)
WHERE rule_type = 'suggest'
  AND action -> 'match' ->> 'sub_category_slug' = 'poe-switch';

-- Keep a name hint so DVR vs NVR can be distinguished under recording-devices.
UPDATE calculator_rules
SET action = jsonb_set(action, '{match,name_contains}', '"DVR"'::jsonb)
WHERE name ILIKE '%DVR%'
  AND rule_type = 'suggest'
  AND action -> 'match' ->> 'sub_category_slug' = 'recording-devices';

UPDATE calculator_rules
SET action = jsonb_set(action, '{match,name_contains}', '"NVR"'::jsonb)
WHERE name ILIKE '%NVR%'
  AND rule_type = 'suggest'
  AND action -> 'match' ->> 'sub_category_slug' = 'recording-devices';

UPDATE calculator_rules
SET action = jsonb_set(action, '{match,name_contains}', '"HDD"'::jsonb)
WHERE name ILIKE '%HDD%'
  AND rule_type = 'suggest';

UPDATE calculator_rules
SET action = jsonb_set(action, '{match,name_contains}', '"SMPS"'::jsonb)
WHERE name ILIKE '%SMPS%'
  AND rule_type = 'suggest';

UPDATE calculator_rules
SET action = jsonb_set(action, '{match,name_contains}', '"PoE"'::jsonb)
WHERE name ILIKE '%POE%'
  AND rule_type = 'suggest';
