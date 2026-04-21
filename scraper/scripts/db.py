from __future__ import annotations

import os
from pathlib import Path
from typing import Iterable

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import credentials, firestore

FIRESTORE_BATCH_LIMIT = 500


def _load_env() -> None:
    env_path = Path(__file__).with_name(".env")
    load_dotenv(env_path)


def _resolve_key_path(path_value: str) -> Path:
    key_path = Path(path_value).expanduser()
    if not key_path.is_absolute():
        key_path = (Path(__file__).with_name(".env").parent / key_path).resolve()
    return key_path


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
    """
    Upsert products into Firestore by `product_id` in 500-write batches.
    Returns number of written documents.
    """
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
