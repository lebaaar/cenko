import 'dart:ui';

import 'package:cenko/core/constants/constants.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAuthLocale = 'authLocale';

final authLocaleProvider = StateProvider<String>((ref) => 'sl');

Future<String> getAuthLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kAuthLocale);
  if (saved != null && kSupportedLocales.contains(saved)) return saved;
  final deviceLang = PlatformDispatcher.instance.locale.languageCode;
  if (kSupportedLocales.contains(deviceLang)) return deviceLang;
  return 'sl';
}

Future<void> setAuthLocale(String locale) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kAuthLocale, locale);
}

Future<void> clearAuthLocale() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kAuthLocale);
}
