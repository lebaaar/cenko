# Cenko
Cenko tracks your grocery habits and hunts down the best deals across Slovenian stores so you never miss a sale on the things you actually buy.

> Dragonhack 2026 - Mobile app built in 24 hours with Flutter and Firebase

## Core features
- **Track spending** - scan receipts to automatically track your spending. See your spending breakdown by store and month, with savings tracked from deals you caught
- **Shopping list** - scan barcodes or add items manually to a shopping list. See where each item is cheapest at the moment and get notified when something from your list goes on sale
- **Browse weekly deals** - all catalogs from  Mercator, Spar, Lidl and Hofer in one place, ranked by discount percentage
- **Get personalized deal alerts** - get notified when an item from your shopping list or something that you regularly buy goes on sale

## UI
### Layout
- Top bar
    - Center: App logo and name in home page, page title otherwise
    - Right: notifications icon
    - Left: back button when on a pushed page
- Navigation bar
    - Home - home icon
    - Deals - tag/percent icon
    - Scan - barcode icon, raised center button. Top bar is hidden on the Scan page, camera takes up the whole screen
    - Shopping List - list icon
    - Profile - profile info and spendings information - profile icon

## Home page
- Good morning/afternoon/evening, [user name], N shopping list items that you often buy are on sale this week
- 2 sections:
    - Your shopping list items on sale (Personalized deal cards, ranked by discount percentage). Sources:
        - Items the user has scanned or entered manually
        - Items inferred from scanned receipts (matched items, appearing 2+ times)
    - Best deals this week (Best deals across all supported stores, ranked by discount percentage)
        - Scrape and sort catalogs by discount percentage, show top 10 deals across all supported stores. Only show products that are currently on sale in catalogs

    Items shown in cards. Each card has a product image or category fallback icon, item name, store name, current price, original price, discount badge (e.g. −28%). Tapping opens Product details page.


## Deals page
- Full with search up top. Searches only products currently present in scraped catalogs. 404 displays message "This product isn't on sale in any supported stores this week."
- Fliter row:
    - Store filter: horizontal scrollable pill row — All, Mercator, Lidl, Hofer, Spar, Kaufland. Multi-select.
    - Price filter: range slider, min 0 € to max 50 €
    - Sort: dropdown — Best discount, Lowest price, Highest discount, Recently added to catalog
- Delas 2 column grid:
    - Each card has a product image or category fallback icon, product name, store name, Current price (large) and original price (struck through), discount badge (e.g. −28%), valid until date. Tapping opens Product details page.


## Scan page
Full-screen camera view. Top bar hidden. Two tabs at the top of the viewfinder: Barcode and Receipt. Close button (X) top-right returns to previous page.
- Barcode scan tab
    - Camera shows a centered square reticle for barcode alignment
    - On successful scan, vibrates and plays a soft tone
    - Looks up barcode in Open [Food Facts API](https://world.openfoodfacts.net/api/v2/product/3830000167383.json)
    - If found: navigates to Product details page pre-populated with name, brand, image, nutrition info, and any matching catalog deal
    - If not found: navigates to Product details page in "manual entry" mode — user can enter name, brand, category, and store. Saves to their shopping list on confirmation.
- Receipt scan tab
    - Camera shows a rectangular portrait reticle with corner guides. User taps shutter to capture
    - Processing screen: spinner with label "Reading your receipt..." shown while OCR + matching runs in the background.
    - OCR extracts: store name, date, total price, and items (short name + price per item)
        - AI needed here to interpret ambiguous item names such as "čoko ploščice" or "m. spodn. hlač." and search catalogs for it
    - Results screen shows all the data capruted. User can correct store name, date, total, and any individual item name or price before saving. No match-state UI in MVP — raw OCR output only, editable.
    - On save: receipt is logged to Spendings (store, date, total, item count).

## Shopping List page
In this page there are all the CRUD operations regarding shopping lists. Additionally, there are buttons to add to shopping list on Home and Deals page.
Features:
- CRUD shopping lists. Both manual centry and barcode scan is supported
- Mark/unmark as bought
- Each item shows where it is cheapest at the moment (On sale now label...)

## Profile page
- User avatar (initials circle) + display name + "Member since [month year]" + receipts scanned count
- Spedings section
    - Heading: month selector - select month and year. Tap arrows to move forward/back. Defaults to current month.
    - Card: Shows total spending for selected month. Secondary line compares to previous month: "↓ 12% vs March" or "↑ 8% vs March" with colour coding (green = less, red = more).     Third line: "Saved X € using deals this month."
    - Spending by store (column chart)
    - Bar chart, one bar per store. X-axis: store names. Y-axis: euros spent. Bars coloured by store (consistent colour per store across the app). Tapping a bar shows a tooltip with exact amount and number of receipts from that store.
    - Recently scanned receipts with  _Show all scanned receipts_ button - goes to Logged Receipts pages
- Account settings (goes to Settings page)
- Notifications settings (goes to Notifications page)
- Log out button

### Product details page
Pushed screen, reached from: deal card tap (Home, Deals), barcode scan result, item row tap (Shopping List page). Back button in top bar returns to caller.
- Header: catalog image if available; Open Food Facts image if scanned by barcode; category illustration fallback. Full-width, 200px height. Product name, brand
- Current deals
    - If the product is currently on sale in one or more catalogs: Best deal shown prominently: store name + store logo, sale price (large), original price (struck through), discount badge, valid until date
    - If on sale at multiple stores simultaneously: "Also on sale at" collapsed list showing other stores with their respective prices, sorted by price ascending
    - If not on sale: "Not on sale this week in any supported store."
- TBD - nutrition info from Open Food Facts if available (only for barcode scans, not manual entries). Nutrition info section shows: calories, carbs, sugar, protein, fat per 100g. Collapsed by default, tap to expand. Score (A to E) if available.
- When reached from a failed barcode lookup, the page opens in edit mode: all fields are empty and editable. Same fields as above — name, brand, category. "Save item" button at bottom. Nutrition info section hidden (no data source).
- Actions:
    - Add to my shopping list (grayed out "Saved" if already in user's shopping list)
    - Share product (opens system share sheet with product name and link to app)

### Logged receipts page
Simple scrollable view of all logged receipts

## AI potential
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

### Resources
- [Database (Firestore)](./docs/db.md)
- [Design - Stitch](https://stitch.withgoogle.com/projects/1120235833466103146)


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

## Learning resources

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
