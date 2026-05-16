import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'core/constants/constants.dart';
import 'router.dart';
import 'shared/providers/current_user_provider.dart';
import 'shared/services/snack_bar_service.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'shared/providers/internet_status_provider.dart';
import 'shared/widgets/offline_banner.dart';

class CenkoApp extends ConsumerStatefulWidget {
  const CenkoApp({super.key});

  @override
  ConsumerState<CenkoApp> createState() => _CenkoAppState();
}

class _CenkoAppState extends ConsumerState<CenkoApp> {
  bool? _lastOverlayDark;

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
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final userAsync = ref.watch(currentUserProvider);
    final themeMode = userAsync.maybeWhen(data: (user) => _themeModeFromSettings(user?.settings.theme), orElse: () => ThemeMode.system);

    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final brightness = themeMode == ThemeMode.system
        ? platformBrightness
        : themeMode == ThemeMode.dark
        ? Brightness.dark
        : Brightness.light;

    _updateSystemUIOverlayIfNeeded(brightness);

    return MaterialApp.router(
      title: appName,
      scaffoldMessengerKey: SnackBarService.scaffoldMessengerKey,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            final isOffline = ref.watch(internetStatusProvider).maybeWhen(
              data: (v) => v == InternetStatus.disconnected,
              orElse: () => false,
            );
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
                const OfflineBanner(),
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
