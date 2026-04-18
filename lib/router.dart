import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'app_theme.dart';

import 'shared/providers/auth_provider.dart';
import 'features/auth/ui/forgot_password_screen.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/auth/ui/register_screen.dart';
import 'features/home/ui/home_screen.dart';
import 'features/notifications/ui/notification_screen.dart';
import 'features/product_detail/ui/product_detail_screen.dart';
import 'features/profile/ui/profile_screen.dart';
import 'features/deals/ui/deals_screen.dart';
import 'features/scan/ui/scan_screen.dart';
import 'features/settings/ui/settings_screen.dart';
import 'features/shopping_list/ui/shopping_list_screen.dart';

const _authPaths = {'/login', '/register', '/forgot-password'};

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      if (authState.isLoading) return null;

      final isAuthenticated = authState.value != null;
      final isOnAuth = _authPaths.contains(state.matchedLocation);

      if (!isAuthenticated && !isOnAuth) return '/login';
      if (isAuthenticated && isOnAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/deals', builder: (context, state) => const DealsScreen()),
          GoRoute(
            path: '/scan',
            builder: (context, state) => ScanScreen(initialMode: state.uri.queryParameters['mode']),
          ),
          GoRoute(path: '/list', builder: (context, state) => const ShoppingListScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: '/notifications', builder: (context, state) => const NotificationScreen()),
        ],
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
});

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final showBottomNav = !location.startsWith('/scan');
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: showBottomNav ? _BottomNavBar(location: location, onTap: (route) => _onTap(context, route)) : null,
    );
  }

  void _onTap(BuildContext context, String route) {
    if (GoRouterState.of(context).matchedLocation == route) {
      return;
    }

    context.go(route);
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.location, required this.onTap});

  final String location;
  final ValueChanged<String> onTap;

  bool _isSelected(String route) {
    if (route == '/home') return location.startsWith('/home');
    return location.startsWith(route);
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primary;
    final brightness = Theme.of(context).brightness;
    final unselectedColor = brightness == Brightness.light ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(28)),
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      label: 'Home',
                      icon: Icons.home_rounded,
                      selected: _isSelected('/home'),
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      onTap: () => onTap('/home'),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      label: 'Deals',
                      icon: Icons.percent_rounded,
                      selected: _isSelected('/deals'),
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      onTap: () => onTap('/deals'),
                    ),
                  ),
                  const SizedBox(width: 68),
                  Expanded(
                    child: _NavItem(
                      label: 'List',
                      icon: Icons.checklist_rounded,
                      selected: _isSelected('/list'),
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      onTap: () => onTap('/list'),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      label: 'Profile',
                      icon: Icons.person_rounded,
                      selected: _isSelected('/profile'),
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      onTap: () => onTap('/profile'),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 15,
              child: GestureDetector(
                onTap: () => onTap('/scan'),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(child: SvgPicture.asset('assets/icons/barcode_scanner.svg', width: 32, height: 32)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
