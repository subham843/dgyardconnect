-- AI Sales Agent MVP: indexes for handover queue + follow-ups (meta-based, no parallel ai_* tables)

CREATE INDEX IF NOT EXISTS idx_bos_leads_next_follow_up
  ON bos_leads (tenant_id, next_follow_up_at)
  WHERE deleted_at IS NULL AND next_follow_up_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_bos_leads_score
  ON bos_leads (tenant_id, score)
  WHERE deleted_at IS NULL AND score IS NOT NULL;

COMMENT ON COLUMN bos_leads.meta IS
  'AI sales: handover_ready, intent, ai_recommendation, budget, location, orchestrate history';
COMMENT ON COLUMN bos_voice_calls.meta IS
  'AI voice: summary, interest, objection, next_action, provider, VOICE_PROVIDER stub|exotel';
