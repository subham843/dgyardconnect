# Google Play Console Compliance Checklist

## App Content
- Privacy policy URL: `https://www.dgyardconnect.com/privacy-policy`
- Contains ads: `Yes` (AdMob initialized in app)
- Target audience: `General` (not children-directed)

## Payments Policy
- Android in-app payments for digital services must use Play-compliant billing flow.
- External/direct gateway checkout has been disabled in Android client payment screen.
- Do not submit Android release with digital checkout routed outside Play billing.

## Account Deletion
- In-app account deletion is available from Settings > Delete account.
- Deletion requires authenticated user session; recent-login errors are surfaced to user.

## Data Safety Mapping (declare based on actual backend behavior)
- Personal info: name, phone, email, address.
- Financial info: payment records/receipts.
- Location: coarse + precise location.
- Photos and files: job/KYC images and uploads.
- Messages: in-app job chat messages.
- App activity and analytics: Firebase Analytics events.
- Device/app identifiers: push token and ad identifiers (where applicable).

## Permissions In Release Manifest
- `INTERNET`
- `CAMERA`
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `POST_NOTIFICATIONS`
- `RECEIVE_BOOT_COMPLETED`
- `USE_FULL_SCREEN_INTENT`
- `VIBRATE`
- `WAKE_LOCK`

## Pre-Upload Verification
1. Build release AAB.
2. Confirm merged manifest does not include `REQUEST_INSTALL_PACKAGES` or `READ_CONTACTS`.
3. Validate Android payment screen does not launch external payment gateway.
4. Validate account deletion flow from settings.
5. Ensure Play Console Data Safety and Ads answers match this checklist.
