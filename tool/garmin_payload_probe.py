#!/usr/bin/env python3
"""Probe synthetic workout payloads, read back JSON/FIT, then delete only probes."""

import argparse
from copy import deepcopy
from datetime import datetime, timezone
import io
import json
import math
from pathlib import Path
import uuid

from garmin_auth import add_session_arguments, authenticated_session

SPORT = {"sportTypeId": 1, "sportTypeKey": "running"}


def step(order, kind="interval", condition="time", value=30, **extra):
    kinds = {"warmup": 1, "cooldown": 2, "interval": 3, "recovery": 4, "rest": 5}
    conditions = {"lap.button": 1, "time": 2, "distance": 3}
    result = {
        "type": "ExecutableStepDTO", "stepOrder": order,
        "stepType": {"stepTypeId": kinds[kind], "stepTypeKey": kind},
        "endCondition": {"conditionTypeId": conditions[condition], "conditionTypeKey": condition},
        "targetType": {"workoutTargetTypeId": 1, "workoutTargetTypeKey": "no.target"},
    }
    if value is not None:
        result["endConditionValue"] = value
    result.update(extra)
    return result


def repeat(order, children, count=2, **extra):
    return {
        "type": "RepeatGroupDTO", "stepOrder": order,
        "stepType": {"stepTypeId": 6, "stepTypeKey": "repeat"},
        "endCondition": {"conditionTypeId": 7, "conditionTypeKey": "iterations"},
        "numberOfIterations": count, "endConditionValue": count,
        "smartRepeat": False, "workoutSteps": children, **extra,
    }


def workout(steps):
    return {"workoutName": "VMA payload probe", "description": "Synthetic API probe; not a training recommendation.",
            "sportType": deepcopy(SPORT), "estimatedDurationInSecs": 180,
            "workoutSegments": [{"segmentOrder": 1, "sportType": deepcopy(SPORT), "workoutSteps": steps}]}


def probes():
    pace = {"targetType": {"workoutTargetTypeId": 6, "workoutTargetTypeKey": "pace.zone"},
            "targetValueOne": 1000 / 270, "targetValueTwo": 1000 / 300}
    cases = {
        "timed_and_distance": workout([step(1, "warmup", value=60), step(2, condition="distance", value=200), step(3, "recovery", value=30), step(4, "rest", value=15), step(5, "cooldown", value=60)]),
        "lap_button": workout([step(1, "warmup", "lap.button", None), step(2), step(3, "cooldown", "lap.button", None)]),
        "pace_fast_first": workout([step(1, condition="distance", value=200, **pace)]),
        "pace_slow_first": workout([step(1, condition="distance", value=200, **{**pace, "targetValueOne": pace["targetValueTwo"], "targetValueTwo": pace["targetValueOne"]})]),
        "repeat_distance_recovery": workout([step(1, "warmup", "lap.button", None), repeat(2, [step(3, condition="distance", value=200, **pace), step(4, "recovery", value=30)]), step(5, "cooldown", "lap.button", None)]),
        "nested_repeats": workout([repeat(1, [repeat(2, [step(3), step(4, "recovery", value=15)]), step(5, "rest", value=30)])]),
        "heart_rate_and_cadence": workout([
            step(1, targetType={"workoutTargetTypeId": 4, "workoutTargetTypeKey": "heart.rate.zone"}, targetValueOne=130, targetValueTwo=150),
            step(2, targetType={"workoutTargetTypeId": 4, "workoutTargetTypeKey": "heart.rate.zone"}, zoneNumber=2),
            step(3, targetType={"workoutTargetTypeId": 3, "workoutTargetTypeKey": "cadence"}, targetValueOne=160, targetValueTwo=180)]),
        "secondary_target_and_notes": workout([step(1, description="Easy pace – récupération", **pace,
            secondaryTargetType={"workoutTargetTypeId": 3, "workoutTargetTypeKey": "cadence"}, secondaryTargetValueOne=160, secondaryTargetValueTwo=180)]),
        "skip_last_recovery": workout([repeat(1, [step(2), step(3, "recovery", value=15)], skipLastRestStep=True)]),
        "duplicate_orders": workout([step(1), repeat(2, [step(1), step(2, "recovery")])]),
        "omitted_estimate": workout([step(1)]),
        "unknown_field": workout([step(1, vmaProbeUnknown="should-not-be-relied-on")]),
    }
    del cases["omitted_estimate"]["estimatedDurationInSecs"]
    cases["omitted_orders"] = workout([step(1), repeat(2, [step(3), step(4, "recovery")])])

    def remove_orders(steps):
        for item in steps:
            item.pop("stepOrder", None)
            remove_orders(item.get("workoutSteps", []))
    remove_orders(cases["omitted_orders"]["workoutSegments"][0]["workoutSteps"])
    cases["repeat_without_condition_value"] = workout([repeat(1, [step(2), step(3, "recovery")])])
    del cases["repeat_without_condition_value"]["workoutSegments"][0]["workoutSteps"][0]["endConditionValue"]
    cases["time_based_repeat"] = workout([repeat(1, [step(2), step(3, "recovery", value=15)], count=None)])
    timed = cases["time_based_repeat"]["workoutSegments"][0]["workoutSteps"][0]
    timed["endCondition"] = {"conditionTypeId": 2, "conditionTypeKey": "time"}
    timed["endConditionValue"] = 120
    cases["minimal_top_level"] = workout([step(1)])
    for key in ("description", "estimatedDurationInSecs", "sportType"):
        del cases["minimal_top_level"][key]
    cases["omitted_description"] = workout([step(1)])
    del cases["omitted_description"]["description"]
    cases["omitted_sport"] = workout([step(1)])
    del cases["omitted_sport"]["sportType"]
    return cases


