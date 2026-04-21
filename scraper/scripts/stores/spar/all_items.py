from __future__ import annotations

import json

from discount_items import fetch_products, normalize_product, now_iso


def main() -> None:
    scraped_at = now_iso()
    raw_products = fetch_products(only_promos=False)
    normalized = [normalize_product(item, scraped_at) for item in raw_products]
    print(json.dumps(normalized, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
