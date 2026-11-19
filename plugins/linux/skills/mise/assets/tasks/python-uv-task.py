#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx>=0.27"]
# ///
# MISE description="One line that says what this task does"
# USAGE flag "--timeout <seconds>" help="Request timeout" default="30"
# USAGE arg "<url>" help="URL to fetch"
"""File task template in Python with inline dependencies (PEP 723).

Save as mise-tasks/<name>.py, run ``chmod +x`` on it, and declare ``uv`` in
``[tools]``. uv installs the dependencies into a cached environment on first
run. mise passes each #USAGE value as a ``usage_*`` environment variable.
"""

from __future__ import annotations

import os
import sys

import httpx


def main() -> int:
    """Fetch a URL and print its status line."""
    url = os.environ["usage_url"]  # noqa: SIM112 - mise sets lowercase usage_* names
    timeout = float(os.environ.get("usage_timeout", "30"))  # noqa: SIM112
    try:
        response = httpx.get(url, timeout=timeout, follow_redirects=True)
    except httpx.HTTPError as exc:
        print(f"request failed: {exc}", file=sys.stderr)
        return 1
    print(f"{response.status_code} {response.reason_phrase} {response.url}")
    return 0 if response.is_success else 1


if __name__ == "__main__":
    raise SystemExit(main())
