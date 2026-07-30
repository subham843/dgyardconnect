/// App-wide constants. Formal English copy for production.
abstract final class AppConstants {
  static const String appName = 'D.G.Yard Connect';
  static const String appTagline = 'Connect. Dispatch. Deliver.';

  /// Shown on splash and phone entry (intro).
  static const String introTagline = 'Where Dealers Meet Trusted Technicians.';

  // Auth
  static const String loginTitle = 'Sign In';
  static const String registerTitle = 'Create Account';
  static const String emailHint = 'Email address';
  static const String passwordHint = 'Password';
  static const String confirmPasswordHint = 'Confirm password';
  static const String nameHint = 'Full name';
  static const String phoneHint = 'Phone number';
  static const String enterPhone = 'Enter your mobile number';
  static const String sendOtp = 'Send OTP';
  static const String enterOtp = 'Enter OTP';
  static const String verifyOtp = 'Verify OTP';
  static const String whereToServe = 'Where do you want to serve?';
  static const String useCurrentLocation = 'Use current location';
  static const String selectAddressManually = 'Select address manually';
  static const String radiusKm = 'Radius (km)';
  static const String addressDetails = 'Address details';
  static const String userDetails = 'Your details';
  static const String buildingApartment = 'Building / Apartment name';
  static const String landmark = 'Landmark';
  static const String areaName = 'Area / Locality name';
  static const String city = 'City';
  static const String state = 'State';
  static const String pincode = 'Pincode';
  static const String selectCategories = 'Select categories you deal in';
  static const String selectSkills = 'Select your skills';
  static const String waitingForAdminApproval = 'Waiting for admin approval';
  static const String waitingForAdminApprovalMessage =
      'Your registration has been submitted. You will be notified once the admin approves your account.';
  static const String confirmLocation = 'Confirm location';
  static const String confirmDetails = 'Confirm details';
  static const String houseFlatShopNumber = 'House no. / Flat no. / Shop no.';
  static const String address = 'Address';
  static const String chooseAccountType = 'Choose account type';
  static const String signInWithEmail = 'Sign in with email instead';
  static const String usePhoneNumber = 'Use phone number';
  static const String rememberEmailPassword = 'Remember email & password';
  static const String forgotPassword = 'Forgot password?';
  static const String noAccount = "Don't have an account?";
  static const String haveAccount = 'Already have an account?';
  static const String registerAsDealer = 'Register as Dealer';
  static const String registerAsTechnician = 'Register as Technician';
  static const String pendingApprovalTitle = 'Registration Pending';
  static const String pendingApprovalMessage =
      'Your registration is under review. You will be notified once approved.';

  // Roles
  static const String roleAdmin = 'Super Admin';
  static const String roleDealer = 'Dealer';
  static const String roleTechnician = 'Technician';

  // General
  static const String submit = 'Submit';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String next = 'Next';
  static const String back = 'Back';
  static const String loading = 'Loading...';
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String retry = 'Retry';
  static const String ok = 'OK';
  static const String signInRequired = 'Please sign in to continue.';

  // Location & permissions (Step 20 – formal English)
  static const String locationPermissionDenied =
      'Location permission is required. Please enable it in device settings.';
  static const String locationError =
      'Unable to get location. Please check permissions and try again.';
  static const String mapPermissionRequired =
      'Location access is needed to show your position on the map.';

  // KYC
  static const String kycUploadSuccess =
      'Document uploaded. Pending admin verification.';
  static const String kycUploadFailed = 'Upload failed. Please try again.';

  // Wallet
  static const String withdrawNotAvailable =
      'Withdrawal will be available when Razorpay payout is configured.';

  // Validation
  static const int minPasswordLength = 8;
  static const int minNameLength = 2;
  static const int maxNameLength = 100;
  static const int phoneLength = 10;
}
