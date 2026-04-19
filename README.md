# Cenko
Cenko tracks your grocery habits and hunts down the best deals across Slovenian stores so you never miss a sale on the things you actually buy.

> Dragonhack 2026 - Mobile app built in 24 hours with Flutter and Firebase

## Core features
- **Track spending** - scan receipts to automatically track your spending. See your spending breakdown by store and month, with savings tracked from deals you caught
- **Shopping list** - scan barcodes or add items manually to a shopping list. See where each item is cheapest at the moment and get notified when something from your list goes on sale
- **Browse weekly deals** - all catalogs from  Mercator, Spar, Lidl and Hofer in one place, ranked by discount percentage
- **Get personalized deal alerts** - get notified when an item from your shopping list or something that you regularly buy goes on sale


## AI use
- Receipt OCR - The LLM interprets ambiguous receipt line items (čoko ploščice, ž. spodn. hlač.) and guesses category + likely product
- Natural language product search: allow users to search for products using natural language queries like "chocolate bars" or "milk alternatives". Use AI to parse the query and match it to products from catalogs.
- Spending insights: use AI to analyze user's spending habits and provide insights like "You spend 30% of your grocery budget on snacks. Consider switching to cheaper alternatives like X, Y, Z.". Just feed the spending data + catalog data to the LLM and ask for a one-sentence insight.

## Development
- Stack: Flutter with Firebase backend
- State management: [Riverpod](https://pub.dev/packages/flutter_riverpod)
- Routing: [go_router](https://pub.dev/packages/go_router)

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