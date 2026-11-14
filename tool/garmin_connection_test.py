#!/usr/bin/env python3
"""Interactive, read-only Garmin Connect smoke test (Python 3.12+)."""

import argparse

from garmin_auth import SessionStorageError, add_session_arguments, authenticated_session, forget_session


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--china", action="store_true", help="Use Garmin China")
    add_session_arguments(parser)
    args = parser.parse_args()

    from garminconnect import (
        GarminConnectAuthenticationError,
        GarminConnectConnectionError,
        GarminConnectTooManyRequestsError,
    )

    stage = "login"
    try:
        if forget_session(args):
            return 0
        print("Read-only Garmin test: no workouts will be sent.")
        with authenticated_session(args) as client:
            print("PASS: Garmin Connect login succeeded.")
            stage = "device lookup"
            devices = client.get_devices()
        print(f"PASS: Device lookup succeeded ({len(devices)} device(s)).")
        for device in devices:
            name = str(device.get("displayName") or "Unnamed device")
            # Do not dump device IDs, serial numbers, or full API responses.
            print("  - " + "".join(c for c in name if c.isprintable())[:100])
        if not devices:
            print("No devices returned. Check the account's Garmin Connect pairing.")
        print("This verifies cloud access; watch sync and workout delivery are untested.")
        return 0
    except SessionStorageError as error:
        print(f"FAIL: {error}")
    except GarminConnectTooManyRequestsError:
        print(f"FAIL during {stage}: Garmin rate-limited the request. Wait before retrying.")
    except GarminConnectAuthenticationError:
        print(f"FAIL during {stage}: Authentication rejected. Check credentials/MFA in Garmin Connect.")
    except GarminConnectConnectionError:
        print(f"FAIL during {stage}: Connection failed or Garmin blocked the unofficial client.")
    except Exception as error:
        print(f"FAIL during {stage}: {type(error).__name__} (details suppressed to protect credentials).")
    return 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyboardInterrupt, EOFError):
        print("\nCancelled.")
        raise SystemExit(130)
