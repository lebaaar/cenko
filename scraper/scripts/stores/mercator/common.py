
from __future__ import annotations

import json
import time
import uuid
from datetime import UTC, datetime
from typing import Any
from urllib.parse import urlencode
from urllib.request import Request, urlopen

BASE_URL = "https://mercatoronline.si/products/browseProducts/getProducts"
DISCOUNT_CODES = "1,2,3,4,5,6,10,11,15,16,18,100,103,109,113,114,115,126,104,105,106,112"
STORE_NAME = "mercator"
REQUEST_LIMIT = 100
MAX_PAGES = 300


def fetch_products(discounted_only: bool) -> list[dict[str, Any]]:
    all_products: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    seen_page_signatures: set[tuple[str, ...]] = set()
    from_index = 0

    for _ in range(MAX_PAGES):
        params: dict[str, Any] = {
            "limit": REQUEST_LIMIT,
            "offset": 0,
            "filterData[offset]": 0,
            "from": from_index,
            "_": int(time.time() * 1000),
        }
        if discounted_only:
            params["filterData[discounts]"] = DISCOUNT_CODES

        url = f"{BASE_URL}?{urlencode(params)}"
        req = Request(
            url,
            headers={
                "User-Agent": "Mozilla/5.0",
                "Accept": "application/json, text/plain, */*",
                "X-Requested-With": "XMLHttpRequest",
            },
        )

        with urlopen(req, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))

        page_products = _extract_product_list(payload)
        if not page_products:
            break

        page_identity = tuple(_product_identity(product) for product in page_products[:10])
        if page_identity in seen_page_signatures:
            break
        seen_page_signatures.add(page_identity)

        added = 0
        for product in page_products:
            pid = _product_identity(product)
            if pid in seen_ids:
                continue
            seen_ids.add(pid)
            all_products.append(product)
            added += 1

        if added == 0:
            break

        from_index += len(page_products)
        if len(page_products) < REQUEST_LIMIT:
            break

    return all_products


def normalize_product(raw: dict[str, Any], scraped_at: str) -> dict[str, Any]:
    data = raw.get("data") if isinstance(raw.get("data"), dict) else {}

    source_id = _first(data, ["cinv", "code", "codewz"]) or _first(
        raw, ["itemId", "id", "productId", "product_id", "sku", "code", "ean"]
    )
    name = _first(data, ["name"]) or _first(
        raw, ["name", "productName", "product_name", "title", "description", "short_name"]
    )
    name = name or ""

    original_price = _to_float(_first(data, ["normal_price"]))
    sale_price = _to_float(_first(data, ["current_price"]))

    if original_price == 0:
        original_price = _to_float(
            _first(raw, ["originalPrice", "priceRegular", "regularPrice", "oldPrice", "price_before"])
        )
    if sale_price == 0:
        sale_price = _to_float(
            _first(raw, ["salePrice", "discountPrice", "priceFinal", "currentPrice", "price"])
        )

    if original_price == 0 and sale_price > 0:
        original_price = sale_price

    discount_pct = _to_float(
        _first(raw, ["discountPct", "discountPercentage", "discount_percent", "discount"])
    )

    discounts = data.get("discounts") if isinstance(data.get("discounts"), list) else []
    if discounts:
        first_discount = discounts[0] if isinstance(discounts[0], dict) else {}
        if sale_price == 0:
            sale_price = _to_float(first_discount.get("discount_price"))
        if discount_pct == 0:
            discount_pct = abs(_to_float(first_discount.get("value")))

    if discount_pct == 0 and original_price > 0 and sale_price > 0 and original_price >= sale_price:
        discount_pct = round(((original_price - sale_price) / original_price) * 100, 2)

    valid_from_raw = _first(data, ["valid_from", "actionFrom", "dateFrom"])
    valid_until_raw = _first(data, ["valid_until", "actionTo", "dateTo", "offer_expires_on"])
    if discounts:
        first_discount = discounts[0] if isinstance(discounts[0], dict) else {}
        valid_from_raw = valid_from_raw or first_discount.get("valid_from")
        valid_until_raw = valid_until_raw or first_discount.get("valid_to")

    valid_from = _parse_timestamp(valid_from_raw) or scraped_at
    valid_until = _parse_timestamp(valid_until_raw) or scraped_at

    product_url = _normalize_mercator_url(_first(data, ["url"]) or _first(raw, ["url", "link", "product_url"]))
    image_url = _normalize_mercator_url(
        _first(data, ["mainImageSrc", "image", "image_url", "imageUrl"])
        or _first(raw, ["mainImageSrc", "image", "image_url", "imageUrl"])
    )
    uid_seed = f"{STORE_NAME}:{source_id or name}"
    generated_id = str(uuid.uuid5(uuid.NAMESPACE_URL, uid_seed))
    original_price_cents = _to_cents(original_price)
    sale_price_cents = _to_cents(sale_price)

    return {
        "product_id": generated_id,
        "store_name": STORE_NAME,
        "scraped_from_url": product_url,
        "product_name": str(name),
        "brand": _nullable_str(_first(data, ["brand_name"]) or _first(raw, ["brand", "brandName", "manufacturer"])),
        "image_url": image_url,
        "original_price": original_price_cents,
        "sale_price": sale_price_cents,
        "discount_pct": discount_pct,
        "valid_from": valid_from,
        "valid_until": valid_until,
        "scraped_at": scraped_at,
    }


def is_discounted(item: dict[str, Any]) -> bool:
    return item["discount_pct"] > 0 or item["sale_price"] < item["original_price"]


def now_iso() -> str:
    return datetime.now(UTC).isoformat()


def _extract_product_list(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return [x for x in payload if isinstance(x, dict)]

    if not isinstance(payload, dict):
        return []

    direct = payload.get("products")
    if isinstance(direct, list):
        return [x for x in direct if isinstance(x, dict)]

    data = payload.get("data")
    if isinstance(data, dict):
        data_products = data.get("products")
        if isinstance(data_products, list):
            return [x for x in data_products if isinstance(x, dict)]

    return []


def _product_identity(product: dict[str, Any]) -> str:
    data = product.get("data") if isinstance(product.get("data"), dict) else {}
    return str(
        _first(data, ["cinv", "code", "codewz"])
        or _first(product, ["itemId", "id", "productId", "product_id", "sku"])
        or json.dumps(product, sort_keys=True, ensure_ascii=False)
    )


def _first(data: dict[str, Any], keys: list[str]) -> Any:
    for key in keys:
        if key in data and data[key] not in (None, ""):
            return data[key]
    return None


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


def _to_cents(value: float) -> int:
    return int(round(value * 100))


def _nullable_str(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


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

    iso_candidate = text.replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(iso_candidate)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=UTC)
        return dt.astimezone(UTC).isoformat()
    except ValueError:
        pass

    formats = [
        "%Y%m%d%H%M%S",
        "%Y-%m-%d",
        "%Y-%m-%d %H:%M:%S",
        "%d.%m.%Y",
        "%d.%m.%Y %H:%M",
        "%d.%m.%Y %H:%M:%S",
    ]
    for fmt in formats:
        try:
            dt = datetime.strptime(text, fmt).replace(tzinfo=UTC)
            return dt.isoformat()
        except ValueError:
            continue

    return None


def _normalize_mercator_url(value: Any) -> str | None:
    text = _nullable_str(value)
    if not text:
        return None
    if text.startswith("http://") or text.startswith("https://"):
        return text
    if text.startswith("/"):
        return f"https://mercatoronline.si{text}"
    return f"https://mercatoronline.si/{text}"
