from __future__ import annotations

import json
import uuid
from datetime import UTC, datetime
from typing import Any
from urllib.request import Request, urlopen

URL = "https://deadpool.unified-jennet.instaleap.io/api/v3"
STORE_NAME = "spar"
HEADERS = {
    "Content-Type": "application/json",
    "dpl-api-key": "febe3691-edb4-498b-b1a6-d6fe1ddd068e",
    "apollographql-client-name": "e-commerce Moira Engine client",
    "apollographql-client-version": "0.18.581",
    "origin": "https://online.spar.si",
    "referer": "https://online.spar.si/",
    "user-agent": "Mozilla/5.0",
}
QUERY = """
query GetHome($getHomeInput: GetHomeInput!) {
  getHome(getHomeInput: $getHomeInput) {
    categories {
      products {
        name
        sku
        ean
        slug
        brand
        price
        previousPrice
        photosUrl
        promotion {
          startDateTime
          endDateTime
          conditions {
            price
          }
        }
        promotions {
          startDateTime
          endDateTime
          benefit {
            value
          }
        }
      }
    }
  }
}
"""


def fetch_products(only_promos: bool) -> list[dict[str, Any]]:
    payload = [
        {
            "operationName": "GetHome",
            "variables": {
                "getHomeInput": {
                    "storeReference": "81701",
                    "clientId": "SPAR_SLOVENIA",
                    "onlyPromos": only_promos,
                }
            },
            "query": QUERY,
        }
    ]

    req = Request(
        URL,
        data=json.dumps(payload).encode("utf-8"),
        headers=HEADERS,
        method="POST",
    )
    with urlopen(req, timeout=45) as response:
        raw = json.loads(response.read().decode("utf-8"))

    response_item = raw[0] if isinstance(raw, list) and raw else {}
    get_home = ((response_item.get("data") or {}).get("getHome") or {}) if isinstance(response_item, dict) else {}
    categories = get_home.get("categories") if isinstance(get_home, dict) else []

    products: list[dict[str, Any]] = []
    seen: set[str] = set()

    if not isinstance(categories, list):
        return products

    for category in categories:
        if not isinstance(category, dict):
            continue
        category_products = category.get("products")
        if not isinstance(category_products, list):
            continue
        for product in category_products:
            if not isinstance(product, dict):
                continue
            identity = str(product.get("sku") or product.get("slug") or product.get("name") or "")
            if not identity or identity in seen:
                continue
            seen.add(identity)
            products.append(product)

    return products


def normalize_product(raw: dict[str, Any], scraped_at: str) -> dict[str, Any]:
    name = str(raw.get("name") or "")
    source_id = raw.get("sku") or _first_list(raw.get("ean")) or raw.get("slug") or name

    original_price = _to_float(raw.get("previousPrice"))
    listed_price = _to_float(raw.get("price"))
    sale_price = _extract_sale_price(raw)

    if original_price == 0:
        original_price = listed_price
    if sale_price == 0:
        sale_price = listed_price
    if original_price == 0 and sale_price > 0:
        original_price = sale_price

    discount_pct = 0.0
    if original_price > 0 and sale_price > 0 and original_price >= sale_price:
        discount_pct = round(((original_price - sale_price) / original_price) * 100, 2)

    valid_from = _extract_datetime(raw, "start") or scraped_at
    valid_until = _extract_datetime(raw, "end") or scraped_at

    slug = _nullable_str(raw.get("slug"))
    scraped_from_url = f"https://online.spar.si/p/{slug}" if slug else None
    image_url = _first_list(raw.get("photosUrl"))

    uid_seed = f"{STORE_NAME}:{source_id}"
    product_id = str(uuid.uuid5(uuid.NAMESPACE_URL, uid_seed))
    original_price_cents = _to_cents(original_price)
    sale_price_cents = _to_cents(sale_price)

    return {
        "product_id": product_id,
        "store_name": STORE_NAME,
        "scraped_from_url": scraped_from_url,
        "product_name": name,
        "brand": _nullable_str(raw.get("brand")),
        "image_url": image_url,
        "original_price": original_price_cents,
        "sale_price": sale_price_cents,
        "discount_pct": discount_pct,
        "valid_from": valid_from,
        "valid_until": valid_until,
        "scraped_at": scraped_at,
    }


def now_iso() -> str:
    return datetime.now(UTC).isoformat()


def _extract_sale_price(raw: dict[str, Any]) -> float:
    promotion = raw.get("promotion")
    if isinstance(promotion, dict):
        conditions = promotion.get("conditions")
        if isinstance(conditions, list) and conditions and isinstance(conditions[0], dict):
            condition_price = _to_float(conditions[0].get("price"))
            if condition_price > 0:
                return condition_price

    promotions = raw.get("promotions")
    if isinstance(promotions, list) and promotions and isinstance(promotions[0], dict):
        benefit = promotions[0].get("benefit")
        if isinstance(benefit, dict):
            benefit_price = _to_float(benefit.get("value"))
            if benefit_price > 0:
                return benefit_price

    return 0.0


def _extract_datetime(raw: dict[str, Any], kind: str) -> str | None:
    if kind == "start":
        keys = ("startDateTime",)
    else:
        keys = ("endDateTime",)

    promotion = raw.get("promotion")
    if isinstance(promotion, dict):
        for key in keys:
            parsed = _parse_iso(promotion.get(key))
            if parsed:
                return parsed

    promotions = raw.get("promotions")
    if isinstance(promotions, list):
        for entry in promotions:
            if not isinstance(entry, dict):
                continue
            for key in keys:
                parsed = _parse_iso(entry.get(key))
                if parsed:
                    return parsed

    return None


def _parse_iso(value: Any) -> str | None:
    if value in (None, ""):
        return None
    text = str(value).strip().replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC).isoformat()


def _nullable_str(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _first_list(value: Any) -> str | None:
    if not isinstance(value, list) or not value:
        return None
    first = _nullable_str(value[0])
    if first and first.startswith("/"):
        return f"https://online.spar.si{first}"
    return first


def _to_float(value: Any) -> float:
    if value is None:
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace("€", "").replace("%", "").replace(" ", "")
    if "," in text and "." in text:
        text = text.replace(".", "").replace(",", ".")
    else:
        text = text.replace(",", ".")
    try:
        return float(text)
    except ValueError:
        return 0.0


def _to_cents(value: float) -> int:
    return int(round(value * 100))


def main() -> None:
    scraped_at = now_iso()
    raw_products = fetch_products(only_promos=True)
    normalized = [normalize_product(item, scraped_at) for item in raw_products]
    discounted = [x for x in normalized if x["discount_pct"] > 0 or x["sale_price"] < x["original_price"]]
    print(json.dumps(discounted, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
