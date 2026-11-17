#!/usr/bin/env python3
"""Read-only progression from a working Garmin request to CORS checks.

Uses the existing encrypted session. Prints header names and HTTP status only;
never exports tokens, response bodies, cookies or authenticated browser snippets.
Python does not enforce CORS: this is a diagnostic, not a real browser test.
"""

import argparse
from unittest.mock import patch
from urllib.parse import urlsplit

import requests

from garmin_auth import add_session_arguments, authenticated_session


def report(label, response):
    print(f"{label}: HTTP {response.status_code}")
    for name in (
        "Access-Control-Allow-Origin",
        "Access-Control-Allow-Methods",
        "Access-Control-Allow-Headers",
        "Access-Control-Allow-Credentials",
    ):
        print(f"  {name}: {response.headers.get(name, '(absent)')}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--origin", default="https://lougau92.github.io")
    parser.add_argument("--china", action="store_true")
    add_session_arguments(parser)
    args = parser.parse_args()
    origin = urlsplit(args.origin)
    if (origin.scheme not in ("http", "https") or not origin.netloc
            or origin.username or origin.password or origin.path
            or origin.query or origin.fragment):
        parser.error("--origin must be an HTTP(S) origin without a path or credentials")
    if args.forget_session:
        parser.error("Use garmin_connection_test.py --forget-session")

    print("Read-only HTTP diagnostics. No workout writes. No browser CORS enforcement.")
    with authenticated_session(args) as client:
        # Observe the actual transport response, not a guessed API URL.
        session = client.client._api_session
        original = session.request
        captured = []

        def observe(*request_args, **request_kwargs):
            response = original(*request_args, **request_kwargs)
            captured.append(response)
            return response

        with patch.object(session, "request", side_effect=observe):
            devices = client.get_devices()
        baseline = captured[-1]
        baseline.raise_for_status()
        request = baseline.request
        url = request.url
        parts = urlsplit(url)
        if parts.scheme != "https" or not parts.hostname.endswith(".garmin.com") or parts.query:
            raise RuntimeError("Unexpected endpoint; stopping before replay")
        print(f"Exact endpoint: {request.method} {url}")
        print("Original header names: " + ", ".join(sorted(request.headers)))
        print(f"Device lookup: {len(devices)} device(s)")
        report("1. Library baseline", baseline)

        authorization = request.headers.get("Authorization")
        if not authorization:
            print("No Authorization header: cookie-based authentication requires a separate browser strategy.")
            return 2
        headers = {"Authorization": authorization, "Accept": "application/json"}
        # Fresh sessions avoid silently carrying over Garmin cookies or headers.
        for label, extra in (
            ("2. Minimal authenticated GET", {}),
            ("3. Same GET with PWA Origin (Python still bypasses CORS)", {"Origin": args.origin}),
        ):
            with requests.Session() as isolated:
                response = isolated.get(url, headers={**headers, **extra}, timeout=15, allow_redirects=False)
                report(label, response)
                response.close()

        # A browser preflight itself contains no authentication credentials.
        with requests.Session() as isolated:
            response = isolated.options(url, headers={
                "Origin": args.origin,
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization",
            }, timeout=15, allow_redirects=False)
            report("4. Credential-free browser preflight", response)
            response.close()
    print("A real browser must additionally permit the preflight and the actual response.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Cancelled.")
        raise SystemExit(130)
    except Exception as error:
        print(f"FAIL: {type(error).__name__} (private details suppressed).")
        raise SystemExit(1)
