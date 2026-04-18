import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainTopBar extends StatelessWidget {
  const MainTopBar({super.key, this.onProfileTap, required this.title});

  final VoidCallback? onProfileTap;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 48),
            Expanded(
              child: Center(
                child: title != null
                    ? Text(title!, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))
                    : const SizedBox.shrink(),
              ),
            ),
            SizedBox(
              width: 48,
              child: IconButton(
                onPressed: onProfileTap ?? () => context.push('/notifications'),
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
