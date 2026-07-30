// Ed25519 webhook signature check (optional — only when public key configured).
import nacl from "https://esm.sh/tweetnacl@1.0.3";

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64.trim());
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** Returns true if valid, false if invalid. When no publicKey, returns true (skip). */
export function verifyTelnyxSignature(opts: {
  rawBody: string;
  signatureB64: string | null;
  timestamp: string | null;
  publicKeyB64: string;
  maxAgeSec?: number;
}): boolean {
  const pub = opts.publicKeyB64.trim();
  if (!pub) return true;
  if (!opts.signatureB64 || !opts.timestamp) return false;
  const ts = Number(opts.timestamp);
  if (!Number.isFinite(ts)) return false;
  const age = Math.abs(Date.now() / 1000 - ts);
  if (age > (opts.maxAgeSec ?? 300)) return false;
  try {
    const msg = new TextEncoder().encode(`${opts.timestamp}|${opts.rawBody}`);
    const sig = b64ToBytes(opts.signatureB64);
    const pk = b64ToBytes(pub);
    return nacl.sign.detached.verify(msg, sig, pk);
  } catch {
    return false;
  }
}
