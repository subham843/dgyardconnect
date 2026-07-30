/// Legal document IDs and default content. App fetches from Firestore when available; falls back to these.
abstract final class LegalConstants {
  static const String termsOfService = 'terms_of_service';
  static const String privacyPolicy = 'privacy_policy';
  static const String technicianAgreement = 'technician_agreement';
  static const String dealerAgreement = 'dealer_agreement';
  static const String cancellationPolicy = 'cancellation_policy';
  static const String refundPolicy = 'refund_policy';

  static const String termsVersion = '1.0';
  static const String privacyPolicyUrl =
      'https://www.dgyardconnect.com/privacy-policy';

  /// Default content when Firestore doc is missing. Admin can update via Firestore.
  static const Map<String, String> defaultTitles = {
    termsOfService: 'Terms of Service',
    privacyPolicy: 'Privacy Policy',
    technicianAgreement: 'Technician Agreement',
    dealerAgreement: 'Dealer Agreement',
    cancellationPolicy: 'Cancellation Policy',
    refundPolicy: 'Refund Policy',
  };

  static const Map<String, String> defaultContent = {
    termsOfService: '''
D.G.Yard Connect – Terms of Service

Last updated: 2025

1. Acceptance
By accessing or using the D.G.Yard Connect platform ("Platform"), you agree to be bound by these Terms of Service. If you do not agree, do not use the Platform.

2. Description of Service
D.G.Yard Connect is a digital marketplace connecting dealers with independent technicians for service jobs including but not limited to CCTV installation, networking, and computer services. The Platform does not directly perform installation or repair services.

3. User Accounts
You must provide accurate information when registering. You are responsible for maintaining the confidentiality of your account and for all activities under your account.

4. Use of Platform
You agree to use the Platform only for lawful purposes and in accordance with these Terms. You must not misuse the Platform, interfere with its operation, or attempt to gain unauthorized access.

5. Fees and Payments
Payment terms, platform commission, and payment release schedules are as described in the Dealer Agreement, Technician Agreement, and payment flows within the app. Payments are processed through Razorpay.

6. Warranty and Disputes
Service warranty and dispute resolution are governed by the Platform's warranty and dispute policies. By using the Platform you agree to those policies.

7. Limitation of Liability
To the fullest extent permitted by law, D.G.Yard Connect shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the Platform or services arranged through it.

8. Changes
We may update these Terms from time to time. Continued use of the Platform after changes constitutes acceptance of the revised Terms.

9. Contact
For questions regarding these Terms, contact the Platform administrator.
''',
    privacyPolicy: '''
D.G.Yard Connect – Privacy Policy

Last updated: 2025

1. Information We Collect
We collect information you provide when registering (name, email, phone, address, service areas, skills), information related to jobs (locations, descriptions, photos, OTP verification), and payment-related data necessary to process transactions.

2. How We Use Information
We use your information to operate the Platform, match dealers with technicians, process payments, verify job completion (including OTP and photo evidence), handle disputes, and communicate with you. We may use aggregated data for analytics and improving the service.

3. Sharing
We share information only as necessary to provide the service (e.g., with payment processors, with the other party to a job). We do not sell your personal data to third parties.

4. Security
We implement reasonable technical and organizational measures to protect your data. Payment details are handled by Razorpay in accordance with their security standards.

5. Retention
We retain your data for as long as your account is active and as needed to comply with legal obligations, resolve disputes, and enforce our agreements.

6. Your Rights
You may access, correct, or delete your account and personal data from in-app settings where available, or by contacting the Platform administrator.

7. Changes
We may update this Privacy Policy from time to time. We will notify you of material changes through the app or by email where appropriate.
''',
    technicianAgreement: '''
D.G.Yard Connect – Technician Agreement

Last updated: 2025

1. Role
As a technician on D.G.Yard Connect, you are an independent service provider. You are not an employee of the Platform. You agree to perform services independently and in compliance with platform policies and applicable law.

2. Acceptance of Jobs
By accepting a job through the Platform, you confirm that you will perform the service independently, arrive at the scheduled time, complete the work as described, and comply with warranty and quality standards. You agree to provide OTP verification and photo evidence as required by the Platform.

3. Payment
Payment for completed jobs is released as per the Platform's payment schedule (e.g., 80% on dealer approval, 20% after warranty period, subject to platform commission). Withdrawals are processed via Razorpay to your registered account.

4. Warranty and Claims
You agree to respond to warranty claims within the time frame specified by the Platform (e.g., 24 hours). Failure to respond may result in reassignment of the job and deduction from your held payment.

5. Conduct
You agree to maintain accurate profile and KYC information, not to misrepresent your skills or identity, and to treat dealers and end customers professionally.

6. Termination
The Platform may suspend or terminate your access for breach of these terms or platform policies. You may stop using the Platform at any time.
''',
    dealerAgreement: '''
D.G.Yard Connect – Dealer Agreement

Last updated: 2025

1. Role
As a dealer on D.G.Yard Connect, you use the Platform to connect with independent technicians for service jobs. The Platform does not directly perform installation or repair services; it facilitates the connection between you and technicians.

2. Job Posting and Payment
You agree to provide accurate job details and to pay for services through the Platform as per the agreed rate. Payment is held in escrow and released upon job completion and your approval (or auto-approval as per platform policy). A portion of the payment may be held during the warranty period.

3. Approval and Disputes
You agree to review job completion (OTP verification, photos) and to approve or raise disputes within the time frame specified. Disputes are reviewed based on OTP verification, job photos, and service records submitted through the Platform.

4. Cancellation and Refunds
Cancellation and refunds are governed by the Platform's Cancellation Policy and Refund Policy. You agree to those policies by using the Platform.

5. Conduct
You agree to provide accurate job and site information, to communicate professionally with technicians, and not to misuse the Platform or payment system.

6. Termination
The Platform may suspend or terminate your access for breach of these terms or platform policies.
''',
    cancellationPolicy: '''
D.G.Yard Connect – Cancellation Policy

Last updated: 2025

1. Dealer Cancellation
If a dealer cancels a job after a technician has been assigned:
- If the technician has already traveled to the site, travel compensation may apply as determined by the Platform.
- If material pickup has been completed by the technician, pickup compensation may apply.
- The Platform may record cancellation and compensation for audit and dispute purposes.

2. Technician Cancellation
If a technician declines or fails to complete an accepted job, the Platform may reassign the job or allow the dealer to repost. Repeated failures may affect the technician's standing.

3. No-Show
If either party fails to show or complete the job as agreed, the Platform's dispute and compensation rules apply. Evidence (OTP, photos, records) may be used to resolve such cases.

4. Platform Discretion
The Platform reserves the right to cancel or reassign jobs in cases of fraud, policy violation, or operational necessity. Refunds or compensation are handled as per the Refund Policy.
''',
    refundPolicy: '''
D.G.Yard Connect – Refund Policy

Last updated: 2025

1. Payment Flow
Payments made by dealers are held in escrow. Upon job completion and dealer approval (or auto-approval per platform policy), funds are split: platform commission, technician payment (e.g., 80%), and warranty hold (e.g., 20%). Refunds to the dealer are issued only in accordance with this policy and dispute resolutions.

2. When Refunds Apply
- If a dispute is resolved in the dealer's favor, the Platform may refund the dealer from escrow as determined by the admin.
- If a job is cancelled before work has started and before the technician has incurred travel or material costs, the dealer may be eligible for a full refund.
- Partial refunds may apply in other circumstances as determined by the Platform based on evidence (OTP, photos, service records).

3. Warranty Hold Release
The warranty hold is released to the technician after the warranty period ends, unless a valid warranty claim results in deduction (e.g., replacement technician payment). Release is documented via warranty release receipts.

4. Processing
Refunds are processed through the same payment method or wallet as applicable. Processing time may vary. The Platform is not responsible for delays caused by payment processors or banks.

5. Contact
For refund requests or questions, contact the Platform administrator or raise a dispute through the app.
''',
  };

  // ─── In-app disclaimer texts ─────────────────────────────────────────────

  static const String jobCreationDisclaimer =
      'D.G.Yard Connect is a digital platform connecting dealers with independent technicians. The platform does not directly perform installation or repair services.';

  static const String technicianJobAcceptDisclaimer =
      'By accepting this job you confirm that you will perform the service independently and comply with platform policies.';

  static const String paymentDisclaimer =
      'Payments are securely processed through Razorpay. A portion of technician payment may be held during the warranty period.';

  static const String serviceCompletionWarrantyDisclaimer =
      'The service warranty applies only to the work performed by the technician and does not cover hardware products or third-party equipment.';

  static const String disputeNotice =
      'Disputes will be reviewed based on OTP verification, job photos, and service records submitted through the platform.';
}
