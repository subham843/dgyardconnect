/**
 * KYC Cloud Functions - Sandbox API (DigiConsole / DigiKYC compatible).
 * Aadhaar OTP, PAN verification, Passive Liveness.
 *
 * Setup: firebase functions:config:set sandbox.api_key="key_test_xxx" sandbox.api_secret="secret_test_xxx"
 *
 * Test mode (key_test): When Sandbox returns "Use test API key" or similar, we return mock
 * reference_id. Use OTP "123456" to verify and get mock e-KYC data for end-to-end testing.
 */
import * as functions from "firebase-functions/v1";
import { getExternalConfig } from "./config";

const SANDBOX_BASE = "https://test-api.sandbox.co.in";
const TEST_OTP = "123456";
const TEST_REF_PREFIX = "test_ref_";

async function getSandboxToken(): Promise<string> {
  const sandbox = getExternalConfig().sandbox;
  if (!sandbox) {
    throw new Error("Sandbox KYC not configured. Set sandbox.api_key and sandbox.api_secret.");
  }
  const res = await fetch(`${SANDBOX_BASE}/authenticate`, {
    method: "POST",
    headers: {
      "x-api-key": sandbox.apiKey,
      "x-api-secret": sandbox.apiSecret,
      "Content-Type": "application/json",
    },
  });
  const json = (await res.json()) as { data?: { access_token?: string }; message?: string };
  const token = json.data?.access_token;
  if (!token) {
    throw new Error(json.message || "Sandbox auth failed");
  }
  return token;
}

async function sandboxRequest(
  path: string,
  body: Record<string, unknown>,
  token: string
): Promise<Record<string, unknown>> {
  const sandbox = getExternalConfig().sandbox;
  if (!sandbox) throw new Error("Sandbox not configured");
  const base = sandbox.baseUrl || SANDBOX_BASE;
  const res = await fetch(`${base}${path}`, {
    method: "POST",
    headers: {
      Authorization: token,
      "x-api-key": sandbox.apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const json = (await res.json()) as Record<string, unknown>;
  if (!res.ok) {
    throw new Error((json.message as string) || `Sandbox API error: ${res.status}`);
  }
  return json;
}

/** Aadhaar OTP - Generate OTP. */
export const kycAadhaarGenerateOtp = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  const aadhaar = String(data?.aadhaar_number ?? "").replace(/\D/g, "");
  const consent = data?.consent as string;
  const reason = (data?.reason as string) || "KYC verification";
  if (aadhaar.length !== 12) {
    throw new functions.https.HttpsError("invalid-argument", "Valid 12-digit Aadhaar required");
  }
  if (consent !== "Y" && consent !== "y") {
    throw new functions.https.HttpsError("invalid-argument", "Consent required");
  }
  const sandbox = getExternalConfig().sandbox;
  const isTestKey = sandbox?.apiKey?.startsWith("key_test") ?? false;

  try {
    const token = await getSandboxToken();
    const result = await sandboxRequest(
      "/kyc/aadhaar/okyc/otp",
      {
        "@entity": "in.co.sandbox.kyc.aadhaar.okyc.otp.request",
        aadhaar_number: aadhaar,
        consent: "Y",
        reason,
      },
      token
    );
    const code = (result.code as number) ?? 0;
    const dataObj = result.data as Record<string, unknown> | undefined;
    const refId = dataObj?.reference_id;
    if (code === 200 && refId != null) {
      return { code: 200, data: { reference_id: String(refId) } };
    }
    const rawMsg = (dataObj?.message as string) || (result.message as string) || "OTP failed";
    const isTestKeyError = rawMsg.toLowerCase().includes("test api key") || rawMsg.toLowerCase().includes("test key");
    if (isTestKey && isTestKeyError) {
      functions.logger.info("kycAadhaarGenerateOtp: Sandbox test key - using mock reference for verification test");
      return { code: 200, data: { reference_id: TEST_REF_PREFIX + aadhaar, test_mode: true } };
    }
    const message = isTestKeyError ? "OTP service temporarily unavailable. Please try again later." : rawMsg;
    return { code: code || 422, message };
  } catch (e) {
    const errMsg = (e as Error).message || "";
    if (isTestKey && (errMsg.toLowerCase().includes("test api key") || errMsg.toLowerCase().includes("test key"))) {
      functions.logger.info("kycAadhaarGenerateOtp: Sandbox test key error - using mock reference");
      return { code: 200, data: { reference_id: TEST_REF_PREFIX + aadhaar, test_mode: true } };
    }
    functions.logger.warn("kycAadhaarGenerateOtp", e);
    throw new functions.https.HttpsError("internal", errMsg);
  }
});

/** Aadhaar OTP - Verify OTP and get e-KYC data. */
export const kycAadhaarVerifyOtp = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  const referenceId = String(data?.reference_id ?? "");
  const otp = String(data?.otp ?? "").trim();
  if (!referenceId || !otp) {
    throw new functions.https.HttpsError("invalid-argument", "reference_id and otp required");
  }
  if (referenceId.startsWith(TEST_REF_PREFIX) && otp === TEST_OTP) {
    functions.logger.info("kycAadhaarVerifyOtp: Test mode - returning mock e-KYC data");
    return {
      code: 200,
      data: {
        name: "Test User",
        care_of: "S/O: Test Father",
        date_of_birth: "01-01-1990",
        full_address: "123 Test Street, Test City, Test State - 560001, India",
        gender: "M",
      },
    };
  }
  try {
    const token = await getSandboxToken();
    const result = await sandboxRequest(
      "/kyc/aadhaar/okyc/otp/verify",
      {
        "@entity": "in.co.sandbox.kyc.aadhaar.okyc.request",
        reference_id: referenceId,
        otp,
      },
      token
    );
    const code = (result.code as number) ?? 0;
    const dataObj = result.data as Record<string, unknown> | undefined;
    const status = dataObj?.status as string;
    const message = (dataObj?.message as string) || (result.message as string);
    if (code === 200 && status === "VALID") {
      return {
        code: 200,
        data: {
          name: dataObj?.name,
          care_of: dataObj?.care_of,
          date_of_birth: dataObj?.date_of_birth,
          full_address: dataObj?.full_address,
          gender: dataObj?.gender,
        },
      };
    }
    return { code: code || 422, message: message || "Verification failed" };
  } catch (e) {
    functions.logger.warn("kycAadhaarVerifyOtp", e);
    throw new functions.https.HttpsError("internal", (e as Error).message);
  }
});

