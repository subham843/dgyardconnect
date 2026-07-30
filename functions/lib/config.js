"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getExternalConfig = getExternalConfig;
/**
 * External service config. Set via Firebase config or env:
 * firebase functions:config:set razorpay.key_id "rzp_xxx" razorpay.key_secret "xxx"
 * Marketplace webhooks: razorpay.webhook_secret "whsec_xxx" (Dashboard → Webhooks → secret)
 * Optional: razorpay.x_account_number "ACCxxx" (RazorpayX current account for payouts), razorpay.fee_percent 0.02 (2% gateway fee)
 * For bank account validation (₹1 transfer): razorpay.x_lite_customer_id "7878780080316316"
 *   (RazorpayX Dashboard → My Account & Settings → Banking → Customer Identifier)
 * firebase functions:config:set twilio.account_sid "ACxxx" twilio.auth_token "xxx" twilio.phone_number "+1234567890"
 * firebase functions:config:set sendgrid.api_key "SG.xxx" sendgrid.from_email "noreply@yourapp.com"
 *
 * Lazy-loaded to avoid deployment timeout (functions.config() not called at module load).
 */
const functions = require("firebase-functions/v1");
let _cached = null;
function _getConfig() {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
    const cfg = functions.config();
    const app = ((_a = cfg.app) === null || _a === void 0 ? void 0 : _a.base_url) ? { baseUrl: cfg.app.base_url } : null;
    const razorpay = ((_b = cfg.razorpay) === null || _b === void 0 ? void 0 : _b.key_id) && ((_c = cfg.razorpay) === null || _c === void 0 ? void 0 : _c.key_secret)
        ? {
            keyId: cfg.razorpay.key_id,
            keySecret: cfg.razorpay.key_secret,
            webhookSecret: cfg.razorpay.webhook_secret || undefined,
            /** RazorpayX Lite Customer Identifier for bank account validation (₹1 transfer). From Dashboard → My Account & Settings → Banking → Customer Identifier. */
            xLiteCustomerId: cfg.razorpay.x_lite_customer_id || undefined,
            /** RazorpayX current account number for payouts. Set for technician withdrawals. */
            xAccountNumber: cfg.razorpay.x_account_number || undefined,
            /** Fee as decimal (e.g. 0.02 = 2%) applied to dealer payments for Razorpay gateway fee. */
            feePercent: (() => {
                var _a;
                const v = (_a = cfg.razorpay) === null || _a === void 0 ? void 0 : _a.fee_percent;
                if (typeof v === "number" && !Number.isNaN(v))
                    return v;
                if (typeof v === "string") {
                    const n = parseFloat(v);
                    if (!Number.isNaN(n))
                        return n;
                }
                return undefined;
            })(),
        }
        : null;
    const twilio = ((_d = cfg.twilio) === null || _d === void 0 ? void 0 : _d.account_sid) && ((_e = cfg.twilio) === null || _e === void 0 ? void 0 : _e.auth_token) && ((_f = cfg.twilio) === null || _f === void 0 ? void 0 : _f.phone_number)
        ? {
            accountSid: cfg.twilio.account_sid,
            authToken: cfg.twilio.auth_token,
            phoneNumber: cfg.twilio.phone_number,
            whatsappNumber: cfg.twilio.whatsapp_number || undefined,
            twimlBaseUrl: cfg.twilio.twiml_base_url || undefined,
        }
        : null;
    const sendgrid = ((_g = cfg.sendgrid) === null || _g === void 0 ? void 0 : _g.api_key) && ((_h = cfg.sendgrid) === null || _h === void 0 ? void 0 : _h.from_email)
        ? { apiKey: cfg.sendgrid.api_key, fromEmail: cfg.sendgrid.from_email }
        : null;
    const sandbox = ((_j = cfg.sandbox) === null || _j === void 0 ? void 0 : _j.api_key) && ((_k = cfg.sandbox) === null || _k === void 0 ? void 0 : _k.api_secret)
        ? {
            apiKey: cfg.sandbox.api_key,
            apiSecret: cfg.sandbox.api_secret,
            baseUrl: cfg.sandbox.base_url || "https://test-api.sandbox.co.in",
        }
        : null;
    return { app, razorpay, twilio, sendgrid, sandbox };
}
function getExternalConfig() {
    if (!_cached)
        _cached = _getConfig();
    return _cached;
}
//# sourceMappingURL=config.js.map