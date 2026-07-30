-- Seed HD CCTV and IP CCTV calculator families (catalog products added separately by admin)

INSERT INTO calculator_families (name, slug, description, sort_order)
VALUES
  ('HD CCTV', 'hd-cctv', 'Analog HD camera systems', 1),
  ('IP CCTV', 'ip-cctv', 'Network IP camera systems', 2)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO calculator_templates (family_id, name, slug, version, is_published)
SELECT f.id, 'HD CCTV Standard', 'hd-cctv-standard', 1, true
FROM calculator_families f WHERE f.slug = 'hd-cctv'
ON CONFLICT DO NOTHING;

INSERT INTO calculator_templates (family_id, name, slug, version, is_published)
SELECT f.id, 'IP CCTV Standard', 'ip-cctv-standard', 1, true
FROM calculator_families f WHERE f.slug = 'ip-cctv'
ON CONFLICT DO NOTHING;

-- HD CCTV questions
INSERT INTO calculator_questions (template_id, question_key, label, ui_type, options, sort_order)
SELECT t.id, q.key, q.label, q.ui_type, q.options::jsonb, q.sort_order
FROM calculator_templates t
JOIN calculator_families f ON f.id = t.family_id AND f.slug = 'hd-cctv'
CROSS JOIN (VALUES
  ('camera_qty', 'Camera Quantity', 'number', NULL, 1),
  ('resolution', 'Resolution', 'select', '["2MP","4MP","5MP","8MP"]', 2),
  ('storage_days', 'Storage Days', 'number', NULL, 3)
) AS q(key, label, ui_type, options, sort_order)
WHERE t.slug = 'hd-cctv-standard'
ON CONFLICT (template_id, question_key) DO NOTHING;

-- IP CCTV questions
INSERT INTO calculator_questions (template_id, question_key, label, ui_type, options, sort_order)
SELECT t.id, q.key, q.label, q.ui_type, q.options::jsonb, q.sort_order
FROM calculator_templates t
JOIN calculator_families f ON f.id = t.family_id AND f.slug = 'ip-cctv'
CROSS JOIN (VALUES
  ('camera_qty', 'Camera Quantity', 'number', NULL, 1),
  ('resolution', 'Resolution', 'select', '["2MP","4MP","5MP","8MP"]', 2)
) AS q(key, label, ui_type, options, sort_order)
WHERE t.slug = 'ip-cctv-standard'
ON CONFLICT (template_id, question_key) DO NOTHING;

-- HD CCTV rules (product suggestions require admin-linked products)
INSERT INTO calculator_rules (template_id, rule_type, name, priority, condition, action)
SELECT t.id, r.rule_type::calculator_rule_type, r.name, r.priority, r.condition::jsonb, r.action::jsonb
FROM calculator_templates t
JOIN calculator_families f ON f.id = t.family_id AND f.slug = 'hd-cctv'
CROSS JOIN (VALUES
  ('suggest', 'Suggest DVR', 10, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"suggest_product","match":{"sub_category_slug":"recording-devices","name_contains":"DVR"},"qty_formula":"1"}'),
  ('suggest', 'Suggest SMPS', 20, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"suggest_product","match":{"sub_category_slug":"power-supply","name_contains":"SMPS"},"qty_formula":"1"}'),
  ('suggest', 'Suggest HDD', 30, '{"all":[{"var":"storage_days","op":"gte","value":1}]}', '{"type":"suggest_product","match":{"sub_category_slug":"storage-devices","name_contains":"HDD"},"qty_formula":"1"}'),
  ('formula', 'BNC quantity', 40, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"formula","output_key":"bnc_qty","expression":"camera_qty * 2"}'),
  ('formula', 'DC Connector quantity', 50, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"formula","output_key":"dc_connector_qty","expression":"camera_qty"}')
) AS r(rule_type, name, priority, condition, action)
WHERE t.slug = 'hd-cctv-standard';

INSERT INTO calculator_rules (template_id, rule_type, name, priority, condition, action)
SELECT t.id, r.rule_type::calculator_rule_type, r.name, r.priority, r.condition::jsonb, r.action::jsonb
FROM calculator_templates t
JOIN calculator_families f ON f.id = t.family_id AND f.slug = 'ip-cctv'
CROSS JOIN (VALUES
  ('suggest', 'Suggest NVR', 10, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"suggest_product","match":{"sub_category_slug":"recording-devices","name_contains":"NVR"},"qty_formula":"1"}'),
  ('suggest', 'Suggest POE Switch', 20, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"suggest_product","match":{"sub_category_slug":"network-switches","name_contains":"PoE"},"qty_formula":"1"}'),
  ('suggest', 'Suggest HDD', 30, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"suggest_product","match":{"sub_category_slug":"storage-devices","name_contains":"HDD"},"qty_formula":"1"}'),
  ('formula', 'Cat6 quantity', 40, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"formula","output_key":"cat6_qty","expression":"camera_qty * 50"}'),
  ('formula', 'RJ45 quantity', 50, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"formula","output_key":"rj45_qty","expression":"camera_qty * 2"}')
) AS r(rule_type, name, priority, condition, action)
WHERE t.slug = 'ip-cctv-standard';
