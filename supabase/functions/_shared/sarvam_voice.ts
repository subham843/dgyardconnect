// Sarvam TTS + language helpers for live phone turns (Twilio Play URL).

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export type SarvamModel = "bulbul:v2" | "bulbul:v3";

const SPEAKERS_V2 = new Set([
  "anushka",
  "abhilash",
  "manisha",
  "vidya",
  "arya",
  "karun",
  "hitesh",
]);
const SPEAKERS_V3 = new Set([
  "shubh",
  "aditya",
  "ritu",
  "priya",
  "neha",
  "rahul",
  "pooja",
  "rohan",
  "simran",
  "kavya",
  "amit",
  "dev",
  "ishita",
  "shreya",
  "ratan",
  "varun",
  "manan",
  "sumit",
  "roopa",
  "kabir",
  "aayan",
  "ashutosh",
  "advait",
  "anand",
  "tanya",
  "tarun",
  "sunny",
  "mani",
  "gokul",
  "vijay",
  "shruti",
  "suhani",
  "mohit",
  "kavitha",
  "rehan",
  "soham",
  "rupali",
  "rilu",
]);

export function normalizeModel(raw?: string): SarvamModel {
  const m = String(raw || "bulbul:v3").toLowerCase();
  return m.includes("v2") ? "bulbul:v2" : "bulbul:v3";
}

export function resolveSpeaker(raw: string | undefined, model: SarvamModel): string {
  const s = String(raw || "").trim().toLowerCase();
  if (model === "bulbul:v2") {
    if (s && SPEAKERS_V2.has(s)) return s;
    return "anushka";
  }
  if (s && SPEAKERS_V3.has(s)) return s;
  return "shubh";
}

