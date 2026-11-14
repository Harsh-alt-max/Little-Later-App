import 'package:firebase_core/firebase_core.dart';

/// Firebase project `littlelater-61969` (values from google-services.json).
const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyB892SNxeXdCML_APdGchJzF6k6hAVtbsE',
  appId: '1:239842393149:android:f38c4f0216a41bdc903e54',
  messagingSenderId: '239842393149',
  projectId: 'littlelater-61969',
  storageBucket: 'littlelater-61969.firebasestorage.app',
);

/// "Web client ID" from Firebase console → Authentication → Sign-in method →
/// Google → Web SDK configuration. Needed for Google sign-in on Android.
/// Set at build time with --dart-define=GOOGLE_WEB_CLIENT_ID=... (GitHub secret).
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

/// Public website (GitHub Pages). Used for invite links and the privacy page.
const siteUrl = 'https://harsh-alt-max.github.io/Little-Later-App';
