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

## /users/{user_id}/shopping_lists_memberships/{list_id}
```json
{
  "list_id": "string", // shopping list id
  "name": "string", // shopping list name (for quick access without fetching the whole list)
  "joined_at": "timestamp"
}
```

## /users/{user_id}/common_products/{item_id}
Items that the user frequently buys, inferred from scanned receipts. Used for personalized deal recommendations on the Home page.
```json
{
  "item_id": "string", // auto-generated id
  "name": "string",
  "brand": "string | null",
  "image_url": "string | null",
  "purchase_count": 0,
  "last_purchased_at": "timestamp",
  "added_at": "timestamp" // refreshed to the latest matching receipt date; delete after 45 days of inactivity. Checked each time a receipt is scanned
}
```

<br><br><br>

## /shopping_lists/{list_id}
Shpping lists can be shared with other users.
```json
{
  "list_id": "string", // auto-generated id
  "name": "string",
  "owner_id": "string", // user_id of list owner - only owner can remove the list (can also transfer ownership to another member)
  "created_at": "timestamp",
  "updated_at": "timestamp",
  "item_count": 88,
  "bought_count": 14,
  "members": [ // max 5 members per list, for free plan, TBD for premium plans
    {
      "user_id": "string",
      "joined_at": "timestamp",
      "role": "owner | member" // owner can remove list and remove members, members can do everything except removing the list and removing other members
    }
  ]
}
```

## /shopping_lists/{list_id}/items/{item_id}
```json
{
  "item_id": "string", // auto-generated id
  "name": "string",
  "brand": "string | null",
  "quantity": 0,
  "unit": "string | null",
  "is_bought": false,
  "added_by": "string",
  "added_at": "timestamp",
  "bought_at": "timestamp | null"
}
```

## /shopping_list_invitations/{invitation_id}
```json
{
  "invitation_id": "string", // auto-generated id
  "list_id": "string",
  "invited_user_id": "string",
  "invited_by_user_id": "string",
  "status": "pending | accepted | declined",
  "sent_at": "timestamp",
  "responded_at": "timestamp | null",
  "expires_at": "timestamp | null"
}
```

<br><br><br>

## /products/{product_id}
Scraper results, products on sale across different stores.
```json
{
  "product_id": "string", // auto-generated id
  "store_name": "string",
  "product_name": "string",
  "brand": "string | null",
  //"category": "string | null",
  "image_url": "string | null",
  "original_price": 0,
  "sale_price": 0,
  "discount_pct": 0,
  "valid_from": "timestamp",
  "valid_until": "timestamp",
  "scraped_at": "timestamp",
  "scrapped_from_url": "string | null"
}
```
