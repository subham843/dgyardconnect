# External Integrations — Razorpay, Twilio, SendGrid, WhatsApp

Yeh guide batata hai ki **Razorpay**, **Twilio** (SMS + Voice), **SendGrid** (Email), aur **WhatsApp** ko kaise configure karein. Sab keys/credentials **Firebase Functions config** mein set hote hain; code mein hardcode mat karo.

---

## 1. Firebase Functions config set karna

**App base URL** (for job-complete notification links, e.g. customer rating page):

```bash
firebase functions:config:set app.base_url="https://your-app.web.app"
```

Replace with your deployed web app URL so SMS/Email/WhatsApp rating links point to the correct domain.

Sab keys Firebase config se aati hain. Project root se ye commands chalao (apne values daal kar):

```bash
# Razorpay (Dashboard: https://dashboard.razorpay.com/)
firebase functions:config:set razorpay.key_id="rzp_live_xxxx" razorpay.key_secret="your_secret"

# Twilio (Console: https://console.twilio.com/)
firebase functions:config:set twilio.account_sid="ACxxxx" twilio.auth_token="your_token" twilio.phone_number="+91xxxxxxxxxx"

# Twilio Voice ke liye TwiML URL (deploy ke baad apna function URL)
# Replace with your actual URL after first deploy, e.g. https://us-central1-YOUR_PROJECT.cloudfunctions.net/twimlMaskedCall
firebase functions:config:set twilio.twiml_base_url="https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net"

# WhatsApp (Twilio WhatsApp number, e.g. whatsapp:+14155238886)
firebase functions:config:set twilio.whatsapp_number="+14155238886"

# SendGrid (API Key: https://app.sendgrid.com/settings/api_keys)
firebase functions:config:set sendgrid.api_key="SG.xxxx" sendgrid.from_email="noreply@yourdomain.com"
```

Config check karne ke liye:

```bash
firebase functions:config:get
```

---

## 2. Razorpay

### Setup

1. [Razorpay Dashboard](https://dashboard.razorpay.com/) → Sign up / Login.
2. **Settings** → **API Keys** → Generate **Key ID** aur **Key Secret** (Test ya Live).
3. `firebase functions:config:set razorpay.key_id="..." razorpay.key_secret="..."` (upar dekho).

### App flow

- Dealer **Proceed to payment** par tap karta hai → **Payment** screen open hoti hai.
- Agar Razorpay configured hai: **createRazorpayOrder** callable se order banata hai → Android/iOS par **Razorpay Checkout** open hota hai.
- Payment success hone par **lockJobPayment** callable **razorpay_order_id**, **razorpay_payment_id**, **razorpay_signature** ke sath call hota hai → backend verify karta hai, phir wallet credit + lock.
- Agar Razorpay configured nahi hai: seedha **lockJobPayment** sirf `jobId` ke sath call hota hai (legacy; payment gateway bina).

### Web

- Web par abhi **Razorpay Checkout** Flutter plugin support nahi karta; **Complete payment** button legacy flow use karta hai (lock without gateway). Production web ke liye Razorpay Web SDK alag se integrate kar sakte ho (hosted page ya custom form).

---

## 3. Twilio — SMS (OTP)

### Setup

1. [Twilio Console](https://console.twilio.com/) → Account SID aur Auth Token (Dashboard par).
2. **Phone Numbers** → **Buy a number** (SMS capable).
3. Config set karo: `twilio.account_sid`, `twilio.auth_token`, `twilio.phone_number`.

### Kaise kaam karta hai

- **sendOtp** callable OTP generate karke Firestore mein save karta hai.
- Agar Twilio configured hai to job ke **siteContactPhone** (ya **pickupContactPhone**) par SMS bhejta hai: *"Your OTP for DG Yard Connect (purpose) is XXXXXX. Valid for 10 minutes."*

---

## 4. Twilio — Voice (Masked call)

### Setup

1. Twilio account + SMS wala number (Voice capable hona chahiye).
2. `twilio.twiml_base_url` set karo — **twimlMaskedCall** function ka public URL. Pehli baar deploy ke baad:
   - Firebase Console → **Functions** → **twimlMaskedCall** → URL copy karo.
   - `firebase functions:config:set twilio.twiml_base_url="https://us-central1-PROJECT.cloudfunctions.net"` (bina function name ke; code andar `/twimlMaskedCall` add karta hai).

### Kaise kaam karta hai

- Technician/Dealer **Call customer** par tap karta hai → **initMaskedCall** callable call hota hai.
- Backend Twilio se **customer** ko call lagata hai (From = Twilio number).
- Customer answer karte hi TwiML run hota hai: "Connecting you to the technician" → **technician** number dial hota hai. Dono connected — customer ko technician ka number nahi dikhta, technician ko customer ka number nahi dikhta.

---

## 5. SendGrid — Email

### Setup

1. [SendGrid](https://sendgrid.com/) → Sign up → **API Keys** → Create API Key.
2. **Sender Authentication** → Single Sender verify karo (from email).
3. `firebase functions:config:set sendgrid.api_key="SG.xxx" sendgrid.from_email="noreply@yourdomain.com"`

### Kaise kaam karta hai

- Job **completed** hone par **sendJobCompleteNotifications** run hota hai.
- Dealer aur Technician ke **users** doc se email (profile.email / email) leta hai.
- SendGrid se **"DG Yard Connect – Job completed"** + message (rating link) bhejta hai.

---

## 6. WhatsApp (Twilio WhatsApp API)

### Setup

1. Twilio Console → **Messaging** → **Try it out** → **Send a WhatsApp message** — Twilio sandbox number milta hai (e.g. +14155238886).
2. Production ke liye [WhatsApp Business API](https://www.twilio.com/docs/whatsapp) through Twilio enable karo.
3. Config: `twilio.whatsapp_number="+14155238886"` (format: whatsapp number bina "whatsapp:" prefix ke; code andar `whatsapp:` laga deta hai).

### Kaise kaam karta hai

- **sendJobCompleteNotifications** mein customer (site contact) ko SMS ke alawa **WhatsApp** bhi bhejta hai agar `twilio.whatsapp_number` set ho — rating link ke sath.

---

## 7. Deploy

Config set karne ke baad functions deploy karo:

```bash
cd e:\dgyardconnect\functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

---

## 8. Checklist

| Service      | Config keys | Purpose                          |
|-------------|-------------|-----------------------------------|
| Razorpay    | razorpay.key_id, razorpay.key_secret | Dealer payment, order create + verify |
| Twilio SMS  | twilio.*    | OTP SMS to site/pickup contact    |
| Twilio Voice| twilio.* + twiml_base_url | Masked call (customer ↔ technician) |
| SendGrid    | sendgrid.api_key, sendgrid.from_email | Job complete email to dealer/technician |
| WhatsApp    | twilio.whatsapp_number | Job complete WhatsApp to customer |

Koi bhi key na ho to us service ka code skip ho jata hai (e.g. Razorpay na ho to legacy payment; Twilio na ho to sirf OTP Firestore mein save, SMS nahi).
