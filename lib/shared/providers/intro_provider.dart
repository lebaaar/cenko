import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kIntroductionShown = 'introductionShown';

final introductionShownProvider = StateProvider<bool>((ref) => true);

Future<bool> getIntroductionShown() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kIntroductionShown) ?? false;
}

Future<void> setIntroductionShown() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kIntroductionShown, true);
}
