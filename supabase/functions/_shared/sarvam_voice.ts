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
  if (
    /\b(haan|nahi|ji|kya|hai|hain|chahiye|kitna|kitne|batao|namaste|dhanyavad|accha|theek)\b/i
      .test(t)
  ) {
    return "hi-IN";
  }
  if (/[\u0B80-\u0BFF]/.test(t)) return "ta-IN";
  if (/[\u0C00-\u0C7F]/.test(t)) return "te-IN";
  if (/[\u0A80-\u0AFF]/.test(t)) return "gu-IN";
  if (/[\u0900-\u097F]/.test(t) === false && /^[\x00-\x7F\s.,!?']+$/.test(t)) {
    return "en-IN";
  }
  return fallback;
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
  const text = opts.text.trim().slice(0, 1200);
  if (!text) return { url: null, sim: true, error: "empty_text" };
  if (!opts.apiKey) return { url: null, sim: true, error: "sarvam_key_missing" };

  const payload: Record<string, unknown> = {
    text,
    target_language_code: opts.language || "hi-IN",
    speaker: opts.speaker,
    model: opts.model,
    pace: 1.0,
    speech_sample_rate: opts.model === "bulbul:v2" ? 22050 : 24000,
    enable_preprocessing: true,
    output_audio_codec: "wav",
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
      JSON.stringify(data);
    return { url: null, sim: false, error: msg };
  }
  const b64 =
    (Array.isArray((data as { audios?: string[] }).audios) &&
      (data as { audios: string[] }).audios[0]) ||
    (data as { audio?: string }).audio ||
    (data as { audio_base64?: string }).audio_base64 ||
    null;
  if (!b64 || typeof b64 !== "string") {
    return { url: null, sim: false, error: "no_audio_in_sarvam_response" };
  }

  const binary = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  const path = `${opts.tenantId}/${opts.callId}/t${opts.turn}-${Date.now()}.wav`;
  const up = await db.storage.from("bos-voice-audio").upload(path, binary, {
    contentType: "audio/wav",
    upsert: true,
  });
  if (up.error) {
    return { url: null, sim: false, error: `storage_upload: ${up.error.message}` };
  }
  const pub = db.storage.from("bos-voice-audio").getPublicUrl(path);
  return { url: pub.data.publicUrl, sim: false };
}

export async function generateVoiceReply(opts: {
  customerText: string;
  language: string;
  scriptHint?: string;
  openaiKey?: string;
  agentName?: string;
}): Promise<string> {
  const customer = opts.customerText.trim().slice(0, 500);
  const lang = opts.language || "hi-IN";
  const agent = opts.agentName || "DG.YARD";
  const hi = lang.startsWith("hi");

  if (opts.openaiKey) {
    try {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${opts.openaiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          temperature: 0.5,
          messages: [
            {
              role: "system",
              content:
                `You are ${agent} phone sales agent for DG.YARD (CCTV, networking, software, security). ` +
                `Speak ONLY as spoken phone dialogue (2-4 short sentences). No markdown. ` +
                `Reply in the SAME language as the customer (hi-IN → Hindi/Hinglish, en-IN → English India). ` +
                `Listen first, answer their question, ask one clarifying question, invite next step (site visit / quote). ` +
                `Never hang up abruptly; if they want to end, thank them politely.`,
            },
            {
              role: "user",
              content:
                `Call context script hint: ${opts.scriptHint || "(none)"}\n` +
                `Customer said (${lang}): ${customer}`,
            },
          ],
        }),
      });
      if (res.ok) {
        const data = await res.json();
        const text = String(data.choices?.[0]?.message?.content || "").trim();
        if (text) return text.slice(0, 600);
      }
    } catch {
      /* fallback below */
    }
  }

  const t = customer.toLowerCase();
  if (/(not interested|nahi chahiye|mat call|stop|busy|baad mein)/.test(t)) {
    return hi
      ? `Theek hai, koi baat nahi. DG.YARD ki taraf se dhanyavaad. Jab ready hon, hum help ke liye yahan hain. Alvida.`
      : `No problem at all. Thank you from DG.YARD. We're here whenever you're ready. Goodbye.`;
  }
  if (/(price|kitna|kitne|cost|rate|budget)/.test(t)) {
    return hi
      ? `Bilkul — price site aur cameras pe depend karta hai. Aapke kitne cameras aur location batayein? Main DG.YARD se rough estimate share karunga.`
      : `Sure — pricing depends on camera count and site. How many cameras and which location? I'll share a DG.YARD ballpark.`;
  }
  if (/(haan|yes|interested|batao|ok|theek)/.test(t)) {
    return hi
      ? `Bahut accha. Main DG.YARD se baat kar raha hoon. Aapki requirement short me sunna chahta hoon — CCTV, networking, ya software?`
      : `Great. This is DG.YARD. Briefly, is your need CCTV, networking, or software?`;
  }
  return hi
    ? `Namaste, main ${agent}, DG.YARD se baat kar raha hoon. Aapne kaha: requirement samajh li. Aur detail batayein taaki sahi solution de sakun?`
    : `Hello, this is ${agent} from DG.YARD. I heard you — please share a bit more so I can help with the right solution.`;
}
