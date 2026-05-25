from __future__ import annotations

import argparse
import os

from scripts.db import sync_store


def main() -> None:
    parser = argparse.ArgumentParser(description="Scrape discounted products for one store.")
    parser.add_argument(
        "--store",
        required=True,
        help="Store directory name to scrape (lidl, mercator, tusdrogerija, spar)",
    )
    args = parser.parse_args()

    database_url = os.getenv("DATABASE_URL")
    written = sync_store(store=args.store, database_url=database_url)
    print(f"Upserted {written} products for {args.store}.")


if __name__ == "__main__":
    main()
