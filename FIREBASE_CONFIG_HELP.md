# Firebase Configuration Help

## The Error You're Seeing

The error `[core/no-app] No Firebase App '[DEFAULT]' has been created` occurs when Firebase is not properly configured for your project.

## Quick Fix Options

### Option 1: Run in Debug Mode (Recommended for Development)

The app is designed to work without Firebase configuration. If Firebase fails to initialize, the app will automatically run in debug mode, allowing you to test the SaveEye SDK functionality directly.

### Option 2: Configure Firebase (For Production)

1. **Create a Firebase Project:**

   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project or use an existing one

2. **Enable Authentication:**

   - Go to Authentication > Sign-in method
   - Enable "Email/Password" provider
   - Enable "Anonymous" provider

3. **Add Android App (Optional):**

   - In Project Settings, click "Add app" and select Android
   - Use package name: `com.example.saveeye_flutter_sdk_example`
   - Download `google-services.json` and place it in `android/app/`

4. **Update Dependencies:**
   ```bash
   cd example
   flutter pub get
   ```

## Current App Behavior

- ✅ **With Firebase**: Full authentication flow (Sign In, Sign Up, Guest)
- ✅ **Without Firebase**: Debug mode with direct access to SaveEye SDK
- ✅ **Error Handling**: Graceful fallback when Firebase is not available

## Debug Mode Features

When Firebase is not configured, the app will:

- Skip authentication screens
- Show "DEBUG MODE" indicator
- Allow direct access to SaveEye SDK functionality
- Display user as "Debug User"

## Testing SaveEye SDK

You can test the SaveEye SDK functionality in debug mode by:

1. Running the app (it will automatically enter debug mode if Firebase fails)
2. Using the device ID field to test device queries
3. Observing the SaveEye SDK integration

## Production Deployment

For production apps:

1. Set up proper Firebase project
2. Configure authentication providers
3. Replace placeholder SDK keys with real values
4. Implement proper JWT token generation

The app is designed to be resilient and work in both development and production environments!
