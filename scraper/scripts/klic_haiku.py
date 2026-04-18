import anthropic
from dotenv import load_dotenv
import os
import sys
import time

load_dotenv()

client = anthropic.Anthropic()

prompt = """You are extracting product and price data from a retail promotional catalog. The text was extracted from a PDF and may be heavily scrambled — product names, prices, and details may appear on separate lines, characters may be split across lines, and multiple products may be mixed together on the same line.

PRICE DECODING RULES:
- Standalone integers may represent prices in cents: 499 = 4.99, 1399 = 13.99
- Comma or period decimal notation is direct currency: "5,99" or "5.99" = 5.99
- Discount patterns like "47%   439" mean 47% off, sale price = 4.39
- Words like "redna cena", "regular price", "was", "RRP", "UVP", "PC" preceding a number = original/regular price
- Words like "CENEJE", "SALE", "AKCIJA", "ZNIŽANO", "NOW", "OFFER" indicate a discounted price
- A number followed by "%" on the same or next line is a discount percentage, NOT a price
- If a number appears immediately after a product name with no context, treat it as the sale price in cents

OUTPUT FORMAT — return only valid JSON, no markdown, no explanation:
{
  "items": [
    {
      "store_name": "infer from catalog text (e.g. SPAR, Lidl, Hofer); null if unknown",
      "product_name": "full product name",
      "brand": "brand name if identifiable, otherwise null",
      "original_price": 839,
      "sale_price": 439,
      "discount_pct": 47,
      "valid_from": "ISO 8601 — infer from catalog text (e.g. 'od srede 15. 4. 2026'); null if unknown",
      "valid_until": "ISO 8601 — infer from catalog text (e.g. 'do torka 21. 4. 2026'); null if unknown",
      "scraped_at": "ISO 8601 UTC timestamp — use current time"
    }
  ]
}

RULES:
- Extract every identifiable product that has at least one associated price
- Product names are usually in ALL CAPS or Title Case
- If there is no discount, set sale_price equal to original_price and discount_pct to 0
- original_price and sale_price must always be present as integers in cents (e.g. 499 for EUR 4.99) — never omit them
- brand should be extracted from the product name or nearby text (e.g. "Nestlé", "Kotanyi", "Pivovarna Union"); null if unclear
- store_name, valid_from, valid_until repeat on every item — infer once from the catalog text and copy to all rows
- Do not invent or guess prices — only extract what is explicitly in the text
- Ignore: legal disclaimers, coupon terms, slogans, URLs, page numbers, opening hours

CATALOG TEXT:
"""

model = "claude-haiku-4-5-20251001"
max_attempts = int(os.getenv("ANTHROPIC_MAX_RETRIES", "3"))
base_delay_seconds = float(os.getenv("ANTHROPIC_RETRY_BASE_DELAY", "1.0"))
max_output_tokens = int(os.getenv("ANTHROPIC_MAX_OUTPUT_TOKENS", "4096"))

def llm_call(text):

    for attempt in range(1, max_attempts + 1):
        try:
            message = client.messages.create(
                model=model,
                max_tokens=max_output_tokens,
                messages=[{"role": "user", "content": prompt+text}],
            )
            response_text = message.content[0].text
            print(response_text)
            return response_text
        except Exception as err:
            if attempt == max_attempts:
                print(
                    f"[klic_haiku] request failed after {attempt}/{max_attempts} attempts: {type(err).__name__}: {err}",
                    file=sys.stderr,
                )
                raise

            delay = base_delay_seconds * (2 ** (attempt - 1))
            print(
                f"[klic_haiku] attempt {attempt}/{max_attempts} failed: {type(err).__name__}: {err}. Retrying in {delay:.1f}s...",
                file=sys.stderr,
            )
            time.sleep(delay)
