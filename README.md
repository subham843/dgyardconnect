# DG Yard Connect

Multi-role job dispatch app (Ola/Uber style) for **Super Admin**, **Dealer**, and **Technician**. Built with Flutter (Web, Android, iOS) and Firebase.

## What's included

- **Production-ready UI/UX**: Themed app (Material 3), formal English copy, consistent spacing, and **animations** (splash, login, cards, transitions) via `flutter_animate`.
- **Complete folder structure**: All screens and shared code as per [IMPLEMENTATION_STEPS.md](IMPLEMENTATION_STEPS.md).
- **Auth flow**: Splash → Login / Register (Dealer or Technician) → Pending approval or role home. Role-based routing with `go_router`.
- **Admin home**: Dashboard with navigation to Pending approvals, Master data, KYC, Dealers, Technicians, Jobs, Override level, Penalty & status.
- **Dealer & Technician homes**: Dashboard with Post job, My jobs, Wallet, Profile, KYC; job detail with Bidding, Track, Rate, Chat; technician Incoming job (full-screen ring), Job execution with OTP.
- **Shared layer**: Models (User, Job, Wallet, master data), services (Auth, Firestore, FCM, Storage, Razorpay, Notifications), widgets (Map picker, OTP, Rating form, Level badge, Profile cards).
- **Firebase**: `firebase/` (Firestore rules, indexes) and `functions/` (TypeScript: onJobCreated, onJobRejected, lockJobPayment, onDealerConfirm, warrantyUnlock, onRatingSubmitted, penalty/OTP/submitCustomerRating callables).

## Run the app

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Run without Firebase** (current default)
   ```bash
   flutter run -d chrome
   ```
   You’ll see “Firebase not configured” in the console; the app still runs and goes to Login.

3. **Run with Firebase**
   ```bash
   flutterfire configure
   flutter run -d chrome
   ```

## Production build

| Platform | Command | Output |
|----------|---------|--------|
| Web | `flutter build web --release` | `build/web/` |
| Android APK | `flutter build apk --release` | `build/app/outputs/flutter-apk/` |
| Android App Bundle | `flutter build appbundle --release` | `build/app/outputs/bundle/release/` |
| iOS | `flutter build ios --release` | Open in Xcode to archive |

Deploy Firebase (rules, functions, storage): `firebase deploy`.  
Full steps: see [DEPLOYMENT.md](DEPLOYMENT.md).

## Super Admin login and database

Step-by-step: **[SUPER_ADMIN_AND_DATABASE_SETUP.md](SUPER_ADMIN_AND_DATABASE_SETUP.md)** — Firebase project, Firestore, Auth, Super Admin user (manual), and database collections.

## External integrations (Razorpay, Twilio, SendGrid, WhatsApp)

Configure keys and complete setup: **[EXTERNAL_INTEGRATIONS.md](EXTERNAL_INTEGRATIONS.md)**. Backend supports: Razorpay (create order + verify in lockJobPayment), Twilio SMS (OTP), Twilio Voice (masked call), SendGrid (job-complete email), Twilio WhatsApp (job-complete message).

## Push notifications (FCM)

Agar notifications (approval, job request, etc.) send/receive nahi ho rahe: **[NOTIFICATION_SETUP.md](NOTIFICATION_SETUP.md)** — Android, iOS, Web aur Cloud Functions ka setup, FCM token save, aur troubleshooting.

## Implementation status

See [TODOS_COMPLETED.md](TODOS_COMPLETED.md) and [NEXT_MOVE_DONE.md](NEXT_MOVE_DONE.md) for what is done.

- **Done**: Auth, registration (with sectors/skills, service area), pending/profile approvals, **KYC with document upload**, post job (with rate matrix suggestion, platform fee), job roll + FCM, incoming job, bidding, **payment** (Razorpay createOrder + verify, PaymentScreen), dealer confirm, wallet (80/20, warranty unlock, **technician withdrawal** requestWithdrawal + UI), live tracking, proofs/OTP + proof photo capture, rating (dealer/technician/customer), reputation/levels/penalty, emergency jobs, travel expense, customer rate & chat links, chat, **call customer** (Twilio Voice when configured). **Notifications**: SendGrid email, Twilio SMS/WhatsApp on job complete; **app.base_url** for rating links. **Production**: release build (web/apk), deployment guide ([DEPLOYMENT.md](DEPLOYMENT.md)), formal English copy and error messages.
- **Remaining**: Add API keys per [EXTERNAL_INTEGRATIONS.md](EXTERNAL_INTEGRATIONS.md) (Razorpay, Twilio, SendGrid, app.base_url). Razorpay Payouts can be wired inside `requestWithdrawal` when ready.
