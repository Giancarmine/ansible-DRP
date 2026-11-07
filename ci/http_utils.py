"""Small HTTP helpers shared by the repository's pin-verification scripts."""

from __future__ import annotations

import hashlib
import json
import sys
import time
import urllib.error
import urllib.request

TIMEOUT = 60
READ_SIZE = 1024 * 1024
RETRIES = 4
BACKOFF = 1.5
MAX_BACKOFF = 30
RETRY_STATUS = {429, 500, 502, 503, 504}


def request(url: str) -> urllib.request.Request:
    return urllib.request.Request(
        url,
        headers={"User-Agent": "ansible-DRP-pin-checker"},
    )


def _retry_delay(error: Exception, attempt: int) -> float:
    delay = min(BACKOFF * (2**attempt), MAX_BACKOFF)
    if isinstance(error, urllib.error.HTTPError):
        headers = getattr(error, "headers", None)
        retry_after = headers.get("Retry-After") if headers else None
        if retry_after and retry_after.isdigit():
            delay = min(max(delay, int(retry_after)), MAX_BACKOFF)
    return delay


def open_url(url: str):
    """Open a URL, retrying transient timeouts and 429/5xx responses."""
    last_error: Exception | None = None
    for attempt in range(RETRIES):
        try:
            return urllib.request.urlopen(request(url), timeout=TIMEOUT)
        except urllib.error.HTTPError as error:
            if error.code not in RETRY_STATUS or attempt == RETRIES - 1:
                raise
            last_error = error
        except (urllib.error.URLError, TimeoutError) as error:
            if attempt == RETRIES - 1:
                raise
            last_error = error

        assert last_error is not None
        delay = _retry_delay(last_error, attempt)
        print(
            f"retrying {url} after {last_error} in {delay:.1f}s "
            f"({attempt + 2}/{RETRIES})",
            file=sys.stderr,
        )
        time.sleep(delay)

    assert last_error is not None
    raise last_error


def fetch_text(url: str) -> str:
    with open_url(url) as response:
        return response.read().decode()


def fetch_hash(url: str) -> str:
    digest = hashlib.sha256()
    with open_url(url) as response:
        while chunk := response.read(READ_SIZE):
            digest.update(chunk)
    return digest.hexdigest()


def fetch_json(url: str):
    return json.loads(fetch_text(url))
