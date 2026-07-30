# Update management + Remote Config

This app uses **Firebase Remote Config** for:

- **Minor runtime changes**: primary color, banner/headings text, feature flags
- **Update prompts**: optional vs force update based on version

## Remote Config keys (add in Firebase Console)

Create these keys in **Firebase Console → Remote Config**.

### UI / runtime config

- `ui_primary_color_hex`
  - Example: `"#1E88E5"`
  - Empty string means "don’t override"

- `app_texts_json`
  - JSON map of string → string
  - Example:
    ```json
    {
      "home_banner": "New: instant payouts",
      "home_heading": "Welcome back"
    }
    ```

- `feature_flags_json`
  - JSON map of string → boolean
  - Example:
    ```json
    {
      "enableChat": true,
      "enableAds": false
    }
    ```

**Admin-managed**: These runtime keys can be published from the Admin panel (App updates screen) via the callable Cloud Function `setAppRuntimeConfig`.

### Update management

- `app_latest_version`
  - Example: `"1.3.0"`
  - If current app version is lower than this, user sees an **optional** update prompt.

- `app_min_supported_version`
  - Example: `"1.2.0"`
  - If current app version is lower than this, user sees a **force update** prompt (cannot skip).

- `app_update_source`
  - `"apk"` or `"playstore"`
  - Controls whether the Update button:
    - downloads + installs an APK in-app, or
    - opens the Play Store URL externally

- `app_update_title`
  - Example: `"Update available"`

- `app_update_message`
  - Example: `"We’ve improved stability and added new features."`

- `app_update_changelog`
  - Multi-line text is supported.
  - Example:
    ```
    • Faster login
    • New technician wallet UI
    • Bug fixes
    ```

- `app_update_url`
  - Used when `app_update_source = "playstore"`.
  - Example: Play Store listing URL (or a landing page).

- `app_update_apk_url`
  - Used when `app_update_source = "apk"`.
  - Example: Firebase Storage download URL for your latest APK.

## How it works

- On app startup:
  - Remote Config is fetched (`fetchAndActivate`)
  - Current app version is read via `package_info_plus`
  - Decision rules:
    - **Force update** if `current < app_min_supported_version`
    - **Optional update** if `current < app_latest_version`

- When the user taps **Update**:
  - If `app_update_source = "playstore"`: opens `app_update_url` using `url_launcher`
  - If `app_update_source = "apk"` (Android only):
    - downloads `app_update_apk_url` with progress
    - requests **Install unknown apps** permission if needed
    - launches the Android package installer

## Using texts/feature flags in UI

Remote Config is exposed via `AppRemoteConfigController` (Provider).

Example usage in any widget:

```dart
final rc = context.watch<AppRemoteConfigController>().config;
final banner = rc.text('home_banner', fallback: '');
final chatEnabled = rc.isFeatureEnabled('enableChat', defaultValue: true);
```

## Firestore alternative (if you prefer)

Remote Config is the default because it’s built for this use case (caching, targeting, gradual rollouts).

If you want Firestore instead, use a single doc like:

- collection: `config`
- doc: `app_update`
- fields: `latestVersion`, `minSupportedVersion`, `changelog`, `updateUrl`, `apkUrl`

Then replace the Remote Config read in `FirebaseRemoteConfigService.readUpdateConfig()` with a Firestore fetch.

