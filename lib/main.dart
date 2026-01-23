import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:saveeye_flutter_sdk/saveeye_flutter_sdk.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth_screen.dart';
import 'screens/device_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  bool firebaseInitialized = false;
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    firebaseInitialized = true;
  } catch (e) {
    // Firebase initialization failed
    firebaseInitialized = false;
  }

  // Initialize SaveEye SDK
  try {
    print('Initializing SaveEye SDK');
    SaveEyeClient.instance.initialize(
      'CNrlw0s0ckK0KjrbwHMDkz6Jo0V3a8BJrCuEOaQn7qM=', // Replace with your actual SDK key
      () async {
        // This function should return a JWT token
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token == null) {
          throw Exception(
            'Failed to retrieve JWT token. User may not be authenticated.',
          );
        }
        return token;
      },
      environment: SaveEyeEnvironment.prod,
      debug: true,
    );
  } catch (e) {
    print('SaveEye SDK initialization failed: $e');
  }

  runApp(MyApp(firebaseInitialized: firebaseInitialized));
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;

  const MyApp({super.key, required this.firebaseInitialized});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaveEye SDK Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: AuthWrapper(firebaseInitialized: firebaseInitialized),
    );
  }
}

class AuthWrapper extends HookWidget {
  final bool firebaseInitialized;

  const AuthWrapper({super.key, required this.firebaseInitialized});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AuthScreen();
        }
        return const DeviceListScreen();
      },
    );
  }
}

// AuthScreen and DeviceListScreen moved to screens/ directory
