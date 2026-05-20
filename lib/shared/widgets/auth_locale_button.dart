import 'package:cenko/shared/providers/auth_locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthLocaleButton extends ConsumerWidget {
  const AuthLocaleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(authLocaleProvider);
    final next = locale == 'en' ? 'sl' : 'en';

    return TextButton.icon(
      onPressed: () async {
        await setAuthLocale(next);
        ref.read(authLocaleProvider.notifier).state = next;
      },
      icon: const Icon(Icons.language, size: 18),
      label: Text(locale.toUpperCase()),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
