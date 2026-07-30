// Twilio conversational TwiML: Sarvam TTS Play + Gather (listen) + AI reply loop.
// Dial sets Call Url → this function. Gather posts SpeechResult back here.
// Query: tenant_id, call_id

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  detectLanguageCode,
  generateVoiceReply,
  normalizeModel,
  resolveSarvamApiKey,
  resolveSpeaker,
  sarvamTtsToPublicUrl,
} from "../_shared/sarvam_voice.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const DEFAULT_TENANT = "b0000000-0000-4000-8000-000000000001";
const MAX_TURNS = 6;

function admin() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("Supabase not configured");
  return createClient(url, key);
}

function xml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function twimlResponse(body: string): Response {
  return new Response(`<?xml version="1.0" encoding="UTF-8"?><Response>${body}</Response>`, {
    headers: {
      ...corsHeaders,
      "Content-Type": "text/xml; charset=utf-8",
    },
  });
}

async function parseBody(req: Request): Promise<Record<string, string>> {
  const ct = req.headers.get("content-type") || "";
  if (ct.includes("application/x-www-form-urlencoded") || ct.includes("multipart/form-data")) {
    const fd = await req.formData();
    const out: Record<string, string> = {};
    fd.forEach((v, k) => {
      if (typeof v === "string") out[k] = v;
    });
    return out;
  }
  if (ct.includes("application/json")) {
    const j = await req.json().catch(() => ({}));
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(j as Record<string, unknown>)) {
      if (v != null) out[k] = String(v);
    }
    return out;
  }
  const text = await req.text();
  const params = new URLSearchParams(text);
  const out: Record<string, string> = {};
  params.forEach((v, k) => {
    out[k] = v;
  });
  return out;
}

function speakOrPlay(audioUrl: string | null, text: string): string {
  if (audioUrl) return `<Play>${xml(audioUrl)}</Play>`;
  return `<Say language="hi-IN">${xml(text)}</Say>`;
}

