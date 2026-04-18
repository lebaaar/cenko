import 'package:cenko/app_theme.dart';
import 'package:flutter/material.dart';

class LargeButton extends StatelessWidget {
  const LargeButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final colors = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelLarge;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: Ink(
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : LinearGradient(colors: [colors.primary, AppColors.primaryDim], begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: disabled ? colors.surfaceContainerHigh : null,
          borderRadius: BorderRadius.circular(6),
          boxShadow: disabled ? null : [BoxShadow(color: colors.primary.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(6),
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: SizedBox(
            height: 52,
            child: Center(
              child: loading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onSurface))
                  : Text(label, style: textStyle?.copyWith(color: disabled ? colors.onSurface.withValues(alpha: 0.38) : Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
