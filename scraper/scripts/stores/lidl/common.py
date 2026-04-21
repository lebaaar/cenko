from __future__ import annotations

import json
import os
import uuid
from datetime import UTC, datetime
from typing import Any
from urllib.parse import urlencode
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

STORE_NAME = "lidl"
SITE_ORIGIN = "https://www.lidl.si"
SEARCH_URL = "https://www.lidl.si/q/api/search"
DEFAULT_FETCH_SIZE = 96
MAX_PAGES_PER_QUERY = 500
FALLBACK_CATEGORY_IDS = [
    "10068374",  # Hrana in pijača
    "10068166",  # Kuhinja in gospodinjstvo
    "10068222",  # Vse za dom in vrt
    "10068226",  # Šport in prosti čas
    "10068371",  # Pohištvo in dodatki
    "10068373",  # Moda in dodatki
    "10068225",  # Dojenčki, otroci in igrače
]

# Endpoint often requires this media type on some environments.
DEFAULT_HEADERS = {
    "Accept": "application/mindshift.search+json;version=2",
    "User-Agent": "Mozilla/5.0",
}


def now_iso() -> str:
    return datetime.now(UTC).isoformat()


def fetch_all_products(
    *,
    category_ids: list[str] | None = None,
    discover_categories: bool = True,
    locale: str = "sl_SI",
    assortment: str = "SI",
    version: str = "2.1.0",
    fetch_size: int = DEFAULT_FETCH_SIZE,
) -> list[dict[str, Any]]:
    """
    Fetches all products by paging `offset` until the endpoint stops returning items.

    If `category_ids` is provided, queries each category separately and deduplicates.
    Otherwise, it tries a single global query (without category filter).
    """
    queries: list[dict[str, str]] = []
    discovered_ids: list[str] = []
    if category_ids:
        queries = [{"category.id": category_id} for category_id in category_ids if category_id]
    elif discover_categories:
        discovered_ids = discover_category_ids(locale=locale, assortment=assortment, version=version)
        if discovered_ids:
            queries = [{"category.id": category_id} for category_id in discovered_ids]
        else:
            queries = [{}]
    else:
        queries = [{}]

    all_items: list[dict[str, Any]] = []
    seen_ids: set[str] = set()

    for query in queries:
        offset = 0
        seen_page_signatures: set[tuple[str, ...]] = set()

        for _ in range(MAX_PAGES_PER_QUERY):
            params: dict[str, Any] = {
                "fetchsize": fetch_size,
                "locale": locale,
                "assortment": assortment,
                "offset": offset,
                "version": version,
            }
            params.update(query)

            payload = _fetch_json(params)
            page_items = _extract_products(payload)
            if not page_items:
                break

            page_signature = tuple(_source_identity(item) for item in page_items[:12])
            if page_signature in seen_page_signatures:
                break
            seen_page_signatures.add(page_signature)

            added = 0
            for item in page_items:
                pid = _source_identity(item)
                if pid in seen_ids:
                    continue
                seen_ids.add(pid)
                all_items.append(item)
                added += 1

            if added == 0:
                break

            if len(page_items) < fetch_size:
                break
            offset += fetch_size

    return all_items


def discover_category_ids(
    *,
    locale: str = "sl_SI",
    assortment: str = "SI",
    version: str = "2.1.0",
) -> list[str]:
    """Extract category IDs from the `category` facet of a broad search call."""
    try:
        payload = _fetch_json(
            {
                "fetchsize": 24,
                "locale": locale,
                "assortment": assortment,
                "offset": 0,
                "version": version,
            }
        )
    except (HTTPError, URLError):
        return list(FALLBACK_CATEGORY_IDS)

    facets = payload.get("facets") if isinstance(payload, dict) else None
    if not isinstance(facets, list):
        return []

    category_facet = None
    for facet in facets:
        if isinstance(facet, dict) and str(facet.get("code")) == "category":
            category_facet = facet
            break
    if not isinstance(category_facet, dict):
        return []

    roots = category_facet.get("topvalues")
    if not isinstance(roots, list) or not roots:
        roots = category_facet.get("values")
    if not isinstance(roots, list):
        return list(FALLBACK_CATEGORY_IDS)

    seen: set[str] = set()
    output: list[str] = []
    _collect_category_values(roots, seen, output)
    return output or list(FALLBACK_CATEGORY_IDS)


