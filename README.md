<div align="center">
  <img src="assets/cenko/logo_rounded.png" alt="Cenko" height="70" />
  <h1 align="center">Cenko</h1>
</div>

Cenko brings all deals from major Slovenian stores into one place, making sure you always get the best price. Share shopping lists with family or friends and scan receipts to automatically track your spending.

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
- Supabase backend - authentication (with Google or email/password), Postgres database
- Firebase for AI logic with Gemini for structured data extraction
- OCR with Gemini for structured data extraction
- Scraping store deals with a custom Python scraper

## Development
See [CONTRIBUTING.md](CONTRIBUTING.md) for instructions on how to set up your development environment and contribute to the project.