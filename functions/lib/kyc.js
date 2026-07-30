"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.kycLivenessVerify = exports.kycPanVerify = exports.kycAadhaarVerifyOtp = exports.kycAadhaarGenerateOtp = void 0;
/**
 * KYC Cloud Functions - Sandbox API (DigiConsole / DigiKYC compatible).
 * Aadhaar OTP, PAN verification, Passive Liveness.
 *
 * Setup: firebase functions:config:set sandbox.api_key="key_test_xxx" sandbox.api_secret="secret_test_xxx"
 *
 * Test mode (key_test): When Sandbox returns "Use test API key" or similar, we return mock
 * reference_id. Use OTP "123456" to verify and get mock e-KYC data for end-to-end testing.
 */
const functions = require("firebase-functions/v1");
const config_1 = require("./config");
const SANDBOX_BASE = "https://test-api.sandbox.co.in";
const TEST_OTP = "123456";
const TEST_REF_PREFIX = "test_ref_";
async function getSandboxToken() {
    var _a;
    const sandbox = (0, config_1.getExternalConfig)().sandbox;
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
    const json = (await res.json());
    const token = (_a = json.data) === null || _a === void 0 ? void 0 : _a.access_token;
    if (!token) {
        throw new Error(json.message || "Sandbox auth failed");
    }
    return token;
}
async function sandboxRequest(path, body, token) {
    const sandbox = (0, config_1.getExternalConfig)().sandbox;
    if (!sandbox)
        throw new Error("Sandbox not configured");
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
    const json = (await res.json());
    if (!res.ok) {
        throw new Error(json.message || `Sandbox API error: ${res.status}`);
    }
    return json;
}
/** Aadhaar OTP - Generate OTP. */
exports.kycAadhaarGenerateOtp = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const aadhaar = String((_a = data === null || data === void 0 ? void 0 : data.aadhaar_number) !== null && _a !== void 0 ? _a : "").replace(/\D/g, "");
    const consent = data === null || data === void 0 ? void 0 : data.consent;
    const reason = (data === null || data === void 0 ? void 0 : data.reason) || "KYC verification";
    if (aadhaar.length !== 12) {
        throw new functions.https.HttpsError("invalid-argument", "Valid 12-digit Aadhaar required");
    }
    if (consent !== "Y" && consent !== "y") {
        throw new functions.https.HttpsError("invalid-argument", "Consent required");
    }
    const sandbox = (0, config_1.getExternalConfig)().sandbox;
    const isTestKey = (_c = (_b = sandbox === null || sandbox === void 0 ? void 0 : sandbox.apiKey) === null || _b === void 0 ? void 0 : _b.startsWith("key_test")) !== null && _c !== void 0 ? _c : false;
    try {
        const token = await getSandboxToken();
        const result = await sandboxRequest("/kyc/aadhaar/okyc/otp", {
            "@entity": "in.co.sandbox.kyc.aadhaar.okyc.otp.request",
            aadhaar_number: aadhaar,
            consent: "Y",
            reason,
        }, token);
        const code = (_d = result.code) !== null && _d !== void 0 ? _d : 0;
        const dataObj = result.data;
        const refId = dataObj === null || dataObj === void 0 ? void 0 : dataObj.reference_id;
        if (code === 200 && refId != null) {
            return { code: 200, data: { reference_id: String(refId) } };
        }
        const rawMsg = (dataObj === null || dataObj === void 0 ? void 0 : dataObj.message) || result.message || "OTP failed";
        const isTestKeyError = rawMsg.toLowerCase().includes("test api key") || rawMsg.toLowerCase().includes("test key");
        if (isTestKey && isTestKeyError) {
            functions.logger.info("kycAadhaarGenerateOtp: Sandbox test key - using mock reference for verification test");
            return { code: 200, data: { reference_id: TEST_REF_PREFIX + aadhaar, test_mode: true } };
        }
        const message = isTestKeyError ? "OTP service temporarily unavailable. Please try again later." : rawMsg;
        return { code: code || 422, message };
    }
    catch (e) {
        const errMsg = e.message || "";
        if (isTestKey && (errMsg.toLowerCase().includes("test api key") || errMsg.toLowerCase().includes("test key"))) {
            functions.logger.info("kycAadhaarGenerateOtp: Sandbox test key error - using mock reference");
            return { code: 200, data: { reference_id: TEST_REF_PREFIX + aadhaar, test_mode: true } };
        }
        functions.logger.warn("kycAadhaarGenerateOtp", e);
        throw new functions.https.HttpsError("internal", errMsg);
    }
});
/** Aadhaar OTP - Verify OTP and get e-KYC data. */
exports.kycAadhaarVerifyOtp = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const referenceId = String((_a = data === null || data === void 0 ? void 0 : data.reference_id) !== null && _a !== void 0 ? _a : "");
    const otp = String((_b = data === null || data === void 0 ? void 0 : data.otp) !== null && _b !== void 0 ? _b : "").trim();
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
        const result = await sandboxRequest("/kyc/aadhaar/okyc/otp/verify", {
            "@entity": "in.co.sandbox.kyc.aadhaar.okyc.request",
            reference_id: referenceId,
            otp,
        }, token);
        const code = (_c = result.code) !== null && _c !== void 0 ? _c : 0;
        const dataObj = result.data;
        const status = dataObj === null || dataObj === void 0 ? void 0 : dataObj.status;
        const message = (dataObj === null || dataObj === void 0 ? void 0 : dataObj.message) || result.message;
        if (code === 200 && status === "VALID") {
            return {
                code: 200,
                data: {
                    name: dataObj === null || dataObj === void 0 ? void 0 : dataObj.name,
                    care_of: dataObj === null || dataObj === void 0 ? void 0 : dataObj.care_of,
                    date_of_birth: dataObj === null || dataObj === void 0 ? void 0 : dataObj.date_of_birth,
                    full_address: dataObj === null || dataObj === void 0 ? void 0 : dataObj.full_address,
                    gender: dataObj === null || dataObj === void 0 ? void 0 : dataObj.gender,
                },
            };
        }
        return { code: code || 422, message: message || "Verification failed" };
    }
    catch (e) {
        functions.logger.warn("kycAadhaarVerifyOtp", e);
        throw new functions.https.HttpsError("internal", e.message);
    }
});
/** PAN verification. */
exports.kycPanVerify = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const panNumber = String((_a = data === null || data === void 0 ? void 0 : data.pan_number) !== null && _a !== void 0 ? _a : "").toUpperCase().replace(/\s/g, "");
    const fullName = String((_b = data === null || data === void 0 ? void 0 : data.full_name) !== null && _b !== void 0 ? _b : "").trim();
    const dateOfBirth = String((_c = data === null || data === void 0 ? void 0 : data.date_of_birth) !== null && _c !== void 0 ? _c : "").trim();
    const consent = data === null || data === void 0 ? void 0 : data.consent;
    const reason = (data === null || data === void 0 ? void 0 : data.reason) || "KYC verification";
    if (panNumber.length !== 10) {
        throw new functions.https.HttpsError("invalid-argument", "Valid 10-character PAN required");
    }
    if (!fullName)
        throw new functions.https.HttpsError("invalid-argument", "Full name required");
    if (!dateOfBirth)
        throw new functions.https.HttpsError("invalid-argument", "Date of birth required");
    if (consent !== "Y" && consent !== "y") {
        throw new functions.https.HttpsError("invalid-argument", "Consent required");
    }
    try {
        const token = await getSandboxToken();
        const result = await sandboxRequest("/kyc/pan/verify", {
            "@entity": "in.co.sandbox.kyc.pan_verification.request",
            pan: panNumber,
            name_as_per_pan: fullName,
            date_of_birth: dateOfBirth,
            consent: "Y",
            reason,
        }, token);
        const code = (_d = result.code) !== null && _d !== void 0 ? _d : 0;
        const dataObj = result.data;
        const status = dataObj === null || dataObj === void 0 ? void 0 : dataObj.status;
        if (code === 200 && status === "valid") {
            return { code: 200 };
        }
        return {
            code: code || 422,
            message: (dataObj === null || dataObj === void 0 ? void 0 : dataObj.remarks) || result.message || "PAN verification failed",
        };
    }
    catch (e) {
        functions.logger.warn("kycPanVerify", e);
        throw new functions.https.HttpsError("internal", e.message);
    }
});
/** Passive Liveness - selfie verification. When not configured, returns success (admin verifies manually). */
exports.kycLivenessVerify = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const imageUrl = data === null || data === void 0 ? void 0 : data.image_url;
    if (!imageUrl)
        throw new functions.https.HttpsError("invalid-argument", "image_url required");
    // Sandbox may not have passive liveness - for now accept and store for admin verification
    return { code: 200, data: { selfie_url: imageUrl } };
});
//# sourceMappingURL=kyc.js.map