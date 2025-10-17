# Firebase Quick Setup Guide

## Current Issue

You're getting the error: `[core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()`

## Quick Fix Steps

### 1. Clean and Rebuild

```bash
cd example
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run
```

### 2. Verify Firebase Configuration

**Check your `google-services.json` file:**

- Location: `android/app/google-services.json`
- Should contain your project details (you already have this)

**Verify Android configuration:**

- ✅ Google Services plugin added to `build.gradle.kts`
- ✅ Google Services plugin applied in `app/build.gradle.kts`

### 3. Enable Authentication in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `saveeye-app-dev`
3. Go to **Authentication** > **Sign-in method**
4. Enable **Email/Password** provider
5. Save changes

### 4. Test the App

After completing the above steps:

1. Run `flutter run`
2. The app should now show the sign-in screen
3. You can create test accounts in Firebase Console > Authentication > Users

## Troubleshooting

### If you still get Firebase errors:

1. **Check Firebase Console:**

   - Ensure your project is active
   - Verify Authentication is enabled
   - Check that Email/Password is enabled

2. **Verify Configuration:**

   ```bash
   # Check if google-services.json is valid
   cat android/app/google-services.json | head -10
   ```

3. **Clean Everything:**
   ```bash
   flutter clean
   cd android
   ./gradlew clean
   cd ..
   flutter pub get
   flutter run
   ```

### Alternative: Use Firebase CLI

If manual setup doesn't work:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project
cd example
firebase init

# Follow the prompts to set up Authentication
```

## Expected Behavior

After proper setup:

- ✅ App shows sign-in screen
- ✅ No Firebase initialization errors
- ✅ Users can sign in with email/password
- ✅ Successful authentication leads to SaveEye SDK screen

## Need Help?

If you're still having issues:

1. Check Firebase Console for any project issues
2. Verify your `google-services.json` matches your project
3. Ensure all dependencies are properly installed
4. Try running on a different device/emulator

The app is designed to work with proper Firebase configuration!
