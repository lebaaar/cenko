import pdfplumber
import argparse
import asyncio
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
#import pdfplumber
#from pdf2image import convert_from_path
#import pytesseract
from klic_haiku import *
from firebase_connection import get_firestore_client


def _strip_json_fence(raw: str) -> str:
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        lines = cleaned.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        cleaned = "\n".join(lines).strip()
    # Extract just the JSON object, ignoring any trailing text/reasoning
    start = cleaned.find("{")
    if start != -1:
        depth = 0
        for i, ch in enumerate(cleaned[start:], start):
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return cleaned[start : i + 1]
    return cleaned


def _parse_iso8601(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def _to_cents(value) -> int:
    if value is None:
        return 0
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(round(value * 100))

    s = str(value).strip()
    if not s:
        return 0

    if "," in s or "." in s:
        return int(round(float(s.replace(",", ".")) * 100))

    return int(s)


def _as_utc_datetime(year: int, month: int, day: int):
    try:
        return datetime(year, month, day, tzinfo=timezone.utc)
    except ValueError:
        return None


def _infer_year_from_name(name: str) -> int:
    m = re.search(r"(20\d{2})", name)
    if m:
        return int(m.group(1))
    return datetime.now(timezone.utc).year


def _extract_dates_from_filename(file_name: str):
    name = file_name.lower()
    year_hint = _infer_year_from_name(name)

    # 2026-04-16
    m = re.search(r"(?<!\d)(20\d{2})[._-](\d{1,2})[._-](\d{1,2})(?!\d)", name)
    if m:
        start = _as_utc_datetime(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        return start, None

    # 15_4-30_4_2026, 15-4-30-4-2026
    m = re.search(
        r"(?<!\d)(\d{1,2})[._-](\d{1,2})[-_](\d{1,2})[._-](\d{1,2})[._-](20\d{2})(?!\d)",
        name,
    )
    if m:
        start = _as_utc_datetime(int(m.group(5)), int(m.group(2)), int(m.group(1)))
        end = _as_utc_datetime(int(m.group(5)), int(m.group(4)), int(m.group(3)))
        return start, end

    # 154-2842026  -> 15.4 - 28.4.2026
    m = re.search(r"(?<!\d)(\d{1,2})(\d{1,2})[-_](\d{1,2})(\d{1,2})(20\d{2})(?!\d)", name)
    if m:
        start = _as_utc_datetime(int(m.group(5)), int(m.group(2)), int(m.group(1)))
        end = _as_utc_datetime(int(m.group(5)), int(m.group(4)), int(m.group(3)))
        return start, end

    # 15_4-30_4 (no year in range, use year hint)
    m = re.search(r"(?<!\d)(\d{1,2})[._-](\d{1,2})[-_](\d{1,2})[._-](\d{1,2})(?!\d)", name)
    if m:
        start = _as_utc_datetime(year_hint, int(m.group(2)), int(m.group(1)))
        end = _as_utc_datetime(year_hint, int(m.group(4)), int(m.group(3)))
        return start, end

    # od-16-4 or od-9-4-07 -> from date only
    m = re.search(r"od[-_](\d{1,2})[-_](\d{1,2})(?:[-_]\d{1,2})?", name)
    if m:
        start = _as_utc_datetime(year_hint, int(m.group(2)), int(m.group(1)))
        return start, None

    return None, None


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("katalogi", help="lokacija do katalogov", type=str)
    args = parser.parse_args()

    path = Path(args.katalogi)
    db = get_firestore_client()

    print(f"[plumber] katalogi path: {path.absolute()}, exists: {path.exists()}")
    pdfs = list(path.rglob("*.pdf"))
    print(f"[plumber] found {len(pdfs)} PDFs")
    for f in pdfs:
        print(f"[plumber] processing: {f.name}")
        file_valid_from, file_valid_until = _extract_dates_from_filename(f.name)

        katalog_txt = { f.parent.name: "" }

        pdf = pdfplumber.open(f)
        for page in pdf.pages:
            katalog_txt[f.parent.name] += page.extract_text(layout=True) or ""

        text_len = len(katalog_txt[f.parent.name])
        print(f"[plumber] extracted {text_len} chars")
        if text_len > 50:
            llm_response = await asyncio.to_thread(llm_call, katalog_txt[f.parent.name])

            if not llm_response:
                continue

            try:
                payload = json.loads(_strip_json_fence(llm_response))
            except json.JSONDecodeError as err:
                print(
                    f"[plumber] invalid JSON for {f}: {err}. Skipping this catalog.",
                    file=sys.stderr,
                )
                continue

            items = payload.get("items", [])
            print(f"[plumber] LLM returned {len(items)} items")
            now = datetime.now(timezone.utc)

            for item in items:
                data = {
                    "store_name": item.get("store_name") or f.parent.name,
                    "product_name": item.get("product_name"),
                    "brand": item.get("brand"),
                    "original_price": _to_cents(item.get("original_price")),
                    "sale_price": _to_cents(item.get("sale_price")),
                    "discount_pct": int(item.get("discount_pct") or 0),
                    "valid_from": _parse_iso8601(item.get("valid_from")) or file_valid_from,
                    "valid_until": _parse_iso8601(item.get("valid_until")) or file_valid_until,
                    "scraped_at": _parse_iso8601(item.get("scraped_at")) or now,
                }
                _, doc_ref = db.collection("catalog_products").add(data)
                print(f"Inserted: /catalog_products/{doc_ref.id}")
            continue
        #print(f)
    
        #for i in range(1, len(pdf.pages) + 1):
        #    images = convert_from_path(f, first_page=i, last_page=i)
        #    katalog_txt[f.parent.name] += pytesseract.image_to_string(images[0], lang="slv")
        #    print("koncou stran:", i)


if __name__ == "__main__":
    asyncio.run(main())
