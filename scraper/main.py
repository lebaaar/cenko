from __future__ import annotations

import os

from scripts.db import sync_discounted_products


def main() -> None:
    database_url = os.getenv("DATABASE_URL")
    written = sync_discounted_products(database_url=database_url)
    print(f"Upserted {written} discounted products into Supabase.")


if __name__ == "__main__":
    main()
