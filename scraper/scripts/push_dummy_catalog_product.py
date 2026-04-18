from datetime import datetime, timedelta, timezone

from firebase_connection import get_firestore_client


def main() -> None:
    db = get_firestore_client()

    now = datetime.now(timezone.utc)
    data = {
        "store_name": "SPAR",
        "product_name": "Dummy Greek Yogurt 500g",
        "brand": "DummyBrand",
        "original_price": 399,
        "sale_price": 249,
        "discount_pct": 38,
        "valid_from": now,
        "valid_until": now + timedelta(days=7),
        "scraped_at": now,
    }

    _, doc_ref = db.collection("catalog_products").add(data)
    print(f"Inserted: /catalog_products/{doc_ref.id}")


if __name__ == "__main__":
    main()
