-- Public bucket for Sarvam TTS clips played on Twilio/Telnyx calls (<Play> needs HTTPS URL).
INSERT INTO storage.buckets (id, name, public)
VALUES ('bos-voice-audio', 'bos-voice-audio', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS bos_voice_audio_public_read ON storage.objects;
CREATE POLICY bos_voice_audio_public_read ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'bos-voice-audio');

DROP POLICY IF EXISTS bos_voice_audio_service_insert ON storage.objects;
CREATE POLICY bos_voice_audio_service_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'bos-voice-audio');
