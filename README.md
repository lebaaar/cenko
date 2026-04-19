# Cenko
Cenko helps you hunt down the best deals across Slovenian stores for the products you buy the most. Scan your grocery receipts to automatically track your spending and get personalized deal recommendations based on your shopping list and frequently bought products.
Powered by on-device OCR and Gemini for structured data extraction, plus a workflow to fetch all catalog deals.

> Dragonhack 2026 - Mobile app built in 24 hours with Flutter and Firebase

## Core features
- **Track spending** - scan receipts to automatically track your spending and gain insights into your spending by store. Powered by on-device OCR and Gemini for structured data extraction.
- **Browse all deals in one place** - find the best deals across all major stores in Slovenia (Mercator, Spar, Hofer, Tuš and Tuš drogerija). Powered by a workflow that sends data to Claude for data structuring.
- **Shopping list** - build a shopping list by scanning barcodes or adding items manually. See where each item is cheapest at the moment.
- **Personalized recommendations** - get deal recommendations based on your shopping list and frequently bought products.

## Tech stack
- Flutter for cross-platform mobile development. State management with [Riverpod](https://pub.dev/packages/flutter_riverpod) and navigation with [GoRouter](https://pub.dev/packages/go_router).
- Firebase for backend (Auth, Firestore and AI logic)
- On-device OCR with [Google ML Kit](https://pub.dev/packages/google_mlkit_text_recognition) and Gemini for structured data extraction
- Web scraping with [Go](https://pptr.dev/), text extraction from PDFs with [pdfplumber](https://github.com/jsvine/pdfplumber) and data structuring with Claude Haiku

### Running the application
- Install depencides:<br>
`flutter pub get`
- Running in debug:<br>
`flutter run --debug`
- Release build: you will need `android/key.properties` file. Structure of this file can be found in `example-key.properties` file. To run the app in release mode run:<br>
`flutter run --release`

### Setting up the environment
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