/** Detect reply language from customer speech. */
export function detectLanguageCode(text: string, fallback = "hi-IN"): string {
  const t = String(text || "").trim();
  if (!t) return fallback;
  if (/[\u0900-\u097F]/.test(t)) return "hi-IN";
  if (/[\u0B80-\u0BFF]/.test(t)) return "ta-IN";
  if (/[\u0C00-\u0C7F]/.test(t)) return "te-IN";
  if (/[\u0A80-\u0AFF]/.test(t)) return "gu-IN";
  // Roman Hindi / Hinglish cues
  if (
    /\b(haan|han|nahi|nahin|ji|kya|hai|hain|hoon|chahiye|kitna|kitne|batao|bataye|namaste|dhanyavad|accha|theek|mujhe|mera|meri|lagwana|lagana|dono|farq|kripya|suniye|bolna)\b/i
      .test(t)
  ) {
    return "hi-IN";
  }
  // Mostly ASCII English words
  if (/^[A-Za-z0-9\s.,!?'"\-]+$/.test(t) && /\b(the|is|are|want|need|how|what|please|cameras?)\b/i.test(t)) {
    return "en-IN";
  }
  if (/^[A-Za-z0-9\s.,!?'"\-]+$/.test(t)) return "en-IN";
  return fallback;
}

function decodeBase64Audio(raw: string): Uint8Array {
  let s = raw.trim();
  const comma = s.indexOf(",");
  if (s.startsWith("data:") && comma >= 0) s = s.slice(comma + 1);
  s = s.replace(/\s+/g, "");
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export async function sarvamTtsToPublicUrl(
  db: SupabaseClient,
  opts: {
    tenantId: string;
    callId: string;
    text: string;
    apiKey: string;
    speaker: string;
    model: SarvamModel;
    language: string;
    turn: number;
  },
): Promise<{ url: string | null; sim: boolean; error?: string }> {
  try {
    // Keep phone replies short — less TTS time + smaller file.
    const text = opts.text.trim().slice(0, 280);
    if (!text) return { url: null, sim: true, error: "empty_text" };
    if (!opts.apiKey) return { url: null, sim: true, error: "sarvam_key_missing" };

    // Telephony-optimized: 16kHz mp3, no preprocessing (faster Sarvam turnaround).
    const payload: Record<string, unknown> = {
      text,
      target_language_code: opts.language || "hi-IN",
      speaker: opts.speaker,
      model: opts.model,
      pace: 1.1,
      speech_sample_rate: 16000,
      enable_preprocessing: false,
      output_audio_codec: "mp3",
    };
    if (opts.model === "bulbul:v2") {
      payload.pitch = 0;
      payload.loudness = 1;
      payload.inputs = [text];
    }

    const res = await fetch("https://api.sarvam.ai/text-to-speech", {
      method: "POST",
      headers: {
        "api-subscription-key": opts.apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      const msg =
        (data as { error?: { message?: string } })?.error?.message ||
        (data as { message?: string })?.message ||
        JSON.stringify(data);
      return { url: null, sim: false, error: `sarvam_http_${res.status}: ${msg}` };
    }
    let b64 =
      (Array.isArray((data as { audios?: string[] }).audios) &&
        (data as { audios: string[] }).audios[0]) ||
      (data as { audio?: string }).audio ||
      (data as { audio_base64?: string }).audio_base64 ||
      null;
    if (!b64 || typeof b64 !== "string") {
      return { url: null, sim: false, error: "no_audio_in_sarvam_response" };
    }
    const comma = b64.indexOf(",");
    if (b64.startsWith("data:") && comma >= 0) b64 = b64.slice(comma + 1);

    // Fast path: DB clip + edge serve (skip Storage upload latency).
    const clipId = crypto.randomUUID();
    const { error: clipErr } = await db.from("bos_voice_clips").insert({
      id: clipId,
      tenant_id: opts.tenantId,
      call_id: opts.callId,
      content_type: "audio/mpeg",
      audio_b64: b64,
    });
    if (!clipErr) {
      const base = Deno.env.get("SUPABASE_URL") || "";
      return {
        url: `${base}/functions/v1/bos-voice-clip?id=${encodeURIComponent(clipId)}`,
        sim: false,
      };
    }

    // Fallback: Storage public URL
    const binary = decodeBase64Audio(b64);
    const path = `${opts.tenantId}/${opts.callId}/t${opts.turn}-${Date.now()}.mp3`;
    const up = await db.storage.from("bos-voice-audio").upload(path, binary, {
      contentType: "audio/mpeg",
      upsert: true,
    });
    if (up.error) {
      return {
        url: null,
        sim: false,
        error: `clip_and_storage_failed: ${clipErr?.message || ""} ${up.error.message}`,
      };
    }
    const pub = db.storage.from("bos-voice-audio").getPublicUrl(path);
    return { url: pub.data.publicUrl, sim: false };
  } catch (e) {
    return { url: null, sim: false, error: `sarvam_exception: ${String(e)}` };
  }
}

/** Resolve Sarvam key from nested or legacy secret shapes. */
export function resolveSarvamApiKey(
  secrets: Record<string, unknown>,
  envFallback = "",
): string {
  const sarvam = secrets.sarvam;
  if (sarvam && typeof sarvam === "object") {
    const k = (sarvam as Record<string, unknown>).api_key;
    if (typeof k === "string" && k.trim()) return k.trim();
  }
  if (typeof sarvam === "string" && sarvam.trim()) return sarvam.trim();
  const voice = secrets.voice;
  if (voice && typeof voice === "object") {
    const k =
      (voice as Record<string, unknown>).sarvam_api_key ||
      (voice as Record<string, unknown>).sarvam;
    if (typeof k === "string" && k.trim()) return k.trim();
  }
  return (envFallback || "").trim();
}

function heuristicSalesReply(customer: string, hi: boolean, agent: string): string {
  const t = customer.toLowerCase();
  const hasCctv = /(cctv|camera|cameras|सीसीटीवी|कैमरा|surveillance|dvr|nvr)/i.test(t);
  const asksDiff =
    /(difference|defrecnce|diference|farq|फर्क|فرق|vs|versus|compare|dono|दोनों|hd.*ip|ip.*hd)/i
      .test(t);
  const asksHd = /\b(hd|analog|एनालॉग)\b/i.test(t) && !asksDiff;
  const asksIp = /\b(ip\s*camera|आई\s*पी|network camera)\b/i.test(t) && !asksDiff;
  const asksCount = /(kitne|kitna|how many|कितने|कितना|\d+\s*(camera|cam))/i.test(t);
  const asksPrice = /(price|kitna lagega|cost|rate|budget|estimate|quote|कीमत|दाम)/i.test(t);

  if (/(not interested|nahi chahiye|mat call|stop calling|busy|baad mein|alvida|bye)/i.test(t)) {
    return hi
      ? `Theek hai, koi baat nahi. DG.YARD ki taraf se dhanyavaad. Jab zarurat ho, call kariye. Alvida.`
      : `No problem. Thank you from DG.YARD. Call us anytime you need. Goodbye.`;
  }

  if (asksDiff || (/(hd|ip)/i.test(t) && /(difference|farq|dono|kya|what)/i.test(t))) {
    return hi
      ? `HD DVR pe sasta, IP NVR pe zyada clear aur phone pe live. Kitne cameras chahiye?`
      : `HD is cheaper on DVR; IP is clearer with phone live view. How many cameras?`;
  }

  if (asksIp) {
    return hi
      ? `IP clear picture aur mobile view deta hai. Kitne cameras, indoor ya outdoor?`
      : `IP gives clear video and phone view. How many cameras, indoor or outdoor?`;
  }

  if (asksHd) {
    return hi
      ? `HD budget-friendly hai. Kitne cameras aur area kitna bada?`
      : `HD is budget-friendly. How many cameras and how large is the area?`;
  }

  if (hasCctv && asksCount) {
    return hi
      ? `Samajh gaya. HD chahiye ya IP? Outdoor bhi lagenge?`
      : `Got it. HD or IP? Any outdoor cameras too?`;
  }

  if (hasCctv || /(lagwana|install|lagana|chahiye|need|want)/i.test(t)) {
    return hi
      ? `Bilkul. Roughly kitne CCTV cameras chahiye?`
      : `Absolutely. Roughly how many CCTV cameras do you need?`;
  }

  if (asksPrice) {
    return hi
      ? `Price cameras aur HD ya IP pe depend karti hai. Kitne cameras chahiye?`
      : `Price depends on count and HD vs IP. How many cameras?`;
  }

  if (/(haan|yes|interested|batao|ok|theek|ji|suniye)/i.test(t)) {
    return hi
      ? `Accha. CCTV chahiye, networking, ya software?`
      : `Great. CCTV, networking, or software?`;
  }

  if (/(network|wifi|lan|router|cabling)/i.test(t)) {
    return hi
      ? `Networking ke liye — office hai ya home, kitne points?`
      : `For networking — office or home, and how many points?`;
  }

  return hi
    ? `Boliye — CCTV, networking, ya aur kuch? Main seedha jawab dunga.`
    : `Tell me — CCTV, networking, or something else? I'll answer directly.`;
}

export async function generateVoiceReply(opts: {
  customerText: string;
  language: string;
  scriptHint?: string;
  openaiKey?: string;
  agentName?: string;
  conversation?: Array<{ role?: string; text?: string }>;
  /** Phone path: skip OpenAI wait (saves ~2–5s). Default true. */
  fast?: boolean;
}): Promise<string> {
  const customer = opts.customerText.trim().slice(0, 500);
  const lang = opts.language || "hi-IN";
  const agent = opts.agentName || "DG.YARD";
  const hi = lang.startsWith("hi");
  const fast = opts.fast !== false;
  const local = heuristicSalesReply(customer, hi, agent);

  // Live calls: never block on LLM — heuristics answer in <1ms.
  if (fast || !opts.openaiKey) return local;

  const history = (opts.conversation || [])
    .slice(-8)
    .map((m) => `${m.role === "customer" ? "Customer" : "Agent"}: ${String(m.text || "").slice(0, 200)}`)
    .join("\n");

  try {
    const ac = new AbortController();
    const timer = setTimeout(() => ac.abort(), 2500);
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      signal: ac.signal,
      headers: {
        Authorization: `Bearer ${opts.openaiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        temperature: 0.4,
        max_tokens: 80,
        messages: [
          {
            role: "system",
            content:
              `You are ${agent}, friendly phone sales for DG.YARD (CCTV, networking, software). ` +
              `Reply ONLY spoken dialogue: 1-2 short sentences. No markdown. ` +
              `Answer the question first, then ask ONE next question. Match customer language.`,
          },
          {
            role: "user",
            content:
              `Script: ${opts.scriptHint || "(none)"}\nHistory:\n${history || "(none)"}\n` +
              `Customer (${lang}): ${customer}\nDraft: ${local}`,
          },
        ],
      }),
    });
    clearTimeout(timer);
    if (res.ok) {
      const data = await res.json();
      const text = String(data.choices?.[0]?.message?.content || "").trim();
      if (text) return text.slice(0, 280);
    }
  } catch {
    /* use local */
  }

  return local;
}
