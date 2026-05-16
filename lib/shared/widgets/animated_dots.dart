import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedDots extends StatefulWidget {
  final TextStyle? style;

  const AnimatedDots({super.key, this.style});

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots> {
  int _dots = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      setState(() => _dots = _dots == 3 ? 1 : _dots + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('.' * _dots, style: widget.style);
  }
}
