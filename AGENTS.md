# Cenko mobile application

Before continuing, make sure to check out the [README.md](README.md) for an overview.

## Core features
- **Track spending** - scan receipts to automatically track your spending and gain insights into your spending by store
- **Browse all deals in one place** - find the best deals across all major grocery stores in Slovenia. Powered by a custom Python scraper that runs as a cron job on GitHub actions.
- **Shopping list** - app supports private or shared shopping lists. You can share your shopping list with your family or friends and collaborate on it in real time. Adding items on shopping list is done either via manual input or by scanning barcodes. There are some free tier limitations for the shopping list functionality, see [plans.md](https://cenko.app/pricing) for more details.
- **Authentication** - users can sign up and log in with email and password or with Google. Authentication is handled by Firebase Authentication.

## Tech stack
- Flutter for cross-platform mobile development. State management with [Riverpod](https://pub.dev/packages/flutter_riverpod) and navigation with [GoRouter](https://pub.dev/packages/go_router)
- Firebase for backend - authentication, Firestore and AI logic
- OCR with Gemini for structured data extraction
- Scraping store deals with a custom Python scraper - ran as a cron job on a GitHub actions
- Database structure is described in [db.md](docs/db.md). App uses NoSQL Firestore database.


