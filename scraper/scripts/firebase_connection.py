import os
from pathlib import Path

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import credentials, firestore


def _load_env() -> None:
    env_path = Path(__file__).with_name(".env")
    load_dotenv(env_path)


def get_firestore_client(service_account_path: str | None = None) -> firestore.Client:
    _load_env()

    key_path = (
        service_account_path
        or os.getenv("FIREBASE_SERVICE_ACCOUNT_KEY")
        or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    )

    if not key_path:
        raise ValueError(
            "Missing Firebase credentials path. Set FIREBASE_SERVICE_ACCOUNT_KEY "
            "or GOOGLE_APPLICATION_CREDENTIALS, or pass service_account_path."
        )

    if not firebase_admin._apps:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)

    return firestore.client()
