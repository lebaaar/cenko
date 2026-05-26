import 'package:cenko/app.dart';
import 'package:cenko/firebase_options.dart';
import 'package:cenko/shared/providers/auth_locale_provider.dart';
import 'package:cenko/shared/providers/intro_provider.dart';
import 'package:cenko/shared/services/device_security_service.dart';
import 'package:cenko/shared/services/exception_reporting_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DeviceBlockedApp extends StatelessWidget {
  const _DeviceBlockedApp({required this.reason});
  final String reason;

  String get _message => switch (reason) {
    'emulator' => 'This app cannot run on an emulator or simulator.',
    'rooted' => 'This app cannot run on a rooted or jailbroken device.',
    _ => 'This device does not meet the security requirements to run this app.',
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF145750),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, size: 64, color: Colors.white),
                const SizedBox(height: 24),
                const Text(
                  'Security Check Failed',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _message,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
  ExceptionReportingService.setupGlobalHandlers();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _setSystemUIOverlayStyle(Brightness.dark); // Set initial (dark) style

  // disable landscape mode
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Block release builds on emulators and rooted/jailbroken devices.
  if (!kDebugMode) {
    final insecureReason = await DeviceSecurityService.checkDevice();
    if (insecureReason != null) {
      runApp(_DeviceBlockedApp(reason: insecureReason));
      return;
    }
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
  );
  await Supabase.initialize(url: dotenv.env['SUPABASE_URL']!, anonKey: dotenv.env['SUPABASE_ANON_KEY']!);
  await GoogleSignIn.instance.initialize();
  final introductionShown = await getIntroductionShown();
  final authLocale = await getAuthLocale();
  runApp(
    ProviderScope(
      overrides: [introductionShownProvider.overrideWith((ref) => introductionShown), authLocaleProvider.overrideWith((ref) => authLocale)],
      child: const CenkoApp(),
    ),
  );
}
