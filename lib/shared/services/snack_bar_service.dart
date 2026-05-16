import 'package:cenko/core/constants/constants.dart';
import 'package:flutter/material.dart';

class SnackBarService {
  SnackBarService._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static bool _isShowing = false;
  static int _showToken = 0;

  static void show(String message, {Duration? duration}) {
    final state = scaffoldMessengerKey.currentState;
    if (state == null) return;

    if (_isShowing) {
      state.hideCurrentSnackBar();
    }

    _isShowing = true;
    final token = ++_showToken;

    state
        .showSnackBar(
          SnackBar(
            content: Text(message),
            duration: duration ?? const Duration(seconds: kSnackBarDurationSeconds),
          ),
        )
        .closed
        .then((_) {
          if (_showToken == token) _isShowing = false;
        });
  }
}
