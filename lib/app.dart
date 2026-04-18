import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'core/constants/constants.dart';
import 'router.dart';
import 'shared/providers/current_user_provider.dart';

class CenkoApp extends ConsumerWidget {
  const CenkoApp({super.key});

  ThemeMode _themeModeFromSettings(String? mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final userAsync = ref.watch(currentUserProvider);
    final themeMode = userAsync.maybeWhen(data: (user) => _themeModeFromSettings(user?.settings.theme), orElse: () => ThemeMode.system);

    // Update system UI overlay style based on theme mode
    ref.listen(currentUserProvider, (_, _) {
      _updateSystemUIOverlay(themeMode, context);
    });

    return MaterialApp.router(
      title: appName,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: kDebugMode,
      builder: (context, child) {
        _updateSystemUIOverlay(themeMode, context);
        return child!;
      },
    );
  }

  void _updateSystemUIOverlay(ThemeMode themeMode, BuildContext context) {
    Brightness brightness;
    if (themeMode == ThemeMode.system) {
      brightness = MediaQuery.of(context).platformBrightness;
    } else {
      brightness = themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light;
    }

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
}