/** PAN verification. */
export const kycPanVerify = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  const panNumber = String(data?.pan_number ?? "").toUpperCase().replace(/\s/g, "");
  const fullName = String(data?.full_name ?? "").trim();
  const dateOfBirth = String(data?.date_of_birth ?? "").trim();
  const consent = data?.consent as string;
  const reason = (data?.reason as string) || "KYC verification";
  if (panNumber.length !== 10) {
    throw new functions.https.HttpsError("invalid-argument", "Valid 10-character PAN required");
  }
  if (!fullName) throw new functions.https.HttpsError("invalid-argument", "Full name required");
  if (!dateOfBirth) throw new functions.https.HttpsError("invalid-argument", "Date of birth required");
  if (consent !== "Y" && consent !== "y") {
    throw new functions.https.HttpsError("invalid-argument", "Consent required");
  }
  try {
    const token = await getSandboxToken();
    const result = await sandboxRequest(
      "/kyc/pan/verify",
      {
        "@entity": "in.co.sandbox.kyc.pan_verification.request",
        pan: panNumber,
        name_as_per_pan: fullName,
        date_of_birth: dateOfBirth,
        consent: "Y",
        reason,
      },
      token
    );
    const code = (result.code as number) ?? 0;
    const dataObj = result.data as Record<string, unknown> | undefined;
    const status = dataObj?.status as string;
    if (code === 200 && status === "valid") {
      return { code: 200 };
    }
    return {
      code: code || 422,
      message: (dataObj?.remarks as string) || (result.message as string) || "PAN verification failed",
    };
  } catch (e) {
    functions.logger.warn("kycPanVerify", e);
    throw new functions.https.HttpsError("internal", (e as Error).message);
  }
});

/** Passive Liveness - selfie verification. When not configured, returns success (admin verifies manually). */
export const kycLivenessVerify = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  const imageUrl = data?.image_url as string;
  if (!imageUrl) throw new functions.https.HttpsError("invalid-argument", "image_url required");
  // Sandbox may not have passive liveness - for now accept and store for admin verification
  return { code: 200, data: { selfie_url: imageUrl } };
});
