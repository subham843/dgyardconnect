-- Calculator no-code engine + quotations

CREATE TYPE calculator_rule_type AS ENUM (
  'suggest', 'formula', 'visibility', 'dependency', 'recommendation'
);

CREATE TYPE quotation_status AS ENUM ('draft', 'sent', 'accepted', 'rejected', 'expired');

CREATE TABLE IF NOT EXISTS calculator_families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS calculator_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES calculator_families (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  version INT NOT NULL DEFAULT 1,
  is_published BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (family_id, slug, version)
);

CREATE TABLE IF NOT EXISTS calculator_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES calculator_templates (id) ON DELETE CASCADE,
  question_key TEXT NOT NULL,
  label TEXT NOT NULL,
  ui_type TEXT NOT NULL DEFAULT 'number',
  options JSONB,
  sort_order INT NOT NULL DEFAULT 0,
  default_visibility BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (template_id, question_key)
);

CREATE TABLE IF NOT EXISTS calculator_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES calculator_templates (id) ON DELETE CASCADE,
  rule_type calculator_rule_type NOT NULL,
  name TEXT,
  priority INT NOT NULL DEFAULT 100,
  condition JSONB NOT NULL DEFAULT '{}',
  action JSONB NOT NULL DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_calculator_rules_template ON calculator_rules (template_id, priority);

CREATE TABLE IF NOT EXISTS calculator_rule_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_id UUID NOT NULL REFERENCES calculator_rules (id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  default_qty INT NOT NULL DEFAULT 1,
  UNIQUE (rule_id, product_id)
);

CREATE TABLE IF NOT EXISTS calculator_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL,
  template_id UUID NOT NULL REFERENCES calculator_templates (id) ON DELETE RESTRICT,
  answers JSONB NOT NULL DEFAULT '{}',
  result JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS quotations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL,
  session_id UUID REFERENCES calculator_sessions (id) ON DELETE SET NULL,
  template_id UUID REFERENCES calculator_templates (id) ON DELETE SET NULL,
  status quotation_status NOT NULL DEFAULT 'draft',
  customer_name TEXT,
  notes TEXT,
  subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS quotation_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quotation_id UUID NOT NULL REFERENCES quotations (id) ON DELETE CASCADE,
  product_id UUID REFERENCES products (id) ON DELETE SET NULL,
  line_type TEXT NOT NULL DEFAULT 'product',
  label TEXT NOT NULL,
  sku TEXT,
  qty NUMERIC(12, 2) NOT NULL DEFAULT 1,
  unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  line_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  source_rule_id UUID REFERENCES calculator_rules (id) ON DELETE SET NULL,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE TRIGGER trg_calculator_families_updated BEFORE UPDATE ON calculator_families FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_calculator_templates_updated BEFORE UPDATE ON calculator_templates FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_calculator_questions_updated BEFORE UPDATE ON calculator_questions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_calculator_rules_updated BEFORE UPDATE ON calculator_rules FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_calculator_sessions_updated BEFORE UPDATE ON calculator_sessions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_quotations_updated BEFORE UPDATE ON quotations FOR EACH ROW EXECUTE FUNCTION set_updated_at();
