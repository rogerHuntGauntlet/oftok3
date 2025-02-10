# OHFtok App Deployment Checklist

## Prerequisites
- [ ] Firebase project fully configured
- [ ] Google Play Developer account set up
- [ ] App signing key generated
- [ ] Environment variables set up
- [ ] All Firebase configuration files in place
  - [ ] `google-services.json` for Android
  - [ ] `GoogleService-Info.plist` for iOS
  - [ ] Firebase Admin SDK key for Cloud Functions

## Pre-deployment Testing
- [ ] Run full test suite
- [ ] Test all Firebase functionality
- [ ] Test video upload and playback
- [ ] Test user authentication
- [ ] Test project creation and management
- [ ] Test collaborator functionality
- [ ] Test public/private project visibility
- [ ] Verify all environment variables are properly set
- [ ] Test deep links (if implemented)

## Android Release Build
1. Generate release keystore:
```bash
keytool -genkey -v -keystore android/app/release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Set environment variables:
```bash
export KEYSTORE_PASSWORD="your_keystore_password"
export KEY_ALIAS="upload"
export KEY_PASSWORD="your_key_password"
```

3. Build release APK:
```bash
flutter build apk --release
```

4. Build Android App Bundle:
```bash
flutter build appbundle --release
```

## iOS Release Build
1. Update iOS signing configuration in Xcode
2. Set up App Store Connect
3. Build iOS release:
```bash
flutter build ios --release
```

## Firebase Deployment
1. Deploy Cloud Functions:
```bash
cd functions
npm install
firebase deploy --only functions
```

2. Update Security Rules:
```bash
firebase deploy --only firestore:rules
firebase deploy --only storage:rules
```

## Final Checks
- [ ] Test release build on real devices
- [ ] Verify Firebase configuration in release build
- [ ] Check all environment variables are set in production
- [ ] Verify API keys and credentials
- [ ] Test deep links in production
- [ ] Verify analytics and crash reporting
- [ ] Check app signing and ProGuard configuration

## Store Listings
### Google Play Store
- [ ] App description
- [ ] Privacy policy
- [ ] Screenshots
- [ ] Feature graphic
- [ ] App icon
- [ ] Content rating questionnaire
- [ ] App pricing and distribution

### App Store (if deploying to iOS)
- [ ] App description
- [ ] Privacy policy
- [ ] Screenshots
- [ ] App preview video
- [ ] App icon
- [ ] Content rating
- [ ] App pricing and distribution

## Post-deployment
- [ ] Monitor Firebase Console for errors
- [ ] Check analytics data
- [ ] Monitor user feedback
- [ ] Set up automated monitoring
- [ ] Document deployment process for future updates 