def normalize_product(raw: dict[str, Any], scraped_at: str) -> dict[str, Any]:
    flat = _flatten_product(raw)

    source_id = _first(flat, [
        "product_id",
        "productId",
        "id",
        "erpNumber",
        "sku",
        "code",
        "ean",
    ])
    product_name = _first(flat, ["name", "title", "productName", "displayName", "keyfacts.title"]) or ""

    brand = _nullable_str(_first(flat, ["brand.name", "brand", "manufacturer"]))

    original_price = _to_float(
        _first(flat, [
            "price.oldPrice",
            "oldPrice",
            "previousPrice",
            "regularPrice",
            "originalPrice",
            "listPrice",
            "basePrice",
        ])
    )
    sale_price = _to_float(
        _first(flat, [
            "price.price",
            "currentPrice",
            "salePrice",
            "finalPrice",
            "discountPrice",
            "price",
        ])
    )

    if original_price == 0:
        original_price = sale_price
    if sale_price == 0:
        sale_price = original_price

    discount_pct = _to_float(_first(flat, ["discount_pct", "discountPercent", "discountPercentage", "discount"]))
    if discount_pct == 0 and original_price > 0 and sale_price > 0 and original_price >= sale_price:
        discount_pct = round(((original_price - sale_price) / original_price) * 100, 2)

    valid_from = _parse_timestamp(
        _first(flat, [
            "valid_from",
            "validFrom",
            "startDate",
            "promotionStart",
            "offerStart",
        ])
    ) or scraped_at
    valid_until = _parse_timestamp(
        _first(flat, [
            "valid_until",
            "validTo",
            "endDate",
            "promotionEnd",
            "offerEnd",
        ])
    ) or scraped_at

    scraped_from_url = _normalize_url(
        _first(flat, [
            "canonicalUrl",
            "canonicalPath",
            "url",
            "link",
            "productUrl",
            "href",
            "keyfacts.url",
            "gridbox.data.url",
        ])
    )
    image_url = _normalize_url(
        _first(flat, [
            "image",
            "imageUrl",
            "image_url",
            "mainImage",
            "mainImageUrl",
            "keyfacts.image",
            "media.mainImage.url",
        ])
    )

    uid_seed = f"{STORE_NAME}:{source_id or product_name}"
    product_id = str(uuid.uuid5(uuid.NAMESPACE_URL, uid_seed))

    return {
        "product_id": product_id,
        "store_name": STORE_NAME,
        "scraped_from_url": scraped_from_url,
        "product_name": str(product_name),
        "brand": brand,
        "image_url": image_url,
        "original_price": original_price,
        "sale_price": sale_price,
        "discount_pct": discount_pct,
        "valid_from": valid_from,
        "valid_until": valid_until,
        "scraped_at": scraped_at,
    }


def is_discounted(item: dict[str, Any]) -> bool:
    return item["discount_pct"] > 0 or item["sale_price"] < item["original_price"]


def _fetch_json(params: dict[str, Any]) -> dict[str, Any]:
    url = f"{SEARCH_URL}?{urlencode(params)}"
    headers = dict(DEFAULT_HEADERS)

    cookie = os.getenv("LIDL_COOKIE", "").strip()
    if cookie:
        headers["Cookie"] = cookie

    extra_headers = os.getenv("LIDL_EXTRA_HEADERS_JSON", "").strip()
    if extra_headers:
        try:
            parsed = json.loads(extra_headers)
            if isinstance(parsed, dict):
                for key, value in parsed.items():
                    if value is not None:
                        headers[str(key)] = str(value)
        except json.JSONDecodeError:
            pass

    req = Request(url, headers=headers)
    with urlopen(req, timeout=45) as response:
        return json.loads(response.read().decode("utf-8"))


