<div align="center">
  <img src="assets/cenko/logo_rounded.png" alt="Cenko" height="70" />
  <h1 align="center">Cenko</h1>
</div>

Cenko brings all deals from major Slovenian stores into one place so you always get the best price. Share shopping lists with family or friends and scan receipts to automatically track your spending. Based on your purchase habits, you also get personalized deal recommendations tailored to what you buy most.

> Dragonhack 2026 - Best use of APIs reward

<div align="center">
    <img src="assets/cenko/demo.gif" alt="Cenko demo" height="600" />
</div>


## Core features
- **Track spending** - scan receipts to automatically track your spending and gain insights into your spending by store
- **Browse all deals in one place** - find the best deals across all major stores in Slovenia (Mercator, Spar, Hofer, Tuš and Tuš drogerija)
- **Shared shopping list** - create shopping lists and share them with family or friends and make sure you always get the best deal for the products on your list
- **Personalized recommendations** - get deal recommendations based on your shopping list and frequently bought products
- **Supported languages** - English and Slovenian

## Tech stack
- Flutter for cross-platform mobile development. State management with [Riverpod](https://pub.dev/packages/flutter_riverpod) and navigation with [GoRouter](https://pub.dev/packages/go_router)
- Firebase backend - authentication (with Google or email/password), Firestore database and AI logic
- OCR with Gemini for structured data extraction
- Scraping store deals with a custom Python scraper

## Future improvements
- **Shared shopping lists** - allow users to share shopping lists with family members or friends
- **Support more stores** - scrape catalogs of more stores
- **Price tracking** - track price changes of frequently bought products or shopping lists and notify users of significant price drops
- **Better OCR and data extraction** - improve the accuracy of receipt scanning and data structuring with more advanced LLMs

## Development
**To run the app locally:**
- Install depencides:<br>
`flutter pub get`
- Running in debug:<br>
`flutter run --debug`
- Release build: you will need `android/key.properties` file. Structure of this file can be found in `example-key.properties` file. To run the app in release mode run:<br>
`flutter run --release`
- To generate localization files after updating ARB files run:<br>
`flutter gen-l10n` or simply `flutter run` since it's included in the build process

**Internationalization (i18n):**

Supported locales: English (`en`), Slovenian (`sl`)

ARB translation files live in `lib/l10n/`:
| File | Role |
|------|------|
| `app_en.arb` | Template — English strings + `@key` metadata |
| `app_sl.arb` | Slovenian translations (no `@` metadata needed) |

**To add a new translatable string:**
1. Add the key + English value to `app_en.arb`:
    ```json
    "myKey": "Hello world",
    "@myKey": { "description": "What this string is for" }
    ```
2. Add the Slovenian translation to `app_sl.arb`:
    ```json
    "myKey": "Pozdravljen svet"
    ```
3. Regenerate: `flutter gen-l10n` (or just `flutter run`)
4. Use in any widget:
    ```dart
    import 'package:cenko/l10n/app_localizations.dart';
    // ...
    Text(AppLocalizations.of(context)!.myKey)
    ```

Generated `app_localizations*.dart` files in `lib/l10n/. These are auto-created, don't edit them manually.

**Firebase stuff:**
- Deploy Firestore rules and indexes:<br>
`firebase deploy --only firestore:rules,firestore:indexes`
- See [Firebase Functions](functions/README.md) for instructions on how to deploy and run functions locally

**To setup the development environment for Android:**
1. Install [Android Studio](https://developer.android.com/studio)
2. Under Tools -> SDK Manager -> SDK Platforms install Android 16.0 ("Baklava")
3. Under Tools -> SDK Manager -> SDK Tools install Android SDK Build-Tools, NDK (Side by side), Android SDK Command-line Tools (latest), CMake, Android Emulator and Android SDK Platform-Tools
4. Create an enulator in Tools -> Device Manager.<br>
Check if emaultor is installed by running  `flutter emuators` and run it via `flutter emulators --launch <emulator id>`
5. Install FlutterFire and Firebase CLI:
    ```bash
    npm install -g firebase-tools
    dart pub global activate flutterfire_cli
    echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.bashrc # add to PATH
    source ~/.bashrc
    firebase login
    flutterfire configure
    ```

**Secrets:**
- Copy `.env.example` to `.env` and fill in the secrets. Get in touch with the developers if you need access to the secrets.
