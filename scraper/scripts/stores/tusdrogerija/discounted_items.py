from __future__ import annotations

import json
import os

from common import fetch_all_products, is_discounted, normalize_product, now_iso


def _read_category_slugs() -> list[str] | None:
    raw = os.getenv("TUSDROGERIJA_CATEGORY_SLUGS", "").strip()
    if not raw:
        return None
    return [x.strip() for x in raw.split(",") if x.strip()]


def main() -> None:
    scraped_at = now_iso()

    category_slugs = _read_category_slugs()
    discover_categories = os.getenv("TUSDROGERIJA_DISCOVER_CATEGORIES", "true").strip().lower() != "false"
    raw_products = fetch_all_products(
        category_slugs=category_slugs,
        discover_categories=discover_categories,
        order=os.getenv("TUSDROGERIJA_ORDER", "suggested"),
        limit=int(os.getenv("TUSDROGERIJA_LIMIT", "100")),
    )

    structured = [normalize_product(item, scraped_at) for item in raw_products]
    discounted_only = [item for item in structured if is_discounted(item)]
    print(json.dumps(discounted_only, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
