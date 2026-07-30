// Twilio conversational TwiML: Sarvam TTS Play + Gather (listen) + AI reply loop.
// Opening audio is pre-generated at dial time → instant Play on answer.
// Silent Gather redirect must NOT replay the intro.

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
const MAX_TURNS = 12;

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

function speakOrPlay(audioUrl: string | null, text: string, sayLang: string): string {
  if (audioUrl) return `<Play>${xml(audioUrl)}</Play>`;
  return `<Say language="${sayLang}">${xml(text)}</Say>`;
}

/** Play/Say inside Gather so listening starts immediately after agent speaks. */
function gatherWithPrompt(
  gatherLang: string,
  actionUrl: string,
  innerXml: string,
): string {
  const hints =
    gatherLang.startsWith("hi")
      ? "haan,nahi,cctv,camera,cameras,hd,ip,price,kitne,kitna,lagwana"
      : "yes,no,cctv,camera,cameras,hd,ip,price,how many,install";
  return (
    `<Gather input="speech" language="${gatherLang}" speechTimeout="auto" timeout="6" ` +
    `action="${xml(actionUrl)}" method="POST" hints="${hints}">` +
    `${innerXml}` +
    `</Gather>` +
    `<Redirect method="POST">${xml(actionUrl + "&phase=listen")}</Redirect>`
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let callIdForErr = "";
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
    const phase = url.searchParams.get("phase") || form.phase || "";
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
    const openingPlayed = Boolean(prevMeta.opening_played) || turn >= 1;
    const speech =
      form.SpeechResult ||
      form.UnstableSpeechResult ||
      form.TranscriptionText ||
      "";
    const baseAction =
      `${Deno.env.get("SUPABASE_URL")}/functions/v1/bos-voice-twiml` +
      `?tenant_id=${encodeURIComponent(tenantId)}&call_id=${encodeURIComponent(callId)}`;

    let language = String(
      prevMeta.customer_language ||
        voiceCfg.sarvam_language ||
        voiceCfg.tts_language ||
        "hi-IN",
    );
    const gatherLang = language.startsWith("en") ? "en-IN" : "hi-IN";

    // --- Customer spoke → answer their question (never replay intro) ---
    if (speech.trim()) {
      language = detectLanguageCode(speech, language);
      const nextTurn = turn + 1;
      const history = Array.isArray(prevMeta.conversation)
        ? [...(prevMeta.conversation as unknown[])]
        : [];
      history.push({ role: "customer", text: speech, at: new Date().toISOString() });

      let speakText = "";
      if (
        nextTurn >= MAX_TURNS ||
        /(bye|goodbye|alvida|hang up|mat call|stop calling)/i.test(speech)
      ) {
        speakText = language.startsWith("hi")
          ? `Dhanyavaad. DG.YARD ki taraf se aapka din shubh ho. Phir milenge.`
          : `Thank you from DG.YARD. Have a great day. Goodbye.`;
      } else {
        speakText = await generateVoiceReply({
          customerText: speech,
          language,
          scriptHint: String(call.script || ""),
          openaiKey: String(openaiKey || ""),
          agentName,
          conversation: history as Array<{ role?: string; text?: string }>,
          fast: true, // never wait on OpenAI during live call
        });
      }
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

      const ending =
        nextTurn >= MAX_TURNS ||
        /(bye|goodbye|alvida|hang up|mat call|stop calling)/i.test(speech);

      await db.from("bos_voice_calls").update({
        status: ending ? "completed" : "in_progress",
        transcript: [
          call.transcript,
          `Customer: ${speech}`,
          `Agent: ${speakText}`,
        ].filter(Boolean).join("\n"),
        meta: {
          ...prevMeta,
          voice_turn: nextTurn,
          opening_played: true,
          customer_language: language,
          conversation: history,
          last_sarvam_play: audio.url,
          last_customer_speech: speech,
          last_agent_reply: speakText,
          sarvam_speaker: speaker,
          conversational: true,
          sarvam_tts_error: audio.error || null,
          has_sarvam_key: Boolean(sarvamKey),
        },
        updated_at: new Date().toISOString(),
      }).eq("id", callId);

      const sayLang = language.startsWith("en") ? "en-IN" : "hi-IN";
      if (ending) {
        return twimlResponse(`${speakOrPlay(audio.url, speakText, sayLang)}<Hangup/>`);
      }
      return twimlResponse(
        gatherWithPrompt(
          sayLang,
          baseAction,
          speakOrPlay(audio.url, speakText, sayLang),
        ),
      );
    }

    // --- No speech: after intro already played → short nudge only (never full intro) ---
    if (openingPlayed || phase === "listen") {
      const nudge = language.startsWith("hi")
        ? "Main sun raha hoon. Aap boliye — jaise CCTV chahiye, kitne cameras, HD ya IP."
        : "I'm listening. Please tell me — for example CCTV, how many cameras, HD or IP.";
      // Prefer tiny cached nudge? Keep Say short to avoid another 30s TTS wait.
      return twimlResponse(
        gatherWithPrompt(
          gatherLang,
          baseAction,
          `<Say language="${gatherLang}">${xml(nudge)}</Say>`,
        ),
      );
    }

    // --- First connect: use pre-generated opening_play (instant) ---
    // Return TwiML ASAP when dial already baked Sarvam audio — no extra TTS wait.
    const cachedOpening =
      typeof prevMeta.opening_play === "string" && prevMeta.opening_play
        ? String(prevMeta.opening_play)
        : null;
    const openingText = String(
      prevMeta.opening_text ||
        call.script ||
        voiceCfg.inbound_greeting ||
        `Namaste, main ${agentName}, DG.YARD se baat kar raha hoon. Aapki enquiry ke baare mein do minute milenge?`,
    ).slice(0, 280);

    if (cachedOpening) {
      // Non-blocking meta update so Twilio gets TwiML immediately
      void db.from("bos_voice_calls").update({
        status: "in_progress",
        meta: {
          ...prevMeta,
          voice_turn: 1,
          opening_played: true,
          conversational: true,
        },
        updated_at: new Date().toISOString(),
      }).eq("id", callId);
      return twimlResponse(
        gatherWithPrompt(
          gatherLang,
          baseAction,
          speakOrPlay(cachedOpening, openingText, gatherLang),
        ),
      );
    }

    let openingUrl: string | null = null;
    if (sarvamKey) {
      const audio = await sarvamTtsToPublicUrl(db, {
        tenantId,
        callId,
        text: openingText,
        apiKey: sarvamKey,
        speaker,
        model,
        language,
        turn: 0,
      });
      openingUrl = audio.url;
      prevMeta.sarvam_tts_error = audio.error || null;
    }

    await db.from("bos_voice_calls").update({
      status: "in_progress",
      meta: {
        ...prevMeta,
        voice_turn: 1,
        opening_played: true,
        opening_play: openingUrl,
        opening_text: openingText,
        customer_language: language,
        conversational: true,
        sarvam_speaker: speaker,
        sarvam_model: model,
        has_sarvam_key: Boolean(sarvamKey),
        conversation: Array.isArray(prevMeta.conversation) &&
            (prevMeta.conversation as unknown[]).length > 0
          ? prevMeta.conversation
          : [{ role: "agent", text: openingText, at: new Date().toISOString() }],
      },
      updated_at: new Date().toISOString(),
    }).eq("id", callId);

    return twimlResponse(
      gatherWithPrompt(
        gatherLang,
        baseAction,
        speakOrPlay(openingUrl, openingText, gatherLang),
      ),
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
      `<Say language="hi-IN">Namaste, DG.YARD se. Kripya thodi der mein dubara try karein.</Say><Hangup/>`,
    );
  }
});
