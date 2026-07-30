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
        (data as { message?: string })?.message ||
        JSON.stringify(data);
      return { url: null, sim: false, error: `sarvam_http_${res.status}: ${msg}` };
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

    const binary = decodeBase64Audio(b64);
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
      ? `Bahut accha sawaal. HD analog camera DVR se judte hain, sasta setup, thodi limited clarity. IP camera NVR pe chalte hain, zyada clear picture, remote app se dekh sakte hain. Aapke site pe kitne cameras chahiye — main sahi option suggest karun?`
      : `Great question. HD analog cameras use a DVR — lower cost, decent clarity. IP cameras use an NVR — sharper video and easy phone viewing. How many cameras do you need so I can recommend the right option?`;
  }

  if (asksIp) {
    return hi
      ? `IP cameras clear picture aur mobile pe live view dete hain. Aapko roughly kitne cameras chahiye, indoor ya outdoor?`
      : `IP cameras give clearer video and live phone view. Roughly how many cameras, indoor or outdoor?`;
  }

  if (asksHd) {
    return hi
      ? `HD cameras budget-friendly hote hain DVR ke saath. Kitne cameras aur area kitna bada hai?`
      : `HD cameras are budget-friendly with a DVR. How many cameras and how large is the area?`;
  }

  if (hasCctv && asksCount) {
    return hi
      ? `Samajh gaya. Cameras ke hisaab se wiring aur NVR size decide hota hai. Aap HD chahenge ya IP, aur outdoor bhi lagenge?`
      : `Got it. Camera count decides wiring and recorder size. Do you prefer HD or IP, and any outdoor cams?`;
  }

  if (hasCctv || /(lagwana|install|lagana|chahiye|need|want)/i.test(t)) {
    return hi
      ? `Bilkul, DG.YARD CCTV lagata hai. Pehle bataiye — aapko roughly kitne cameras chahiye? Phir main poochunga HD chahiye ya IP.`
      : `Absolutely — DG.YARD installs CCTV. First, roughly how many cameras do you need? Then I'll ask HD or IP.`;
  }

  if (asksPrice) {
    return hi
      ? `Price cameras, HD ya IP, aur site pe depend karti hai. Kitne cameras chahiye aur city kaun si hai? Main rough estimate bataunga.`
      : `Pricing depends on camera count, HD vs IP, and site. How many cameras and which city? I'll share a ballpark.`;
  }

  if (/(haan|yes|interested|batao|ok|theek|ji|suniye)/i.test(t)) {
    return hi
      ? `Bahut accha. Aapki zarurat kya hai — CCTV, networking, ya software? Main step by step help karunga.`
      : `Great. Is your need CCTV, networking, or software? I'll help step by step.`;
  }

  if (/(network|wifi|lan|router|cabling)/i.test(t)) {
    return hi
      ? `Networking ke liye site size aur users matter karte hain. Office hai ya home, aur kitne points chahiye?`
      : `For networking, site size and users matter. Office or home, and how many points?`;
  }

  return hi
    ? `Main sun raha hoon. Thoda clear batayiye — CCTV camera, networking, ya koi aur DG.YARD service? Main aapke sawaal ka seedha jawab dunga.`
    : `I'm listening. Please tell me clearly — CCTV cameras, networking, or another DG.YARD service? I'll answer your question directly.`;
}

export async function generateVoiceReply(opts: {
  customerText: string;
  language: string;
  scriptHint?: string;
  openaiKey?: string;
  agentName?: string;
  conversation?: Array<{ role?: string; text?: string }>;
}): Promise<string> {
  const customer = opts.customerText.trim().slice(0, 500);
  const lang = opts.language || "hi-IN";
  const agent = opts.agentName || "DG.YARD";
  const hi = lang.startsWith("hi");
  const history = (opts.conversation || [])
    .slice(-8)
    .map((m) => `${m.role === "customer" ? "Customer" : "Agent"}: ${String(m.text || "").slice(0, 200)}`)
    .join("\n");

  // Prefer fast local sales dialogue first so the call is not silent for 20–30s waiting on LLM.
  const local = heuristicSalesReply(customer, hi, agent);

  if (opts.openaiKey) {
    try {
      const ac = new AbortController();
      const timer = setTimeout(() => ac.abort(), 4500);
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
          max_tokens: 120,
          messages: [
            {
              role: "system",
              content:
                `You are ${agent}, friendly phone sales for DG.YARD (CCTV, networking, software). ` +
                `Reply ONLY spoken dialogue: 2 short sentences max. No markdown, no lists. ` +
                `ALWAYS answer the customer's actual question first, then ask ONE next question. ` +
                `If they ask HD vs IP: explain simply then ask camera count. ` +
                `If they want CCTV: ask how many cameras, then HD or IP. ` +
                `Match customer language exactly (Hindi/Hinglish vs English). Never restart the intro.`,
            },
            {
              role: "user",
              content:
                `Script hint: ${opts.scriptHint || "(none)"}\n` +
                `Recent turns:\n${history || "(none)"}\n` +
                `Customer just said (${lang}): ${customer}\n` +
                `Draft idea (improve or keep): ${local}`,
            },
          ],
        }),
      });
      clearTimeout(timer);
      if (res.ok) {
        const data = await res.json();
        const text = String(data.choices?.[0]?.message?.content || "").trim();
        if (text) return text.slice(0, 320);
      }
    } catch {
      /* use local */
    }
  }

  return local;
}
