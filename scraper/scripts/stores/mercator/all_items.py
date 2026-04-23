from __future__ import annotations

import json

from common import fetch_products, normalize_product, now_iso


def main() -> None:
    scraped_at = now_iso()
    raw_items = fetch_products(discounted_only=False)
    structured = [normalize_product(item, scraped_at) for item in raw_items]
    print(json.dumps(structured, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
