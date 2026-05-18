// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovenian (`sl`).
class AppLocalizationsSl extends AppLocalizations {
  AppLocalizationsSl([String locale = 'sl']) : super(locale);

  @override
  String get settingsTitle => 'Nastavitve';

  @override
  String get settingsAccountSection => 'Račun';

  @override
  String get settingsAccountSubtitle =>
      'Upravljajte nastavitve in preference računa';

  @override
  String get settingsLanguageLabel => 'Jezik';

  @override
  String get languageEnglish => 'Angleščina';

  @override
  String get languageSlovenian => 'Slovenščina';

  @override
  String get navHome => 'Domov';

  @override
  String get navDeals => 'Akcije';

  @override
  String get navList => 'Seznam';

  @override
  String get navProfile => 'Profil';
}
