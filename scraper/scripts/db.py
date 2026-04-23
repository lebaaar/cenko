from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Iterable

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import credentials, firestore

FIRESTORE_BATCH_LIMIT = 500
DISCOUNT_SCRIPT_PATHS = [
    Path("stores/lidl/discounted_items.py"),
    Path("stores/mercator/discounted_items.py"),
    Path("stores/tusdrogerija/discounted_items.py"),
    Path("stores/spar/discounted_items.py"),
]


def _load_env() -> None:
    env_path = Path(__file__).with_name(".env")
    load_dotenv(env_path)


def _resolve_key_path(path_value: str) -> Path:
    key_path = Path(path_value).expanduser()
    if key_path.is_absolute():
        return key_path

    cwd_candidate = (Path.cwd() / key_path).resolve()
    if cwd_candidate.is_file():
        return cwd_candidate

    return (Path(__file__).resolve().parent / key_path).resolve()


def get_firestore_client(service_account_path: str | None = None) -> firestore.Client:
    _load_env()

    key_path_value = (
        service_account_path
        or os.getenv("FIREBASE_SERVICE_ACCOUNT_KEY")
        or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    )

    if not key_path_value:
        raise ValueError(
            "Missing Firebase credentials path. Set FIREBASE_SERVICE_ACCOUNT_KEY "
            "or GOOGLE_APPLICATION_CREDENTIALS, or pass service_account_path."
        )

    key_path = _resolve_key_path(key_path_value)
    if not key_path.is_file():
        raise FileNotFoundError(f"Firebase service account JSON not found at: {key_path}")

    if not firebase_admin._apps:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)

    return firestore.client()


def upsert_products(
    db: firestore.Client,
    products: Iterable[dict],
    collection_name: str = "products",
) -> int:
    written = 0
    batch = db.batch()
    ops_in_batch = 0

    for product in products:
        product_id = product.get("product_id")
        if not product_id:
            raise ValueError("Each product must contain a non-empty `product_id`.")

        doc_ref = db.collection(collection_name).document(str(product_id))
        batch.set(doc_ref, product, merge=True)
        ops_in_batch += 1

        if ops_in_batch >= FIRESTORE_BATCH_LIMIT:
            batch.commit()
            written += ops_in_batch
            batch = db.batch()
            ops_in_batch = 0

    if ops_in_batch > 0:
        batch.commit()
        written += ops_in_batch

    return written


def load_discounted_products(
    scripts_root: Path | None = None,
    script_paths: Iterable[Path] = DISCOUNT_SCRIPT_PATHS,
) -> list[dict[str, Any]]:
    root = scripts_root or Path(__file__).resolve().parent
    all_products: list[dict[str, Any]] = []

    for relative_script_path in script_paths:
        script_path = (root / relative_script_path).resolve()
        result = subprocess.run(
            [sys.executable, str(script_path)],
            cwd=str(script_path.parent),
            capture_output=True,
            text=True,
            check=True,
        )
        parsed = json.loads(result.stdout)
        if not isinstance(parsed, list):
            raise ValueError(f"Expected a list of products from {script_path}, got: {type(parsed).__name__}")

        store_products = [item for item in parsed if isinstance(item, dict)]
        store_name = str(relative_script_path.parent.name)
        print(f"Found {len(store_products)} discounted products for {store_name}.")
        all_products.extend(store_products)

    return all_products


def dedupe_products_per_store(products: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    unique: dict[tuple[str, str], dict[str, Any]] = {}
    for product in products:
        store_name = str(product.get("store_name") or "").strip()
        product_id = str(product.get("product_id") or "").strip()
        if not store_name or not product_id:
            raise ValueError("Each product must include non-empty `store_name` and `product_id`.")

        unique[(store_name, product_id)] = product

    return list(unique.values())


def sync_discounted_products(
    service_account_path: str | None = None,
    collection_name: str = "products",
) -> int:
    db = get_firestore_client(service_account_path=service_account_path)
    discounted_products = load_discounted_products()
    unique_discounted_products = dedupe_products_per_store(discounted_products)
    return upsert_products(db=db, products=unique_discounted_products, collection_name=collection_name)


def main() -> None:
    service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_KEY") or "serviceAccountKey.json"
    collection_name = os.getenv("FIRESTORE_COLLECTION", "products")
    written = sync_discounted_products(
        service_account_path=service_account_path,
        collection_name=collection_name,
    )
    print(f"Upserted {written} discounted products into Firestore collection '{collection_name}'.")


if __name__ == "__main__":
    main()
