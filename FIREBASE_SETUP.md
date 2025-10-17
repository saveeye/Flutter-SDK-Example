# Firebase Auth Setup for SaveEye Flutter SDK Example

This example app now includes Firebase Authentication with email/password and anonymous authentication.

## Prerequisites

1. A Firebase project
2. Android Studio or VS Code with Flutter extensions
3. Flutter SDK installed

## Setup Instructions

### 1. Firebase Project Setup

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use an existing one
3. Enable Authentication in your Firebase project:
   - Go to Authentication > Sign-in method
   - Enable "Email/Password" sign-in provider
   - Enable "Anonymous" sign-in provider

### 2. Android Configuration

**Note**: Email/password authentication works without additional configuration files. The app will work out of the box with Firebase Auth.

**Optional - For production apps:**

1. **Add your app to Firebase:**
   - In Firebase Console, go to Project Settings
   - Click "Add app" and select Android
   - Use package name: `com.example.saveeye_flutter_sdk_example`
   - Download the `google-services.json` file and place it in `android/app/`

### 3. Dependencies

The following dependencies have been added to `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
```

### 4. Build Configuration

The Android build configuration is simplified for email/password authentication:

- No Google Services plugin required
- No additional configuration files needed
- Works with standard Firebase Core setup

## Features

### Authentication Methods

1. **Email/Password Sign-In**: Users must sign in with email and password
2. **Automatic Sign-In**: Users stay signed in across app sessions
3. **Required Authentication**: Users must be signed in to access the app

### User Interface

- **Simple Sign-In Form**: Clean email/password authentication
- **Form Validation**: Email format validation and error handling
- **Error Handling**: Clear error messages for authentication issues
- **User Profile**: Shows user information and authentication status
- **Sign Out**: Easy sign-out functionality via menu

### Integration with SaveEye SDK

The app maintains the original SaveEye SDK functionality while adding authentication:

- Users must be authenticated to access the device list
- User information is displayed in the app
- Authentication state is managed automatically

## Running the App

1. **Install dependencies:**

   ```bash
   cd example
   flutter pub get
   ```

2. **Run the app:**
   ```bash
   flutter run
   ```

## Authentication Flow

### Sign Up Flow

1. User enters email and password
2. User confirms password
3. App validates input (email format, password strength, password match)
4. Firebase creates new user account
5. User is automatically signed in

### Sign In Flow

1. User enters email and password
2. App validates input
3. Firebase authenticates user
4. User is signed in and redirected to device screen

### Guest Flow

1. User clicks "Continue as Guest"
2. Firebase creates anonymous user
3. User is signed in and redirected to device screen

### Debug Flow

1. User clicks "Bypass Auth (Debug)"
2. User is directly redirected to device screen
3. Debug mode indicator is shown

## Troubleshooting

### Common Issues

1. **Authentication not working:**

   - Check Firebase Console for enabled sign-in methods
   - Verify internet connectivity
   - Check Firebase project configuration

2. **Build errors:**

   - Clean and rebuild: `flutter clean && flutter pub get`
   - Ensure all dependencies are properly installed

3. **Email validation errors:**
   - Check email format
   - Ensure email is not already in use (for sign up)
   - Verify password meets requirements (6+ characters)

### Debug Information

- Check Firebase Console for authentication logs
- Use `flutter logs` to see runtime errors
- Ensure internet connectivity for Firebase services

## Security Notes

- The example uses placeholder values for SDK keys
- Replace with actual values before production use
- Consider implementing proper JWT token generation for SaveEye SDK integration
- Review Firebase security rules for production deployment
- **Important**: Email/password auth doesn't require `google-services.json` for basic functionality
- For production apps, consider adding Firebase configuration for analytics and other features

## Next Steps

1. Replace placeholder SDK keys with actual values
2. Implement proper JWT token generation based on Firebase Auth tokens
3. Add additional authentication providers if needed
4. Implement proper error handling and user feedback
5. Add unit tests for authentication flows
6. Configure Firebase security rules for production
