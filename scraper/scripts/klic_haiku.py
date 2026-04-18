import anthropic
from dotenv import load_dotenv
import os
import sys
import time

load_dotenv()

client = anthropic.Anthropic()

prompt = "ojla"
model = "claude-haiku-4-5-20251001"
max_attempts = int(os.getenv("ANTHROPIC_MAX_RETRIES", "3"))
base_delay_seconds = float(os.getenv("ANTHROPIC_RETRY_BASE_DELAY", "1.0"))

for attempt in range(1, max_attempts + 1):
    try:
        message = client.messages.create(
            model=model,
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}],
        )
        print(message.content[0].text)
        break
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
