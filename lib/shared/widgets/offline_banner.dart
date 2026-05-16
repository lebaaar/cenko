import 'package:cenko/app_theme.dart';
import 'package:cenko/shared/providers/internet_status_provider.dart';
import 'package:cenko/shared/widgets/animated_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(internetStatusProvider);

    final isOffline = status.maybeWhen(data: (value) => value == InternetStatus.disconnected, orElse: () => false);

    if (!isOffline) {
      return const SizedBox.shrink();
    }

    return Material(
      color: AppColors.error,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, color: AppColors.onError),
              const SizedBox(width: 10),
              Text(
                'Waiting for connection',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onError, fontWeight: FontWeight.w600),
              ),
              AnimatedDots(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onError, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