function gatherBlock(gatherLang: string, actionUrl: string, promptIfSilent: string): string {
  return (
    `<Gather input="speech" language="${gatherLang}" speechTimeout="auto" timeout="8" action="${xml(actionUrl)}" method="POST">` +
    `<Pause length="1"/>` +
    `</Gather>` +
    `<Say language="${gatherLang}">${xml(promptIfSilent)}</Say>` +
    `<Redirect method="POST">${xml(actionUrl)}</Redirect>`
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let callIdForErr = "";
  let tenantIdForErr = DEFAULT_TENANT;
  try {
    const url = new URL(req.url);
    const form = req.method === "POST" ? await parseBody(req) : {};
    const tenantId =
      url.searchParams.get("tenant_id") ||
      form.tenant_id ||
      DEFAULT_TENANT;
    const callId =
      url.searchParams.get("call_id") ||
      form.call_id ||
      "";
    tenantIdForErr = tenantId;
    callIdForErr = callId;
    if (!callId) {
      return twimlResponse(`<Say language="hi-IN">Call setup incomplete. Goodbye.</Say><Hangup/>`);
    }

    const db = admin();
    const { data: call, error: callErr } = await db
      .from("bos_voice_calls")
      .select("*")
      .eq("id", callId)
      .maybeSingle();
    if (callErr) throw new Error(`call_lookup: ${callErr.message}`);
    if (!call) {
      return twimlResponse(`<Say language="hi-IN">Call not found. Goodbye.</Say><Hangup/>`);
    }

    const { data: settingsRow } = await db
      .from("bos_tenant_settings")
      .select("api_secrets, api_config, settings")
      .eq("tenant_id", tenantId)
      .maybeSingle();
    const secrets = (settingsRow?.api_secrets ?? {}) as Record<string, unknown>;
    const voiceCfg = ((settingsRow?.api_config as Record<string, unknown>)?.voice ?? {}) as Record<
      string,
      string
    >;
    const aiAgent = ((settingsRow?.settings as Record<string, unknown>)?.ai_agent ?? {}) as Record<
      string,
      string
    >;
    const sarvamKey = resolveSarvamApiKey(
      secrets,
      Deno.env.get("SARVAM_API_KEY") || "",
    );
    const openaiRaw = secrets.openai;
    const openaiKey =
      (openaiRaw && typeof openaiRaw === "object"
        ? String((openaiRaw as Record<string, unknown>).api_key || "")
        : typeof openaiRaw === "string"
        ? openaiRaw
        : "") ||
      Deno.env.get("OPENAI_API_KEY") ||
      "";
    const model = normalizeModel(voiceCfg.sarvam_model || voiceCfg.tts_model);
    const speaker = resolveSpeaker(voiceCfg.sarvam_speaker || voiceCfg.tts_speaker, model);
    const agentName = aiAgent.name || "DG.YARD Sales Agent";

    const prevMeta = (call.meta ?? {}) as Record<string, unknown>;
    const turn = Number(prevMeta.voice_turn || 0);
    const speech =
      form.SpeechResult ||
      form.UnstableSpeechResult ||
      form.TranscriptionText ||
      "";
    const actionUrl =
      `${Deno.env.get("SUPABASE_URL")}/functions/v1/bos-voice-twiml` +
      `?tenant_id=${encodeURIComponent(tenantId)}&call_id=${encodeURIComponent(callId)}`;

    let speakText = "";
    let language = String(
      prevMeta.customer_language ||
        voiceCfg.sarvam_language ||
        voiceCfg.tts_language ||
        "hi-IN",
    );
    let nextTurn = turn;
    const gatherLang = language.startsWith("en") ? "en-IN" : "hi-IN";
    const silentPrompt = language.startsWith("hi")
      ? "Main aapki baat sun nahi paya. Kripya dobara boliye."
      : "I could not hear you. Please speak again.";

    if (speech.trim()) {
      language = detectLanguageCode(speech, language);
      nextTurn = turn + 1;
      const history = Array.isArray(prevMeta.conversation)
        ? [...(prevMeta.conversation as unknown[])]
        : [];
      history.push({ role: "customer", text: speech, at: new Date().toISOString() });

      if (
        nextTurn >= MAX_TURNS ||
        /(bye|goodbye|alvida|hang up|mat call|stop calling)/i.test(speech)
      ) {
        speakText =
          language.startsWith("hi")
            ? `Dhanyavaad. DG.YARD ki taraf se aapka din shubh ho. Phir milenge.`
            : `Thank you. Wishing you a great day from DG.YARD. Goodbye.`;
        const audio = await sarvamTtsToPublicUrl(db, {
          tenantId,
          callId,
          text: speakText,
          apiKey: sarvamKey,
          speaker,
          model,
          language,
          turn: nextTurn,
        });
        await db.from("bos_voice_calls").update({
          status: "completed",
          transcript: [
            call.transcript,
            `Customer: ${speech}`,
            `Agent: ${speakText}`,
          ].filter(Boolean).join("\n"),
          meta: {
            ...prevMeta,
            voice_turn: nextTurn,
            customer_language: language,
            conversation: [...history, { role: "agent", text: speakText }],
            last_sarvam_play: audio.url,
            sarvam_speaker: speaker,
            conversational: true,
            sarvam_tts_error: audio.error || null,
          },
          updated_at: new Date().toISOString(),
        }).eq("id", callId);

        return twimlResponse(`${speakOrPlay(audio.url, speakText)}<Hangup/>`);
      }

      speakText = await generateVoiceReply({
        customerText: speech,
        language,
        scriptHint: String(call.script || ""),
        openaiKey: String(openaiKey || ""),
        agentName,
      });
      history.push({ role: "agent", text: speakText, at: new Date().toISOString() });

      const audio = await sarvamTtsToPublicUrl(db, {
        tenantId,
        callId,
        text: speakText,
        apiKey: sarvamKey,
        speaker,
        model,
        language,
        turn: nextTurn,
      });

      await db.from("bos_voice_calls").update({
        status: "in_progress",
        transcript: [
          call.transcript,
          `Customer: ${speech}`,
          `Agent: ${speakText}`,
        ].filter(Boolean).join("\n"),
        meta: {
          ...prevMeta,
          voice_turn: nextTurn,
          customer_language: language,
          conversation: history,
          last_sarvam_play: audio.url,
          last_customer_speech: speech,
          sarvam_speaker: speaker,
          conversational: true,
          sarvam_tts_error: audio.error || null,
          has_sarvam_key: Boolean(sarvamKey),
        },
        updated_at: new Date().toISOString(),
      }).eq("id", callId);

      return twimlResponse(
        speakOrPlay(audio.url, speakText) +
          gatherBlock(language.startsWith("en") ? "en-IN" : "hi-IN", actionUrl, silentPrompt),
      );
    }

    // Opening turn — Sarvam plays script, then listen
    speakText = String(
      call.script ||
        voiceCfg.inbound_greeting ||
        `Namaste, main ${agentName}, DG.YARD se baat kar raha hoon. Aapki enquiry ke baare mein do minute milenge?`,
    ).slice(0, 800);
    nextTurn = Math.max(turn, 1);
    const audio = await sarvamTtsToPublicUrl(db, {
      tenantId,
      callId,
      text: speakText,
      apiKey: sarvamKey,
      speaker,
      model,
      language,
      turn: 0,
    });

    await db.from("bos_voice_calls").update({
      status: "in_progress",
      meta: {
        ...prevMeta,
        voice_turn: nextTurn,
        customer_language: language,
        conversational: true,
        sarvam_speaker: speaker,
        sarvam_model: model,
        opening_play: audio.url,
        sarvam_tts_error: audio.error || null,
        has_sarvam_key: Boolean(sarvamKey),
        conversation: [
          ...(Array.isArray(prevMeta.conversation) ? prevMeta.conversation as unknown[] : []),
          { role: "agent", text: speakText, at: new Date().toISOString() },
        ],
      },
      updated_at: new Date().toISOString(),
    }).eq("id", callId);

    // Do NOT use .catch() on Postgrest builders — it is not a Promise and crashes the call.
    try {
      await db.from("bos_voice_events").insert({
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        call_id: callId,
        lead_id: call.lead_id || null,
        provider: "twilio",
        event_type: audio.url ? "sarvam_play_opening" : "sarvam_play_fallback_say",
        payload: {
          speaker,
          model,
          language,
          error: audio.error || null,
          has_sarvam_key: Boolean(sarvamKey),
        },
      });
    } catch {
      /* non-fatal */
    }

    return twimlResponse(
      speakOrPlay(audio.url, speakText) + gatherBlock(gatherLang, actionUrl, silentPrompt),
    );
  } catch (e) {
    const err = String(e);
    console.error("bos-voice-twiml error", err);
    if (callIdForErr) {
      try {
        const db = admin();
        const { data: call } = await db
          .from("bos_voice_calls")
          .select("meta")
          .eq("id", callIdForErr)
          .maybeSingle();
        const prev = (call?.meta ?? {}) as Record<string, unknown>;
        await db.from("bos_voice_calls").update({
          meta: { ...prev, twiml_exception: err },
          updated_at: new Date().toISOString(),
        }).eq("id", callIdForErr);
      } catch {
        /* ignore */
      }
    }
    return twimlResponse(
      `<Say language="hi-IN">Namaste, DG.YARD se call connect ho raha hai. Kripya thodi der mein dubara try karein.</Say><Hangup/>`,
    );
  }
});
