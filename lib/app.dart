import 'package:cenko/app_theme.dart';
import 'package:cenko/core/constants/constants.dart';
import 'package:cenko/l10n/app_localizations.dart';
import 'package:cenko/router.dart';
import 'package:cenko/shared/providers/auth_locale_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/shared/services/snack_bar_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CenkoApp extends ConsumerStatefulWidget {
  const CenkoApp({super.key});

  @override
  ConsumerState<CenkoApp> createState() => _CenkoAppState();
}

class _CenkoAppState extends ConsumerState<CenkoApp> {
  bool? _lastOverlayDark;

  // Cached from last successful currentUserProvider data
  // Prevents locale/theme flicker when the provider errors (eg. network drops and the Supabase fetch fails).
  Locale? _cachedLocale;
  ThemeMode? _cachedThemeMode;

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

  Locale _localeFromSettings(String? lang) {
    switch (lang) {
      case 'sl':
        return const Locale('sl');
      case 'en':
        return const Locale('en');
      default:
        return const Locale('sl');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final userAsync = ref.watch(currentUserProvider);
    final authLocale = ref.watch(authLocaleProvider);

    // Update cache when real data arrives; hold cached value during loading/error so locale and theme don't revert when the network drops temporarily.
    final themeMode = userAsync.when(
      data: (user) => _cachedThemeMode = _themeModeFromSettings(user?.theme),
      loading: () => _cachedThemeMode ?? ThemeMode.system,
      error: (e, _) => _cachedThemeMode ?? ThemeMode.system,
    );
    final locale = userAsync.when(
      data: (user) => _cachedLocale = _localeFromSettings(user?.lang ?? authLocale),
      loading: () => _cachedLocale ?? _localeFromSettings(authLocale),
      error: (e, _) => _cachedLocale ?? _localeFromSettings(authLocale),
    );

    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final brightness = themeMode == ThemeMode.system
        ? platformBrightness
        : themeMode == ThemeMode.dark
        ? Brightness.dark
        : Brightness.light;

    _updateSystemUIOverlayIfNeeded(brightness);

    return MaterialApp.router(
      title: kAppName,
      scaffoldMessengerKey: SnackBarService.scaffoldMessengerKey,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: kDebugMode,
    );
  }

  void _updateSystemUIOverlayIfNeeded(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    if (_lastOverlayDark == isDark) {
      return;
    }
    _lastOverlayDark = isDark;

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
