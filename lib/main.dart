import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app.dart';
import 'firebase_options.dart';

// Web client ID from Firebase Console → Authentication → Sign-in method → Google → Web client ID
// Only needed if google-services.json doesn't have a web OAuth client (oauth_client type 3).
const _webClientId = null; // e.g. '12345-xxxx.apps.googleusercontent.com'

void _setSystemUIOverlayStyle(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark ? Colors.black : Colors.white,
      systemNavigationBarDividerColor: isDark ? Colors.black : const Color(0xFFE0E0E0),
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _setSystemUIOverlayStyle(Brightness.dark); // Set initial (dark) style

  // disable landscape mode
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GoogleSignIn.instance.initialize(serverClientId: defaultTargetPlatform == TargetPlatform.android ? _webClientId : null);
  runApp(const ProviderScope(child: CenkoApp()));
}
