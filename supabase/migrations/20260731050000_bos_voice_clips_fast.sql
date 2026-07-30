-- Ephemeral TTS clips for Twilio <Play> without Storage upload latency.
CREATE TABLE IF NOT EXISTS bos_voice_clips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID,
  call_id UUID,
  content_type TEXT NOT NULL DEFAULT 'audio/mpeg',
  audio_b64 TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bos_voice_clips_created
  ON bos_voice_clips (created_at);

ALTER TABLE bos_voice_clips ENABLE ROW LEVEL SECURITY;

-- Edge functions use service role (bypass RLS). No public table access.
DROP POLICY IF EXISTS bos_voice_clips_deny_all ON bos_voice_clips;
CREATE POLICY bos_voice_clips_deny_all ON bos_voice_clips
  FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
