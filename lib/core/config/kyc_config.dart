/// KYC API configuration for DigiConsole / Sandbox / DigiKYC.
///
/// Uses Cloud Functions to proxy API calls (API keys must stay on backend).
/// Test API: Sandbox (https://test-api.sandbox.co.in)
/// - Aadhaar OTP, PAN verification, Passive Liveness
///
/// Test mode (key_test): When Sandbox returns "Use test API key", backend returns
/// mock reference_id. Use OTP "123456" to verify and get mock e-KYC data.
///
/// Set up Cloud Functions: kycAadhaarGenerateOtp, kycAadhaarVerifyOtp,
/// kycPanVerify, kycLivenessVerify - these call Sandbox/DigiConsole with your keys.
abstract final class KycConfig {
  /// Use test/sandbox environment for development.
  /// Keep false by default for production safety.
  static const bool useTestApi = bool.fromEnvironment(
    'KYC_USE_TEST_API',
    defaultValue: false,
  );

  /// When true, Aadhaar OTP uses local mock (no Cloud Function needed).
  /// Use Aadhaar 999999999999 + OTP 123456 to test KYC flow.
  /// Set to false when Cloud Functions are deployed and working.
  /// Keep false by default for production safety.
  static const bool useMockAadhaarForTesting = bool.fromEnvironment(
    'KYC_USE_MOCK_AADHAAR',
    defaultValue: false,
  );

  /// Cloud Function names for KYC (backend holds API keys).
  static const String fnAadhaarGenerateOtp = 'kycAadhaarGenerateOtp';
  static const String fnAadhaarVerifyOtp = 'kycAadhaarVerifyOtp';
  static const String fnPanVerify = 'kycPanVerify';
  static const String fnLivenessVerify = 'kycLivenessVerify';
}
