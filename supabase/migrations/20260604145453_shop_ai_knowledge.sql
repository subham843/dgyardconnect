-- Local AI knowledge: cache learned text-assist outputs (fewer Groq/Gemini/OpenAI calls)

CREATE TABLE IF NOT EXISTS shop_ai_knowledge (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action TEXT NOT NULL,
  input_hash TEXT NOT NULL,
  input_text TEXT,
  context_json JSONB,
  language TEXT,
  output_text TEXT NOT NULL,
  source_provider TEXT,
  hit_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (action, input_hash)
);

CREATE INDEX IF NOT EXISTS idx_shop_ai_knowledge_action ON shop_ai_knowledge (action);
CREATE INDEX IF NOT EXISTS idx_shop_ai_knowledge_hits ON shop_ai_knowledge (hit_count DESC);

ALTER TABLE shop_ai_knowledge ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shop_ai_knowledge_read ON shop_ai_knowledge;
CREATE POLICY shop_ai_knowledge_read ON shop_ai_knowledge FOR SELECT
  USING (auth_is_superadmin());

DROP POLICY IF EXISTS shop_ai_knowledge_write ON shop_ai_knowledge;
CREATE POLICY shop_ai_knowledge_write ON shop_ai_knowledge FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

COMMENT ON TABLE shop_ai_knowledge IS 'Learned copy/SEO suggestions; Edge Function reads before external AI';
