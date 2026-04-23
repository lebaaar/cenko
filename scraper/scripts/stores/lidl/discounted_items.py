from __future__ import annotations

import json
import os

from common import fetch_all_products, is_discounted, normalize_product, now_iso


def _read_category_ids() -> list[str] | None:
    raw = os.getenv("LIDL_CATEGORY_IDS", "").strip()
    if not raw:
        return None
    return [x.strip() for x in raw.split(",") if x.strip()]


def main() -> None:
    scraped_at = now_iso()

    category_ids = _read_category_ids()
    discover_categories = os.getenv("LIDL_DISCOVER_CATEGORIES", "true").strip().lower() != "false"
    raw_products = fetch_all_products(
        category_ids=category_ids,
        discover_categories=discover_categories,
        locale=os.getenv("LIDL_LOCALE", "sl_SI"),
        assortment=os.getenv("LIDL_ASSORTMENT", "SI"),
        version=os.getenv("LIDL_API_VERSION", "2.1.0"),
        fetch_size=int(os.getenv("LIDL_FETCHSIZE", "96")),
    )

    structured = [normalize_product(item, scraped_at) for item in raw_products]
    discounted_only = [item for item in structured if is_discounted(item)]
    print(json.dumps(discounted_only, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
