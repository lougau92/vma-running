#!/usr/bin/env python3
"""Preview or temporarily probe the club's Promenade verte episode 3 session."""

import argparse
import json
import math
from pathlib import Path

from garmin_auth import add_session_arguments, authenticated_session
from garmin_payload_probe import run_probe, step

GROUPS = {
    1: [(400, 90, 90), (400, 100, 100), (200, 110, 110), (1200, 80, 85)],
    2: [(400, 90, 90), (200, 100, 100), (1000, 80, 85)],
}


def build_club_workout(group, vma_kmh):
    if group not in GROUPS:
        raise ValueError("Choose group 1 or 2")
    if not math.isfinite(vma_kmh) or vma_kmh <= 0:
        raise ValueError("VMA must be a positive finite number in km/h")
    steps = []

    def append(kind="interval", condition="time", value=60, **extra):
        steps.append(step(len(steps) + 1, kind, condition, value, **extra))

    append("warmup", "lap.button", None,
           description="Échauffement sur la promenade verte. Appuyer sur LAP pour commencer la séance.")
    # Expand all three blocks explicitly, avoiding an unverified skip-last-rest
    # flag or an unintended rest after the third block.
    for block in range(3):
        for index, (distance, low, high) in enumerate(GROUPS[group]):
            percent = str(low) if low == high else f"{low}–{high}"
            append(condition="distance", value=distance,
                   description=f"Bloc {block + 1}/3 : {distance} m à {percent}% VMA.",
                   targetType={"workoutTargetTypeId": 6, "workoutTargetTypeKey": "pace.zone"},
                   targetValueOne=vma_kmh * high / 100 / 3.6,
                   targetValueTwo=vma_kmh * low / 100 / 3.6)
            if index < len(GROUPS[group]) - 1:
                append("recovery", value=60,
                       description="Pause active : 1 minute (200 m indicatifs). Fin après 1 minute.")
        if block < 2:
            append("rest", value=120, description="Pause sèche : 2 minutes entre les blocs.")
    append("cooldown", "lap.button", None,
           description="Retour au calme : 2 tours tous ensemble. Appuyer sur LAP après les 2 tours.")
    sport = {"sportTypeId": 1, "sportTypeKey": "running"}
    return {
        "workoutName": f"Promenade verte E3 G{group}",
        "description": f"Stade Fallon. Objectif Promenade verte, épisode 3. Groupe {group}. VMA {vma_kmh:g} km/h. "
                       "Contenu annoncé : 40 min (indicatif, pas une limite). "
                       "Bien respecter les % de VMA très important. Les pourcentages uniques sont des cibles exactes, sans tolérance ajoutée.",
        "sportType": sport,
        "workoutSegments": [{"segmentOrder": 1, "sportType": sport.copy(), "workoutSteps": steps}],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vma", type=float, required=True, help="Runner VMA in km/h (required, never inferred)")
    parser.add_argument("--group", type=int, choices=(1, 2), action="append", help="Default: both groups")
    parser.add_argument("--live-probe", action="store_true", help="Temporarily create/read/FIT-export/delete; never send to watch")
    parser.add_argument("--report", type=Path, default=Path(".tools/garmin-club-report.json"))
    parser.add_argument("--china", action="store_true")
    add_session_arguments(parser)
    args = parser.parse_args()
    if args.forget_session:
        parser.error("Use garmin_connection_test.py --forget-session")
    try:
        payloads = {f"group_{group}": build_club_workout(group, args.vma) for group in args.group or (1, 2)}
    except ValueError as error:
        parser.error(str(error))
    if not args.live_probe:
        print(json.dumps(payloads, indent=2, ensure_ascii=False))
        return 0
    report = {"vma_kmh": args.vma, "recovery_end": "time", "cases": {}}
    args.report.parent.mkdir(parents=True, exist_ok=True)

    def journal(record):
        report["cases"][record["case"]] = record
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")

    with authenticated_session(args) as client:
        for name, payload in payloads.items():
            record = run_probe(client, name, payload, journal)
            print(name, record["outcome"], "changed fields:", len(record.get("changes", [])), "cleanup:", record["cleanup"], flush=True)
            if record["outcome"] != "exported" or record["cleanup"] != "deleted" or record["changes"]:
                return 1
    print("Report:", args.report)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Cancelled. Check the report for pending cleanup.")
        raise SystemExit(130)
    except Exception as error:
        print(f"Club probe failed: {type(error).__name__} (private server details suppressed).")
        print("Check the report for pending cleanup before retrying.")
        raise SystemExit(1)
