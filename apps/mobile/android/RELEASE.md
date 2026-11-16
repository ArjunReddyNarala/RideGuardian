# Android release setup

The Android application ID is `com.arjunreddynarala.rideguardian`, aligned with the existing iOS bundle ID. Register this exact ID as an Android app in the `ride-guardian-2026` Firebase project, download its matching `google-services.json` to `app/`, then rerun FlutterFire configuration so `lib/firebase_options.dart` uses the new Android Firebase app ID and settings. Configure Firebase Phone and Google sign-in. Add the release upload certificate SHA-1 (and SHA-256 where requested) to Firebase/Google Cloud OAuth settings. The currently present ignored `app/google-services.json` and the checked-in Android Firebase options are for the old Firebase Android registration and must be replaced before building.

## Local release credentials

Keep the upload keystore outside source control. Set these Gradle properties in `~/.gradle/gradle.properties` or environment variables:

```properties
RELEASE_STORE_FILE=/absolute/path/to/rideguardian-upload.jks
RELEASE_STORE_PASSWORD=your-store-password
RELEASE_KEY_ALIAS=your-upload-key-alias
RELEASE_KEY_PASSWORD=your-key-password
MAPS_API_KEY=your-restricted-android-maps-key
```

Restrict the Maps key to the Android app ID and signing certificate and enable the Maps SDK for Android in its Google Cloud project. Use the same `MAPS_API_KEY` name for debug builds; debug Maps require the debug signing certificate restriction.

Build the Play upload artifact from `apps/mobile`:

```sh
flutter build appbundle --release
```

The release task checks for Maps and signing configuration and stops with an actionable error if either is missing. Increase the `+buildNumber` in `pubspec.yaml` for every subsequent Play upload. The initial version is `1.0.0+1`.

## Before submitting to Play

- Replace `app/google-services.json` with the Firebase file registered for the application ID above. Confirm Firebase Phone and Google providers are enabled and Google OAuth fingerprints include the upload certificate.
- Supply a restricted Android Maps API key and test the map screens on a real device.
- Configure Play App Signing and retain the upload keystore and its passwords securely. Never commit these credentials.
- Publish a public privacy policy URL and complete Play Console Data safety, location disclosure, app access, content rating, target audience, and store listing declarations. The app handles precise location and ride history; the declarations must match actual backend retention and sharing behavior.
- Test phone and Google sign-in, location permission denial/recovery, an active ride, guardian monitoring, and reconnect behavior on supported Android versions.
- Review the merged release manifest and generated AAB in Play Console's internal testing track before production rollout.
