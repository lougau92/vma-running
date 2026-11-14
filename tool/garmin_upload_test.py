#!/usr/bin/env python3
"""Create a three-minute running workout in Garmin Connect."""

import argparse
import sys

from garmin_auth import SessionStorageError, add_session_arguments, authenticated_session, forget_session
from garmin_delivery import send_workout


def positive_id(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("ID must be positive")
    return number


def build_workout() -> dict:
    """Build simple timed steps without pace targets for the first watch test."""
    steps = []
    for order, (kind, label) in enumerate(
        [(1, "warmup"), (3, "interval"), (2, "cooldown")], start=1
    ):
        steps.append({
            "type": "ExecutableStepDTO",
            "stepOrder": order,
            "stepType": {"stepTypeId": kind, "stepTypeKey": label},
            "endCondition": {"conditionTypeId": 2, "conditionTypeKey": "time"},
            "endConditionValue": 60.0,
            "targetType": {"workoutTargetTypeId": 1, "workoutTargetTypeKey": "no.target"},
        })
    sport = {"sportTypeId": 1, "sportTypeKey": "running"}
    return {
        "workoutName": "VMA Connection Test - 3 min",
        "description": "Connection test: 1 min warmup, 1 min easy run, 1 min cooldown. No pace targets.",
        "sportType": sport,
        "estimatedDurationInSecs": 180,
        "workoutSegments": [{
            "segmentOrder": 1,
            "sportType": sport,
            "workoutSteps": steps,
        }],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--china", action="store_true", help="Use Garmin China")
    parser.add_argument("--send-to-watch", action="store_true", help="Also request delivery to your registered running watch")
    parser.add_argument("--workout-id", type=positive_id, help="Send this existing workout instead of creating another")
    parser.add_argument("--device-id", type=positive_id, help="Select a registered running-capable device when several are available")
    parser.add_argument("--preview", action="store_true", help="Print workout JSON without login or upload")
    add_session_arguments(parser)
    args = parser.parse_args()
    if args.workout_id is not None:
        args.send_to_watch = True
    if args.device_id is not None and not args.send_to_watch:
        parser.error("--device-id requires --send-to-watch or --workout-id")
    if args.preview:
        import json
        print(json.dumps(build_workout(), indent=2))
        return 0
    if not sys.stdin.isatty():
        print("Run this in your own interactive terminal to enter credentials.")
        return 2

    if args.forget_session:
        try:
            forget_session(args)
            return 0
        except SessionStorageError as error:
            print(f"FAIL: {error}")
            return 1
        except Exception as error:
            print(f"FAIL: {type(error).__name__} (keyring/session details suppressed).")
            return 1
    if args.workout_id is not None:
        print(f"Sends existing workout {args.workout_id}; no new workout will be created.")
    else:
        print("Creates one workout: VMA Connection Test - 3 min")
        print("1 min warmup + 1 min easy running + 1 min cooldown; no pace targets.")
    if args.send_to_watch:
        print("Will request delivery to the selected device." if args.device_id else
              "Will select your registered running-capable watch for delivery.")
    prompt = "Send this existing workout? [y/N]: " if args.workout_id else "Create this workout in Garmin Connect? [y/N]: "
    if input(prompt).strip().lower() != "y":
        print("Cancelled.")
        return 0
    stage = "login"
    try:
        with authenticated_session(args) as client:
            print("PASS: Garmin Connect login succeeded.")
            workout_id = args.workout_id
            if workout_id is None:
                stage = "workout upload"
                result = client.upload_workout(build_workout())
                workout_id = result.get("workoutId")
                if not isinstance(workout_id, int) or isinstance(workout_id, bool):
                    print("Upload returned without a workout ID. Check Garmin Connect before rerunning.")
                    return 1
                print(f"PASS: Workout created. Workout ID: {workout_id}")
                print(f"To retry delivery without another upload: --workout-id {workout_id}")
            print(f"https://connect.garmin.com/modern/workout/{workout_id}")
            if args.send_to_watch:
                stage = "watch delivery request"
                send_workout(client, workout_id, args.device_id)
                print("PASS: Garmin accepted the delivery request. Sync your watch to download it.")
                print("Device receipt is unverified until you find the workout on your watch.")
            else:
                print("Open this workout in Garmin Connect, choose Send to Device, then sync your watch.")
            print("Delete the test workout from Garmin Connect when finished.")
        return 0
    except SessionStorageError as error:
        print(f"FAIL: {error}")
        return 1
    except Exception as error:
        print(f"FAIL during {stage}: {type(error).__name__} (server details suppressed).")
        from garmin_delivery import DeliveryError
        if isinstance(error, DeliveryError):
            print(f"Delivery step: {error}")
        if stage == "workout upload":
            print("Check Garmin Connect before retrying: the upload may have reached the server.")
        elif stage == "watch delivery request":
            print("The workout still exists. Use its link above to send it manually, then sync.")
        return 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyboardInterrupt, EOFError):
        print("\nCancelled. If upload had started, check Garmin Connect before retrying.")
        raise SystemExit(130)
