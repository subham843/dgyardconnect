# Play Store Release Checklist

Use this checklist before submitting an Android update to Google Play.

## 1) Policy and Declarations

- Data safety form is updated and matches app behavior for:
  - Authentication (Firebase Auth)
  - Analytics (Firebase Analytics)
  - Location, Camera, Notifications
  - Payments (Razorpay)
- Ads declaration is enabled (`contains ads` = yes).
- Privacy policy URL is live and publicly accessible.
- Account deletion flow is declared and matches in-app behavior.
- App access is configured with reviewer test credentials and clear steps.

## 2) Build and Runtime Config

- Release build uses production ad unit via:
  - `--dart-define=ADMOB_ANDROID_BANNER_UNIT_ID=ca-app-pub-.../...`
- KYC test flags are disabled by default:
  - `KYC_USE_TEST_API=false`
  - `KYC_USE_MOCK_AADHAAR=false`
- `targetSdk` is pinned to current Play requirement.
- Release keystore is configured in `android/key.properties`.

## 3) Critical Flows Smoke Test (Release Build)

- Sign in / OTP flow
- Dealer + Technician onboarding and KYC
- Location and map usage
- Barcode scanner flow
- Push notification receive + tap routing
- Payment flow and receipt generation
- Account deletion from settings
- Ads load on supported screens

## 4) Upload Gate

- Run `flutter analyze` with no new errors.
- Upload final AAB to internal test track first.
- Verify Play Console warnings (policy/security) and resolve all before review submit.
