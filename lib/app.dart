import 'dart:async';

import 'package:cenko/app_theme.dart';
import 'package:cenko/core/constants/constants.dart';
import 'package:cenko/l10n/app_localizations.dart';
import 'package:cenko/router.dart';
import 'package:cenko/shared/providers/auth_locale_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/shared/providers/internet_status_provider.dart';
import 'package:cenko/shared/services/snack_bar_service.dart';
import 'package:cenko/shared/widgets/offline_banner.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class CenkoApp extends ConsumerStatefulWidget {
  const CenkoApp({super.key});

  @override
  ConsumerState<CenkoApp> createState() => _CenkoAppState();
}

class _CenkoAppState extends ConsumerState<CenkoApp> with WidgetsBindingObserver {
  bool? _lastOverlayDark;
  bool _suppressOffline = false;
  Timer? _suppressTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _suppressTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _suppressOffline = true);
      _suppressTimer?.cancel();
      _suppressTimer = Timer(const Duration(milliseconds: 7500), () {
        if (mounted) setState(() => _suppressOffline = false);
      });
    }
  }

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
    final themeMode = userAsync.maybeWhen(data: (user) => _themeModeFromSettings(user?.settings.theme), orElse: () => ThemeMode.system);
    final authLocale = ref.watch(authLocaleProvider);
    final locale = userAsync.maybeWhen(
      data: (user) => _localeFromSettings(user?.settings.language ?? authLocale),
      orElse: () => _localeFromSettings(authLocale),
    );

    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final brightness = themeMode == ThemeMode.system
        ? platformBrightness
        : themeMode == ThemeMode.dark
        ? Brightness.dark
        : Brightness.light;

    _updateSystemUIOverlayIfNeeded(brightness);

    final suppressOffline = _suppressOffline;

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
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            final isOffline =
                !suppressOffline && ref.watch(internetStatusProvider).maybeWhen(data: (v) => v == InternetStatus.disconnected, orElse: () => false);
            Widget childWidget = child ?? const SizedBox.shrink();
            if (isOffline) {
              final mq = MediaQuery.of(context);
              childWidget = MediaQuery(
                data: mq.copyWith(padding: mq.padding.copyWith(top: 0)),
                child: childWidget,
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                OfflineBanner(suppressOffline: suppressOffline),
                Expanded(child: childWidget),
              ],
            );
          },
        );
      },
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
