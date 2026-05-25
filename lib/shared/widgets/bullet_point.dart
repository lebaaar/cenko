import 'package:flutter/material.dart';

/// A bullet point row. Pass either [text] (convenience) or [child] (custom widget).
class BulletPoint extends StatelessWidget {
  const BulletPoint(String text, {super.key})
      : _text = text,
        _child = null;

  const BulletPoint.widget({required Widget child, super.key})
      : _text = null,
        _child = child;

  final String? _text;
  final Widget? _child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _child ?? Text(_text!, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
