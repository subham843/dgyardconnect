-- DVR/NVR quantity should be 1 unit (channel sizing is product selection), not camera_qty.
UPDATE calculator_rules
SET action = (action - 'qty_var') || '{"qty_formula":"1"}'::jsonb
WHERE rule_type = 'suggest'
  AND name ILIKE ANY (ARRAY['%DVR%', '%NVR%'])
  AND action ? 'qty_var';