def differences(expected, actual, path=""):
    """Compare requested fields only; Garmin adds IDs and defaults of its own."""
    changes = []
    if isinstance(expected, dict) and isinstance(actual, dict):
        for key, value in expected.items():
            child = f"{path}.{key}" if path else key
            if key not in actual:
                changes.append({"path": child, "sent": value, "stored": "<missing>"})
            else:
                changes.extend(differences(value, actual[key], child))
    elif isinstance(expected, list) and isinstance(actual, list):
        if len(expected) != len(actual):
            changes.append({"path": path + ".length", "sent": len(expected), "stored": len(actual)})
        for index, (left, right) in enumerate(zip(expected, actual)):
            changes.extend(differences(left, right, f"{path}[{index}]"))
    elif isinstance(expected, (int, float)) and not isinstance(expected, bool) and isinstance(actual, (int, float)) and not isinstance(actual, bool):
        if not math.isclose(expected, actual, rel_tol=1e-6, abs_tol=1e-6):
            changes.append({"path": path, "sent": expected, "stored": actual})
    elif expected != actual:
        changes.append({"path": path, "sent": expected, "stored": actual})
    return changes


def fit_summary(content):
    import fitdecode
    with fitdecode.FitReader(io.BytesIO(content), check_crc=fitdecode.CrcCheck.RAISE) as reader:
        return [{"message": frame.name, "fields": {field.name: field.value for field in frame.fields}}
                for frame in reader if isinstance(frame, fitdecode.FitDataMessage) and frame.name in ("workout", "workout_step")]


