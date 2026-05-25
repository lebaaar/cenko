from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Iterable

import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

DISCOUNT_SCRIPT_PATHS = [
    Path("stores/lidl/discounted_items.py"),
    Path("stores/mercator/discounted_items.py"),
    Path("stores/tusdrogerija/discounted_items.py"),
    Path("stores/spar/discounted_items.py"),
]

# Maps CLI --store arg (directory name) → script path
STORE_SCRIPT_MAP: dict[str, Path] = {
    "lidl": Path("stores/lidl/discounted_items.py"),
    "mercator": Path("stores/mercator/discounted_items.py"),
    "tusdrogerija": Path("stores/tusdrogerija/discounted_items.py"),
    "spar": Path("stores/spar/discounted_items.py"),
}

# Maps scraper STORE_NAME -> DB store_id (matches seeded store table)
STORE_ID_MAP: dict[str, int] = {
    "spar": 1,
    "tus": 2,
    "tus_drogerija": 3,
    "mercator": 4,
    "hofer": 5,
    "lidl": 6,
    "eurospin": 7,
}


def _load_env() -> None:
    env_path = Path(__file__).with_name(".env")
    load_dotenv(env_path)


def get_db_connection(database_url: str | None = None) -> psycopg2.extensions.connection:
    _load_env()
    url = database_url or os.getenv("DATABASE_URL")
    if not url:
        raise ValueError(
            "Missing DATABASE_URL. "
            "Set it as an env var or pass it directly. "
            "Find it in Supabase -> Project Settings -> Database -> Connection string (URI)."
        )
    return psycopg2.connect(url)


def upsert_products(
    conn: psycopg2.extensions.connection,
    products: Iterable[dict],
) -> int:
    """Delete stale rows for the scraped stores, then bulk-insert fresh data."""
    products_list = list(products)
    if not products_list:
        return 0

    store_ids = {_resolve_store_id(p["store_name"]) for p in products_list}

    rows = []
    for product in products_list:
        store_id = _resolve_store_id(product["store_name"])
        rows.append((
            store_id,
            str(product.get("product_name") or ""),
            int(product.get("sale_price") or 0),
            int(product.get("original_price") or 0),
            int(round(float(product.get("discount_pct") or 0))),
            product.get("image_url"),
            _parse_ts(product.get("valid_from")),
            _parse_ts(product.get("valid_until")),
            _parse_ts(product.get("scraped_at")),
        ))

    with conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM product WHERE store_id = ANY(%s)", (list(store_ids),))
            psycopg2.extras.execute_values(
                cur,
                """
                INSERT INTO product
                  (store_id, name, sale_price, original_price,
                   discount_pct, image_url, valid_from, valid_to, scraped_at)
                VALUES %s
                """,
                rows,
            )
    return len(rows)


def _resolve_store_id(store_name: str) -> int:
    key = (store_name or "").strip().lower()
    store_id = STORE_ID_MAP.get(key)
    if store_id is None:
        raise ValueError(
            f"Unknown store_name {store_name!r}. "
            f"Known stores: {list(STORE_ID_MAP)}"
        )
    return store_id


def _parse_ts(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value.strip():
        return None
    text = value.strip().replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def _log_event(event: str, **fields: Any) -> None:
    payload = {"event": event, **fields}
    print(json.dumps(payload, ensure_ascii=False), file=sys.stderr)


def load_discounted_products(
    scripts_root: Path | None = None,
    script_paths: Iterable[Path] = DISCOUNT_SCRIPT_PATHS,
) -> list[dict[str, Any]]:
    root = scripts_root or Path(__file__).resolve().parent
    all_products: list[dict[str, Any]] = []

    for relative_script_path in script_paths:
        script_path = (root / relative_script_path).resolve()
        store_name = str(relative_script_path.parent.name)
        started_at = time.monotonic()
        _log_event("store_scrape_started", store=store_name, script=str(script_path))
        try:
            result = subprocess.run(
                [sys.executable, str(script_path)],
                cwd=str(script_path.parent),
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError as exc:
            _log_event(
                "store_scrape_failed",
                store=store_name,
                script=str(script_path),
                exit_code=exc.returncode,
                duration_seconds=round(time.monotonic() - started_at, 3),
                stdout=exc.stdout,
                stderr=exc.stderr,
            )
            continue

        parsed = json.loads(result.stdout)
        if not isinstance(parsed, list):
            raise ValueError(
                f"Expected a list of products from {script_path}, got: {type(parsed).__name__}"
            )

        store_products = [item for item in parsed if isinstance(item, dict)]
        _log_event(
            "store_scrape_succeeded",
            store=store_name,
            script=str(script_path),
            product_count=len(store_products),
            duration_seconds=round(time.monotonic() - started_at, 3),
        )
        all_products.extend(store_products)

    return all_products


def dedupe_products_per_store(products: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    unique: dict[tuple[str, str], dict[str, Any]] = {}
    for product in products:
        store_name = str(product.get("store_name") or "").strip()
        product_id = str(product.get("product_id") or "").strip()
        if not store_name or not product_id:
            raise ValueError(
                "Each product must include non-empty `store_name` and `product_id`."
            )
        unique[(store_name, product_id)] = product
    return list(unique.values())


def sync_store(store: str, database_url: str | None = None) -> int:
    """Scrape one store and upsert its products. Exits 1 on scrape failure."""
    script_relative = STORE_SCRIPT_MAP.get(store)
    if script_relative is None:
        raise ValueError(f"Unknown store {store!r}. Known: {list(STORE_SCRIPT_MAP)}")

    root = Path(__file__).resolve().parent
    script_path = (root / script_relative).resolve()

    started_at = time.monotonic()
    _log_event("store_scrape_started", store=store, script=str(script_path))

    try:
        result = subprocess.run(
            [sys.executable, str(script_path)],
            cwd=str(script_path.parent),
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        _log_event(
            "store_scrape_failed",
            store=store,
            script=str(script_path),
            exit_code=exc.returncode,
            duration_seconds=round(time.monotonic() - started_at, 3),
            stdout=exc.stdout,
            stderr=exc.stderr,
        )
        raise SystemExit(1) from exc

    parsed = json.loads(result.stdout)
    if not isinstance(parsed, list):
        raise ValueError(
            f"Expected a list from {script_path}, got: {type(parsed).__name__}"
        )

    products = [item for item in parsed if isinstance(item, dict)]
    _log_event(
        "store_scrape_succeeded",
        store=store,
        script=str(script_path),
        product_count=len(products),
        duration_seconds=round(time.monotonic() - started_at, 3),
    )

    conn = get_db_connection(database_url=database_url)
    try:
        unique = dedupe_products_per_store(products)
        return upsert_products(conn=conn, products=unique)
    finally:
        conn.close()


def sync_discounted_products(database_url: str | None = None) -> int:
    conn = get_db_connection(database_url=database_url)
    try:
        discounted_products = load_discounted_products()
        unique_products = dedupe_products_per_store(discounted_products)
        return upsert_products(conn=conn, products=unique_products)
    finally:
        conn.close()


def main() -> None:
    database_url = os.getenv("DATABASE_URL")
    written = sync_discounted_products(database_url=database_url)
    print(f"Upserted {written} discounted products into Supabase.")


if __name__ == "__main__":
    main()
