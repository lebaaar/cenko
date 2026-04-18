import 'package:flutter/material.dart';

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
            const SizedBox(
              width: 48,
              height: 48, // 👈 preserves original height
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
