from __future__ import annotations

import json
import uuid
from datetime import UTC, datetime
from typing import Any
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen

STORE_NAME = "tus_drogerija"
SITE_ORIGIN = "https://www.tusdrogerija.si"
CATALOG_CATS_URL = f"{SITE_ORIGIN}/api/catalog/cats"
CATEGORY_PRODUCTS_URL = f"{SITE_ORIGIN}/api/catalog/{{slug}}/products"
DEFAULT_ORDER = "suggested"
DEFAULT_LIMIT = 100
MAX_PAGES_PER_CATEGORY = 500

HEADERS = {
    "Accept": "application/json",
    "User-Agent": "Mozilla/5.0",
}


def now_iso() -> str:
    return datetime.now(UTC).isoformat()


def discover_category_slugs() -> list[str]:
    payload = _fetch_json(CATALOG_CATS_URL)
    if not isinstance(payload, list):
        return []

    seen: set[str] = set()
    output: list[str] = []
    _collect_slugs(payload, seen, output)
    return output


def fetch_all_products(
    *,
    category_slugs: list[str] | None = None,
    discover_categories: bool = True,
    order: str = DEFAULT_ORDER,
    limit: int = DEFAULT_LIMIT,
) -> list[dict[str, Any]]:
    if category_slugs:
        slugs = [x.strip() for x in category_slugs if x and x.strip()]
    elif discover_categories:
        slugs = discover_category_slugs()
    else:
        slugs = []

    all_items: list[dict[str, Any]] = []
    seen_product_keys: set[str] = set()

    for slug in slugs:
        seen_page_signatures: set[tuple[str, ...]] = set()
        skip = 0

        for _ in range(MAX_PAGES_PER_CATEGORY):
            page_payload = _fetch_products_page(slug=slug, order=order, limit=limit, skip=skip)
            products = _extract_products(page_payload)
            if not products:
                break

            page_signature = tuple(_source_identity(item) for item in products[:10])
            if page_signature in seen_page_signatures:
                break
            seen_page_signatures.add(page_signature)

            added = 0
            for product in products:
                identity = _source_identity(product)
                if identity in seen_product_keys:
                    continue
                seen_product_keys.add(identity)
                all_items.append(product)
                added += 1

            if added == 0:
                break

            if len(products) < limit:
                break

            pagination_total = _extract_total(page_payload)
            skip += limit
            if pagination_total is not None and skip >= pagination_total:
                break

    return all_items


def normalize_product(raw: dict[str, Any], scraped_at: str) -> dict[str, Any]:
    ext_id = _nullable_str(raw.get("extId"))
    title = _nullable_str(raw.get("title")) or ""
    slug = _nullable_str(raw.get("slug"))

    price = raw.get("price") if isinstance(raw.get("price"), dict) else {}
    action_price = _to_float(price.get("actionWithVat") or price.get("action"))
    regular_price = _to_float(price.get("regularWithVat") or price.get("regular"))

    if regular_price == 0:
        regular_price = action_price
    if action_price == 0:
        action_price = regular_price

    discount_pct = _to_float(price.get("actionDiscount"))
    if discount_pct == 0 and regular_price > 0 and action_price > 0 and regular_price >= action_price:
        discount_pct = round(((regular_price - action_price) / regular_price) * 100, 2)

    action_details = price.get("actionDetails") if isinstance(price.get("actionDetails"), dict) else {}
    valid_from = _parse_iso(action_details.get("start")) or scraped_at
    valid_until = _parse_iso(action_details.get("end")) or scraped_at

    scraped_from_url = f"{SITE_ORIGIN}/izdelek/{slug}" if slug else None

    image = raw.get("mainImage") if isinstance(raw.get("mainImage"), dict) else {}
    image_url = _normalize_image_url(image.get("url"))

    uid_seed = f"{STORE_NAME}:{ext_id or slug or title}:{regular_price}:{action_price}"
    product_id = str(uuid.uuid5(uuid.NAMESPACE_URL, uid_seed))

    return {
        "product_id": product_id,
        "store_name": STORE_NAME,
        "scraped_from_url": scraped_from_url,
        "product_name": title,
        "brand": _extract_brand(raw),
        "image_url": image_url,
        "original_price": regular_price,
        "sale_price": action_price,
        "discount_pct": discount_pct,
        "valid_from": valid_from,
        "valid_until": valid_until,
        "scraped_at": scraped_at,
    }


def is_discounted(item: dict[str, Any]) -> bool:
    return item["discount_pct"] > 0 or item["sale_price"] < item["original_price"]


def _fetch_products_page(*, slug: str, order: str, limit: int, skip: int) -> dict[str, Any]:
    base_url = CATEGORY_PRODUCTS_URL.format(slug=quote(slug, safe=""))
    params = {
        "order": order,
        "limit": limit,
        "skip": skip,
    }
    return _fetch_json(f"{base_url}?{urlencode(params)}")


def _fetch_json(url: str) -> dict[str, Any] | list[Any]:
    req = Request(url, headers=HEADERS)
    with urlopen(req, timeout=45) as response:
        return json.loads(response.read().decode("utf-8"))


def _extract_products(payload: Any) -> list[dict[str, Any]]:
    if not isinstance(payload, dict):
        return []
    products = payload.get("products")
    if not isinstance(products, list):
        return []
    return [x for x in products if isinstance(x, dict)]


def _extract_total(payload: Any) -> int | None:
    if not isinstance(payload, dict):
        return None
    pagination = payload.get("pagination")
    if not isinstance(pagination, dict):
        return None
    total = pagination.get("total")
    if isinstance(total, int):
        return total
    if isinstance(total, str) and total.isdigit():
        return int(total)
    return None


def _collect_slugs(nodes: list[Any], seen: set[str], output: list[str]) -> None:
    for node in nodes:
        if not isinstance(node, dict):
            continue
        if node.get("active") is False or node.get("published") is False:
            continue

        slug = _nullable_str(node.get("slug"))
        if slug and slug not in seen:
            seen.add(slug)
            output.append(slug)

        children = node.get("children")
        if isinstance(children, list) and children:
            _collect_slugs(children, seen, output)


def _source_identity(item: dict[str, Any]) -> str:
    for key in ("extId", "id", "slug", "title"):
        value = item.get(key)
        if value not in (None, ""):
            return str(value)
    return json.dumps(item, sort_keys=True, ensure_ascii=False)


def _extract_brand(raw: dict[str, Any]) -> str | None:
    attributes = raw.get("attributes") if isinstance(raw.get("attributes"), dict) else {}
    for key in ("brand", "znamka", "Brand", "Blagovna znamka"):
        value = attributes.get(key)
        text = _nullable_str(value)
        if text:
            return text

    title = _nullable_str(raw.get("title")) or ""
    if " " in title:
        candidate = title.split(" ", 1)[0].strip()
        if candidate.isupper() and len(candidate) > 1:
            return candidate
    return None


def _normalize_image_url(value: Any) -> str | None:
    text = _nullable_str(value)
    if not text:
        return None

    text = text.replace("|width|", "800").replace("|height|", "800")
    if text.startswith("http://") or text.startswith("https://"):
        return text
    if text.startswith("/"):
        return f"{SITE_ORIGIN}{text}"
    return text


def _nullable_str(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


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
