# SaveEye Flutter SDK Example

This example app requires your own Firebase configuration files to enable Firebase Auth (and related Firebase services) on Android and iOS.

## Place your Firebase config files

| Platform | File                       | Destination path (relative to `example/`) |
| -------: | -------------------------- | ----------------------------------------- |
|  Android | `google-services.json`     | `android/app/google-services.json`        |
|      iOS | `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist`     |

Notes:

## How to obtain these files

1. Create a Firebase project (or select an existing one) in the Firebase console.
2. Add an iOS app and an Android app to the project using this example app's bundle identifiers:
   - Android package name: check `example/android/app/src/main/AndroidManifest.xml` `package` value.
   - iOS bundle identifier: open `example/ios/Runner.xcodeproj` in Xcode and check the Runner target Bundle Identifier.
3. Download the config files from the setup flow and place them in the paths above.

## Run the example

```bash
flutter pub get
flutter run
```

On iOS, if you run into CocoaPods issues after adding the plist, run:

```bash
cd ios && pod install && cd -
```

## Troubleshooting

- "Default FirebaseApp is not initialized" or similar: the config file is missing or placed in the wrong path.
