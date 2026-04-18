import os
from pathlib import Path

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import credentials, firestore


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
        raise FileNotFoundError(
            f"Firebase service account JSON not found at: {key_path}"
        )

    if not firebase_admin._apps:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)

    return firestore.client()
