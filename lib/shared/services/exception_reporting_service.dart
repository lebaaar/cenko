import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExceptionReportingService {
  ExceptionReportingService._();
  static void setupGlobalHandlers() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details); // keep default console output
      report(details.exception, details.stack ?? StackTrace.empty, context: details.context?.toString());
    };

    // Unhandled Dart errors outside the Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, context: 'PlatformDispatcher.unhandledError');
      return false; // false = not handled, Flutter applies default behavior
    };
  }

  /// Report an exception
  /// [context] Where the error occurred, e.g. `'DealsScreen._addDealToShoppingList'`
  /// [userId] Supabase UID; resolved from current session when null
  static Future<void> report(Object exception, StackTrace stackTrace, {String? context, String? userId}) async {
    if (kDebugMode) {
      debugPrint('[CENKO_EXCEPTION] Exception in $context: $exception\n$stackTrace');
      return;
    }

    try {
      await _send(exception, stackTrace, context: context, userId: userId);
    } catch (_) {
      // Don't surface webhook errors to the user
    }
  }

  static Future<void> _send(Object exception, StackTrace stackTrace, {String? context, String? userId}) async {
    final webhookUrl = dotenv.maybeGet('DISCORD_WEBHOOK_EXCEPTION');
    if (webhookUrl == null || webhookUrl.isEmpty) return;

    final uid = userId ?? _currentUserId();
    final appInfo = await _appInfo();
    final deviceInfo = await _deviceInfo();
    final frames = _topAppFrames(stackTrace);

    final fields = <Map<String, dynamic>>[
      {'name': 'Exception', 'value': exception.toString(), 'inline': false},
      if (context != null && context.isNotEmpty) {'name': 'Context', 'value': _cap(context, 500), 'inline': false},
      {'name': 'User ID', 'value': uid ?? 'unauthenticated', 'inline': true},
      {'name': 'App', 'value': appInfo, 'inline': true},
      {'name': 'Device', 'value': deviceInfo, 'inline': true},
      {'name': 'Stack (app frames)', 'value': '```\n${_cap(frames, 980)}\n```', 'inline': false},
    ];

    final payload = {
      'username': 'Cenko App',
      'embeds': [
        {'title': exception.runtimeType.toString(), 'color': 0xE74C3C, 'fields': fields, 'timestamp': DateTime.now().toUtc().toIso8601String()},
      ],
    };

    await http
        .post(Uri.parse(webhookUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 10));
  }

  static String? _currentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _appInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }

  static Future<String> _deviceInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        return '${a.manufacturer} ${a.model} · Android ${a.version.release}';
      } else if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        return '${i.name} ${i.model} · iOS ${i.systemVersion}';
      }
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  /// Returns top N app-package frames from the stack trace.
  /// Falls back to first N raw lines if no app frames found.
  static String _topAppFrames(StackTrace stackTrace, {int max = 10}) {
    final lines = stackTrace.toString().split('\n').where((l) => l.trim().isNotEmpty).toList();
    final appLines = lines.where((l) => l.contains('package:cenko')).take(max).toList();
    return (appLines.isNotEmpty ? appLines : lines.take(max).toList()).join('\n');
  }

  static String _cap(String s, int max) => s.length <= max ? s : '${s.substring(0, max - 1)}…';
}
