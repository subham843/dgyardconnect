-- Service role uploads TTS clips; upsert needs UPDATE; public read for Twilio <Play>.
DROP POLICY IF EXISTS bos_voice_audio_public_read ON storage.objects;
CREATE POLICY bos_voice_audio_public_read ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'bos-voice-audio');

DROP POLICY IF EXISTS bos_voice_audio_service_insert ON storage.objects;
CREATE POLICY bos_voice_audio_service_insert ON storage.objects
  FOR INSERT TO public
  WITH CHECK (bucket_id = 'bos-voice-audio');

DROP POLICY IF EXISTS bos_voice_audio_service_update ON storage.objects;
CREATE POLICY bos_voice_audio_service_update ON storage.objects
  FOR UPDATE TO public
  USING (bucket_id = 'bos-voice-audio')
  WITH CHECK (bucket_id = 'bos-voice-audio');
