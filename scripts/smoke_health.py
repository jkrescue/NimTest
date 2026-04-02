#!/usr/bin/env python3
"""Poll GET /v1/health/ready until status is ready or timeout."""
from __future__ import annotations

import argparse
import sys
import time

import httpx


def main() -> int:
    p = argparse.ArgumentParser(description="Wait for DoMINO NIM /v1/health/ready")
    p.add_argument("--url", default="http://127.0.0.1:8000", help="NIM base URL (no trailing path)")
    p.add_argument("--timeout", type=float, default=600.0, help="Total seconds to wait")
    p.add_argument("--interval", type=float, default=5.0, help="Seconds between attempts")
    args = p.parse_args()

    base = args.url.rstrip("/")
    url = f"{base}/v1/health/ready"
    deadline = time.time() + args.timeout

    while time.time() < deadline:
        try:
            r = httpx.get(url, timeout=30.0)
            if r.status_code == 200:
                try:
                    j = r.json()
                except Exception:
                    j = {}
                if j.get("status") == "ready":
                    print("NIM is healthy:", j)
                    return 0
            print(f"... HTTP {r.status_code} body[:200]={r.text[:200]!r}")
        except Exception as e:
            print(f"... retry: {e}")
        time.sleep(args.interval)

    print("Timeout: NIM did not become ready.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
