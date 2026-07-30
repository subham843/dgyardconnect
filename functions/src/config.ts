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
import * as functions from "firebase-functions/v1";

let _cached: ReturnType<typeof _getConfig> | null = null;

function _getConfig() {
  const cfg = functions.config();
  const app = cfg.app?.base_url ? { baseUrl: cfg.app.base_url as string } : null;
  const razorpay =
    cfg.razorpay?.key_id && cfg.razorpay?.key_secret
      ? {
          keyId: cfg.razorpay.key_id as string,
          keySecret: cfg.razorpay.key_secret as string,
          webhookSecret: (cfg.razorpay.webhook_secret as string) || undefined,
          /** RazorpayX Lite Customer Identifier for bank account validation (₹1 transfer). From Dashboard → My Account & Settings → Banking → Customer Identifier. */
          xLiteCustomerId: (cfg.razorpay.x_lite_customer_id as string) || undefined,
          /** RazorpayX current account number for payouts. Set for technician withdrawals. */
          xAccountNumber: (cfg.razorpay.x_account_number as string) || undefined,
          /** Fee as decimal (e.g. 0.02 = 2%) applied to dealer payments for Razorpay gateway fee. */
          feePercent: (() => {
            const v = cfg.razorpay?.fee_percent;
            if (typeof v === "number" && !Number.isNaN(v)) return v;
            if (typeof v === "string") { const n = parseFloat(v); if (!Number.isNaN(n)) return n; }
            return undefined;
          })(),
        }
      : null;
  const twilio =
    cfg.twilio?.account_sid && cfg.twilio?.auth_token && cfg.twilio?.phone_number
      ? {
          accountSid: cfg.twilio.account_sid as string,
          authToken: cfg.twilio.auth_token as string,
          phoneNumber: cfg.twilio.phone_number as string,
          whatsappNumber: (cfg.twilio.whatsapp_number as string) || undefined,
          twimlBaseUrl: (cfg.twilio.twiml_base_url as string) || undefined,
        }
      : null;
  const sendgrid =
    cfg.sendgrid?.api_key && cfg.sendgrid?.from_email
      ? { apiKey: cfg.sendgrid.api_key as string, fromEmail: cfg.sendgrid.from_email as string }
      : null;
  const sandbox =
    cfg.sandbox?.api_key && cfg.sandbox?.api_secret
      ? {
          apiKey: cfg.sandbox.api_key as string,
          apiSecret: cfg.sandbox.api_secret as string,
          baseUrl: (cfg.sandbox.base_url as string) || "https://test-api.sandbox.co.in",
        }
      : null;
  return { app, razorpay, twilio, sendgrid, sandbox };
}

export function getExternalConfig() {
  if (!_cached) _cached = _getConfig();
  return _cached;
}
