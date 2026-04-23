
from __future__ import annotations

import json

from common import fetch_products, is_discounted, normalize_product, now_iso


def main() -> None:
    scraped_at = now_iso()
    raw_items = fetch_products(discounted_only=True)
    structured = [normalize_product(item, scraped_at) for item in raw_items]
    discounted_only = [item for item in structured if is_discounted(item)]
    print(json.dumps(discounted_only, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
