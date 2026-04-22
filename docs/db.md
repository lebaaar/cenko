# Database schema

Project uses NoSQL Firestore database

Collections:

## /users/{user_id}

```json
{
  "user_id": 0, // auto-generated
  "name": "string",
  "email": "string",
  "created_at": "timestamp",
  "auth_provider": "email | google",
  "google_id": "string | null",
  "plan": "string", // "free"
  "settings": {
    "theme": "system | dark | light",
    "notificationsEnabled": true
  },
  "stats": {
    "total_spent": 0, // in cents
    "receipts_scanned": 0,
    "most_visited_stores": [
      {
        "store_name": "string",
        "visit_count": 0
      }
    ]
  }
}
```

## /users/{user_id}/receipts/{receipt_id}

```json
{
  "receipt_id": "string", // auto-generated
  "store_name": "string", // eg. Mercator, Lidl, Spar
  "total_price": 0, // in cents
  "item_count": 0,
  "raw_ocr": "string", // full raw OCR text for debugging and future improvements
  "date": "timestamp"
}
```

## /users/{user_id}/receipts/{receipt_id}/items/{item_id}

```json
{
  "item_id": "string", // auto-generated id
  "raw_name": "string", // eg. Milka Oreo 100g
  "unit_price": 0, // price per unit in cents
  "quantity": 0,
  "total_price": 0 // in cents
}
```

## /users/{user_id}/shopping_list/{item_id}

Items the user added to their shopping list

```json
{
  "item_id": "string", // auto-generated id
  "name": "string", // eg. Milka Oreo 100g
  "brand": "string | null", // eg. Milka
  "barcode": "string | null",
  "image_url": "string | null",
  "added_at": "timestamp",
  "bought": false
}
```

## /users/{user_id}/common_products/{item_id}

Items that the user frequently buys, inferred from scanned receipts. Used for personalized deal recommendations on the Home page.

```json
{
  "item_id": "string", // auto-generated id
  "name": "string", // eg. Milka Oreo 100g
  "brand": "string | null", // eg. Milka
  "image_url": "string | null",
  "purchase_count": 0, // distinct receipts in the last 90 days
  "last_purchased_at": "timestamp",
  "added_at": "timestamp" // refreshed to the latest matching receipt date; delete after 45 days of inactivity. Checked each time a receipt is scanned
}
```

## /catalog_products/{product_id}

Scraper results, written by scraper backend (Cloud Function, runs every 3 days).

```json
{
  "product_id": "string", // auto-generated id
  "store_name": "string",
  //"scraped_from_url": "string",
  "product_name": "string",
  "brand": "string | null",
  //"category": "string | null",
  //"image_url": "string | null",
  "original_price": 0,
  "sale_price": 0,
  "discount_pct": 0,
  "valid_from": "timestamp",
  "valid_until": "timestamp",
  "scraped_at": "timestamp"
}
```
