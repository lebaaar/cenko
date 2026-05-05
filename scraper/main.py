from __future__ import annotations

import os

from scripts.db import sync_discounted_products


def main() -> None:
    service_account_path = os.path.expandvars("$RUNNER_TEMP/firebase-key.json")
    collection_name = os.getenv("FIRESTORE_COLLECTION", "products")
    written = sync_discounted_products(
        service_account_path=service_account_path,
        collection_name=collection_name,
    )
    print(f"Upserted {written} discounted products into Firestore collection '{collection_name}'.")


if __name__ == "__main__":
    main()
