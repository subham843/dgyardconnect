# KYC Setup – DigiConsole / Sandbox Test API

KYC flow uses **Sandbox.co.in** test API for Aadhaar, PAN, and Passive Liveness.

## 1. Sandbox API Credentials

1. Sign up at https://developer.sandbox.co.in
2. Get **Test** API Key and Secret (prefix `key_test_` and `secret_test_`)

## 2. Configure Cloud Functions

```bash
firebase functions:config:set sandbox.api_key="key_test_YOUR_KEY" sandbox.api_secret="secret_test_YOUR_SECRET"
```

## 3. Deploy Functions

```bash
cd functions && npm install && npm run build && firebase deploy --only functions
```

## 4. Flow

### Technician (App)

1. **Aadhaar** – Enter 12-digit Aadhaar → Send OTP → Enter OTP → Verified
2. **PAN** – Enter PAN, full name, DOB (DD/MM/YYYY) → Verify
3. **Passive Liveness** – Capture selfie
4. **Skill Certificates** (optional) – Add documents
5. **Submit** – Sends to admin for final verification

### Admin

- KYC screen lists pending users
- Shows Aadhaar ✓, PAN ✓, Liveness ✓, certificates count
- Approve → `kycStatus: verified`
- Reject → `kycStatus: rejected`

## Firestore Schema

```
users/{uid}
  kycStatus: "pending" | "verified" | "rejected"
  kycData:
    aadhaarVerified: true
    aadhaarName: "..."
    panVerified: true
    panNumber: "ABCDE1234F"
    livenessVerified: true
    livenessSelfieUrl: "https://..."
    skillCertificates: ["url1", "url2"]
    submittedAt: Timestamp
```

## Cloud Functions

| Function | Purpose |
|----------|---------|
| kycAadhaarGenerateOtp | Send OTP to Aadhaar-linked mobile |
| kycAadhaarVerifyOtp | Verify OTP, return e-KYC data |
| kycPanVerify | Verify PAN with name/DOB |
| kycLivenessVerify | Accept selfie (admin verifies manually) |
