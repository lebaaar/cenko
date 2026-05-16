import 'package:cenko/app.dart';
import 'package:cenko/firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  await dotenv.load(fileName: '.env');
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _setSystemUIOverlayStyle(Brightness.dark); // Set initial (dark) style

  // disable landscape mode
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
  );
  await GoogleSignIn.instance.initialize();
  runApp(const ProviderScope(child: CenkoApp()));
}