def _extract_products(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return [x for x in payload if isinstance(x, dict)]

    if not isinstance(payload, dict):
        return []

    list_candidates: list[Any] = [
        payload.get("products"),
        payload.get("items"),
        payload.get("results"),
        payload.get("result"),
        payload.get("content"),
    ]

    data = payload.get("data")
    if isinstance(data, dict):
        list_candidates.extend([
            data.get("products"),
            data.get("items"),
            data.get("results"),
            data.get("content"),
        ])
    elif isinstance(data, list):
        list_candidates.append(data)

    for candidate in list_candidates:
        if isinstance(candidate, list):
            normalized = [x for x in candidate if isinstance(x, dict)]
            if normalized:
                return normalized

    return []


def _flatten_product(raw: dict[str, Any]) -> dict[str, Any]:
    flat = dict(raw)

    gridbox = raw.get("gridbox")
    if isinstance(gridbox, dict):
        data = gridbox.get("data")
        if isinstance(data, dict):
            for key, value in data.items():
                if key not in flat:
                    flat[key] = value
                flat[f"gridbox.data.{key}"] = value

    keyfacts = flat.get("keyfacts")
    if isinstance(keyfacts, dict):
        for key, value in keyfacts.items():
            flat[f"keyfacts.{key}"] = value

    brand = flat.get("brand")
    if isinstance(brand, dict):
        for key, value in brand.items():
            flat[f"brand.{key}"] = value

    price = flat.get("price")
    if isinstance(price, dict):
        for key, value in price.items():
            flat[f"price.{key}"] = value

    media = flat.get("media")
    if isinstance(media, dict):
        main_image = media.get("mainImage")
        if isinstance(main_image, dict):
            for key, value in main_image.items():
                flat[f"media.mainImage.{key}"] = value

    return flat


def _collect_category_values(nodes: list[Any], seen: set[str], output: list[str]) -> None:
    for node in nodes:
        if not isinstance(node, dict):
            continue
        value = _nullable_str(node.get("value"))
        if value and value not in seen:
            seen.add(value)
            output.append(value)
        children = node.get("children")
        if isinstance(children, list) and children:
            _collect_category_values(children, seen, output)


def _source_identity(item: dict[str, Any]) -> str:
    flat = _flatten_product(item)
    sid = _first(flat, [
        "product_id",
        "productId",
        "id",
        "erpNumber",
        "sku",
        "code",
        "ean",
        "url",
        "link",
    ])
    if sid:
        return str(sid)
    return json.dumps(item, sort_keys=True, ensure_ascii=False)


def _first(data: dict[str, Any], keys: list[str]) -> Any:
    for key in keys:
        if key in data and data[key] not in (None, ""):
            return data[key]
    return None


def _nullable_str(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _normalize_url(value: Any) -> str | None:
    text = _nullable_str(value)
    if not text:
        return None
    if text.startswith("http://") or text.startswith("https://"):
        return text
    if text.startswith("//"):
        return f"https:{text}"
    if text.startswith("/"):
        return f"{SITE_ORIGIN}{text}"
    return text


def _to_float(value: Any) -> float:
    if value is None:
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)

    text = str(value).strip().replace("€", "").replace("%", "")
    text = text.replace(" ", "")
    if "," in text and "." in text:
        text = text.replace(".", "").replace(",", ".")
    else:
        text = text.replace(",", ".")

    try:
        return float(text)
    except ValueError:
        return 0.0


def _parse_timestamp(value: Any) -> str | None:
    if value in (None, ""):
        return None

    if isinstance(value, (int, float)):
        ts = float(value)
        if ts > 1_000_000_000_000:
            ts = ts / 1000
        return datetime.fromtimestamp(ts, tz=UTC).isoformat()

    text = str(value).strip()
    if not text or text == "1970-01-01":
        return None

    text = text.replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(text)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=UTC)
        return dt.astimezone(UTC).isoformat()
    except ValueError:
        pass

    formats = [
        "%Y-%m-%d",
        "%Y-%m-%d %H:%M:%S",
        "%d.%m.%Y",
        "%d.%m.%Y %H:%M",
        "%d.%m.%Y %H:%M:%S",
    ]
    for fmt in formats:
        try:
            return datetime.strptime(text, fmt).replace(tzinfo=UTC).isoformat()
        except ValueError:
            continue

    return None
