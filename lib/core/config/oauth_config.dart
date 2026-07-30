/// OAuth client IDs for native Google / Facebook sign-in.
///
/// **Google (Android):** If `google-services.json` has empty `oauth_client` or
/// Google Sign-In returns a null `idToken`, add **SHA-1** and **SHA-256** in
/// Firebase Console → Project settings → Android app, then re-download
/// `google-services.json`. Alternatively paste your **Web client ID** here
/// (ends with `.apps.googleusercontent.com` from Google Cloud Console →
/// APIs & Services → Credentials → OAuth 2.0 Client IDs → Web client).
///
/// **Facebook:** Set [facebookAppId] and [facebookClientToken] to match
/// [android/app/src/main/res/values/strings.xml](android/app/src/main/res/values/strings.xml)
/// and enable Facebook login in Firebase Authentication.
abstract final class OAuthConfig {
  static const String googleWebClientId = '';

  /// Same numeric App ID as `facebook_app_id` in Android `strings.xml`.
  static const String facebookAppId = '';

  /// Same as `facebook_client_token` in Android `strings.xml` (Meta dashboard).
  static const String facebookClientToken = '';
}
