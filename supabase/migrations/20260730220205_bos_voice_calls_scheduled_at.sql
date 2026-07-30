-- AI follow-up calls: optional schedule time on voice queue
ALTER TABLE bos_voice_calls
  ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_bos_voice_calls_tenant_scheduled
  ON bos_voice_calls (tenant_id, scheduled_at)
  WHERE status IN ('queued', 'ringing', 'in_progress');
