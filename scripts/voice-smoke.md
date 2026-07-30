# Voice smoke checklist (Telnyx)

10-step dogfood after Settings → Voice secrets + webhook URL are set.

1. **Readiness** — Settings → AI Voice → Voice readiness: provider `telnyx`, webhook URL ready, keys set.
2. **Webhook ping** — Send test ping; Voice events list shows a recent `test_ping` (or similar) row.
3. **TTS preview** — Preview TTS with a short Hinglish line; audio plays (or clear “set Sarvam” stub note).
4. **Outbound dial** — Test dial to your phone; call rings; Voice list shows live (not stub) status strip.
5. **Answer + hangup** — Answer briefly, hang up; webhook events: `call.answered` / hangup; call completes (or Run due / wait ~45s reconcile).
6. **Inbound miss** — Call your Telnyx number, let it miss; lead `source=voice_inbound`; activity “Missed…”; callback queued ~5 min (or skipped if DND/opt-out).
7. **Open from activity** — Lead detail → tap callback activity → Voice opens with `?call=` deep-link.
8. **Opt-out** — Settings → add phone to opt-outs; miss again → activity “callback skipped”, no new queue.
9. **Inbox hot** — Hot/handover lead conversation shows badge; Queue AI call creates `inbox_*` lead source; Leads Source filter “Inbox / chat” finds it.
10. **Run due** — Hub or Voice → Run due; due callbacks/campaign queues dial; Reports voice KPIs tick up.

Optional: Campaign with `trigger_voice` → Run campaign → Voice “due” filter → dial.

Secrets live in Settings (`api_secrets.voice.telnyx`); never commit keys. Deploy webhook after Edge changes:

```cmd
cd e:\dgyardconnect\scripts
npx supabase functions deploy bos-voice-webhook --no-verify-jwt
```