def run_probe(client, name, payload, journal):
    record = {"case": name, "payload": payload, "cleanup": "not_created"}
    workout_id = None
    stage = "upload"
    try:
        created = client.upload_workout(payload)
        workout_id = created.get("workoutId")
        if not isinstance(workout_id, int) or isinstance(workout_id, bool) or workout_id <= 0:
            raise ValueError("Missing workout ID")
        record.update(workout_id=workout_id, cleanup="pending")
        # Persist immediately, so interrupted probes can be found for cleanup.
        journal(record)
        stage = "readback"
        stored = client.get_workout_by_id(workout_id)
        record["changes"] = differences(payload, stored)
        # Whitelist synthetic training fields, excluding account/author metadata.
        record["stored"] = {key: stored.get(key) for key in ("workoutName", "description", "sportType", "estimatedDurationInSecs", "workoutSegments")}
        # Step structures can contain owner metadata in future API versions:
        # keep only the keys we understand, recursively.
        record["stored"] = sanitize(record["stored"])
        stage = "FIT export"
        exported = client.download_workout(workout_id)
        record["fit"] = fit_summary(exported)
        record["outcome"] = "exported" if record["fit"] else "empty_fit"
    except Exception as error:
        record["outcome"] = "error"
        record["failure_stage"] = stage
        record["error_type"] = type(error).__name__
        record["http_status"] = getattr(getattr(error, "response", None), "status_code", None)
        # Never log raw server responses, headers, exceptions, or tokens.
    finally:
        if workout_id is not None:
            try:
                client.delete_workout(workout_id)
                record["cleanup"] = "deleted"
            except Exception as error:
                record["cleanup"] = "failed:" + type(error).__name__
        journal(record)
    return record


def sanitize(value):
    keys = {"workoutName", "description", "sportType", "estimatedDurationInSecs", "workoutSegments", "segmentOrder", "workoutSteps",
            "type", "stepOrder", "stepType", "endCondition", "endConditionValue", "targetType", "targetValueOne", "targetValueTwo", "zoneNumber",
            "secondaryTargetType", "secondaryTargetValueOne", "secondaryTargetValueTwo", "secondaryZoneNumber", "numberOfIterations", "smartRepeat", "skipLastRestStep",
            "sportTypeId", "sportTypeKey", "stepTypeId", "stepTypeKey", "conditionTypeId", "conditionTypeKey", "workoutTargetTypeId", "workoutTargetTypeKey", "displayOrder", "displayable"}
    if isinstance(value, list):
        return [sanitize(item) for item in value]
    if isinstance(value, dict):
        return {key: sanitize(item) for key, item in value.items() if key in keys}
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true", help="Create/read/export/delete synthetic probe workouts")
    parser.add_argument("--china", action="store_true")
    parser.add_argument("--case", choices=list(probes()), action="append")
    parser.add_argument("--report", type=Path, default=Path(".tools/garmin-payload-report.json"))
    add_session_arguments(parser)
    args = parser.parse_args()
    if args.forget_session:
        parser.error("Use garmin_connection_test.py --forget-session")
    selected = {key: value for key, value in probes().items() if not args.case or key in args.case}
    if not args.live:
        print(json.dumps(selected, indent=2, ensure_ascii=False))
        return 0
    run_id = uuid.uuid4().hex[:8]
    report = {"date": datetime.now(timezone.utc).isoformat(), "run": run_id, "cases": {}}
    args.report.parent.mkdir(parents=True, exist_ok=True)

    def journal(record):
        report["cases"][record["case"]] = record
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")

    with authenticated_session(args) as client:
        report["dictionaries"] = client.get_workout_types()
        for name, payload in selected.items():
            payload["workoutName"] = f"VMA probe {run_id} {name}"
            record = run_probe(client, name, payload, journal)
            print(name, record["outcome"], "changed fields:", len(record.get("changes", [])), "cleanup:", record["cleanup"], flush=True)
            if record.get("http_status") in (401, 403, 429) or record["cleanup"].startswith("failed"):
                print("Stopping probes after access/rate-limit or cleanup failure.")
                return 1
            if record["outcome"] == "error" and not (
                name in ("time_based_repeat", "minimal_top_level", "omitted_sport")
                and record.get("failure_stage") == "upload" and record.get("http_status") == 400
            ):
                print("Stopping after an unexpected failure; inspect the report before retrying.")
                return 1
    print("Report:", args.report)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Cancelled. Check the report for pending cleanup before running again.")
        raise SystemExit(130)
    except Exception as error:
        print(f"Probe runner failed: {type(error).__name__} (private server details suppressed).")
        print("Check the report for pending cleanup before running again.")
        raise SystemExit(1)
