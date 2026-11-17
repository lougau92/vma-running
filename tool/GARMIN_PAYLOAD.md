# Garmin running workout payload: observed contract

Observed on 2026-11-12 with `garminconnect==0.3.20`. These are observations of
undocumented Garmin Connect endpoints, not a complete or guaranteed API schema.
The live dictionaries came from `get_workout_types()`.

We exercised **18 distinct cases**: 15 were created, read back, and exported as
CRC-checked FIT files; 3 were rejected on upload with HTTP 400. Every created
probe was deleted. An initial timed/distance smoke probe was also deleted.
Nothing from this suite was scheduled or sent to a watch. The original manual
connection-test workout was left untouched.

Evidence: [synthetic requests, stored fields, differences, and decoded FIT](fixtures/garmin_payload_observations.json).
The fixture excludes account/author metadata and created workout IDs.
Local journal files in `.tools/` retain IDs for interrupted-run cleanup.

## Verified fields and transformations

| Feature / field | Live observation | Guidance |
|---|---|---|
| Running sport | `sportTypeId: 1`, `sportTypeKey: "running"` preserved | Include at top level and in the segment. Removing the top-level sport returned 400 in this payload. |
| Timed step | `endCondition` ID 2 / `time`, value 60 becomes FIT `duration_time: 60.0` | JSON uses seconds. |
| Distance step | ID 3 / `distance`, value 200 becomes FIT `duration_distance: 200.0` | JSON uses meters. |
| Lap-button step | ID 1 / `lap.button`, with `endConditionValue` omitted | Exports as FIT `duration_type: open`. |
| Step intensity | IDs 1 warmup, 2 cooldown, 3 interval, 4 recovery, 5 rest | Each exported to its corresponding FIT intensity (`interval` becomes `active`). |
| No target | Target ID 1 / `no.target` | FIT target is `open`. |
| Pace range | Target ID 6 / `pace.zone`, `targetValueOne` / `targetValueTwo` | These are **speeds in meters/second**, not seconds/km. |
| Pace bound order | Both faster-first and slower-first were stored unchanged | FIT sorts the bounds. Use faster-first consistently, matching the web-designer convention; do not rely on sorting in every consumer. |
| Counted repeat | `RepeatGroupDTO`, ID 6 / `repeat`, condition ID 7 / `iterations`, `numberOfIterations: 2` | Children are nested JSON `workoutSteps`; FIT flattens them and adds a backward repeat instruction. |
| Repeat condition value | Omitting repeat `endConditionValue` still produced a two-iteration FIT repeat | `numberOfIterations` carries the count in the tested format. Keep both consistent when providing both. |
| Nested repeats | Two levels stored and exported | Both FIT repeat instructions pointed to the proper earlier steps. Watch execution remains untested. |
| Global step numbering | Distinct one-based orders across parents and children preserved | Always generate explicit, globally unique ascending orders. |
| Duplicate orders | Accepted, then renumbered by Garmin | Avoid relying on this repair. |
| Omitted orders | Accepted, but the repeat moved before the standalone interval | **Unsafe: omission changed workout sequence.** |
| HR range | Target ID 4 / `heart.rate.zone`, range 130–150 | FIT encoded 230–250: the standard FIT `workout_hr` BPM offset is 100, so this represents 130–150 BPM. |
| HR zone | Same target, `zoneNumber: 2`, no custom bounds | FIT exported `target_hr_zone: 2`; it uses the runner's configured zones. |
| Cadence | Target ID 3 / `cadence`, range 160–180 | Stored unchanged; FIT exported 80–90 in cadence fields. Record this conversion explicitly; total steps/min versus cycles/min display must be checked on the watch. |
| Secondary target | `secondaryTargetType` plus `secondaryTargetValueOne/Two` | Pace plus secondary cadence survived into FIT. Old-watch support remains unverified. |
| Unicode step description | `description: "Easy pace – récupération"` | Exported unchanged as FIT step `notes`. |
| Workout description | Text stored and exported as FIT `wkt_description` | Optional in the tested payload. |
| Duration estimate | `estimatedDurationInSecs` | Optional in the tested timed workout; when omitted Garmin derived 30 seconds. It does not define step duration. |
| Skip final recovery | Repeat `skipLastRestStep: true` | JSON preserved it; FIT repeat field 18 changed from 0 to 1. This decoder calls it `unknown_18`, so execution semantics remain provisional. |
| Arbitrary field | Synthetic `vmaProbeUnknown` on a step | Accepted upload, silently discarded during storage. Never infer support from HTTP success alone. |
| Time-based repeat | Running repeat with `time` condition, value 120, `numberOfIterations: null` | Rejected with HTTP 400. This does not establish whether another sport or shape supports it. |

The minimal-top-level case (sport, description and estimate omitted together)
was also rejected; separate probes isolated the top-level sport removal as a
failure while description and estimate removal succeeded.

For absolute pace, convert seconds/km to m/s with `1000 / secondsPerKm`.
The tested 4:30–5:00 min/km bounds were `3.7037037` and `3.3333333`; FIT exported
`custom_target_speed_low: 3.333` and `custom_target_speed_high: 3.704`.
For VMA in km/h, speed in m/s is `VMA * percent / 100 / 3.6`.
An exact target versus a tolerance range is a product decision, not an API unit.

The FIT heart-rate encoding offset is defined by
[Garmin's FIT profile](https://github.com/garmin/fit-python-sdk/blob/main/garmin_fit_sdk/profile.py).
The offset belongs to FIT encoding; send **130**, not 230, in the JSON for 130 BPM.

## Representative format

See the `repeat_distance_recovery` case in the fixture for the complete tested
payload: lap-button warmup, two repetitions of 200 meters with a pace range and
30 seconds recovery, then lap-button cooldown. Its core repeat is:

```json
{
  "type": "RepeatGroupDTO",
  "stepOrder": 2,
  "stepType": {"stepTypeId": 6, "stepTypeKey": "repeat"},
  "endCondition": {"conditionTypeId": 7, "conditionTypeKey": "iterations"},
  "numberOfIterations": 2,
  "endConditionValue": 2,
  "smartRepeat": false,
  "workoutSteps": [
    {
      "type": "ExecutableStepDTO",
      "stepOrder": 3,
      "stepType": {"stepTypeId": 3, "stepTypeKey": "interval"},
      "endCondition": {"conditionTypeId": 3, "conditionTypeKey": "distance"},
      "endConditionValue": 200,
      "targetType": {"workoutTargetTypeId": 6, "workoutTargetTypeKey": "pace.zone"},
      "targetValueOne": 3.7037037037037037,
      "targetValueTwo": 3.3333333333333335
    },
    {
      "type": "ExecutableStepDTO",
      "stepOrder": 4,
      "stepType": {"stepTypeId": 4, "stepTypeKey": "recovery"},
      "endCondition": {"conditionTypeId": 2, "conditionTypeKey": "time"},
      "endConditionValue": 30,
      "targetType": {"workoutTargetTypeId": 1, "workoutTargetTypeKey": "no.target"}
    }
  ]
}
```

## Running the probes

```sh
uv pip install --python .tools/garmin-venv/bin/python -r tool/garmin-requirements.txt
# Preview only; no login or network:
.tools/garmin-venv/bin/python tool/garmin_payload_probe.py
# Create, read, export, and delete the synthetic cases:
.tools/garmin-venv/bin/python tool/garmin_payload_probe.py --live
# Limit to a particular case:
.tools/garmin-venv/bin/python tool/garmin_payload_probe.py --live --case repeat_distance_recovery
# Offline regressions against the recorded observations and cleanup behavior:
.tools/garmin-venv/bin/python -m unittest discover -s tool -p 'test_garmin_*.py'
```

Each run writes `.tools/garmin-payload-report.json`, with an entry saved as soon
as a created workout ID is known, then updated after cleanup. Choose a different
`--report PATH` to preserve earlier runs. A process killed during upload can
leave a probe behind; locate its `VMA probe RUN_ID ...` name in Garmin Connect.
Do not blindly rerun after a network error. No automatic retries are added.

Remaining gaps: physical watch execution, cadence display, skip-final-recovery
behavior, secondary targets on older watches, step/name limits, other sports,
power targets, all condition types, and validation across firmware versions.
The dictionaries advertise options; they do not prove any particular device can
execute them. No boundaries or limits have been established by this suite.

## Real club example: Promenade verte, episode 3

`garmin_club_session.py` models both groups from the club's session at Stade
Fallon. Each includes three blocks, one-minute active recoveries (200 m shown as
a note), and two-minute rests only between blocks. The 80–85% VMA ranges are
preserved. Single percentages are exact targets without an invented tolerance.

Group 1 has 6,600 m of work and nine active recoveries; group 2 has 4,800 m and
six active recoveries. Both have two interblock rests. Warmup and cooldown end
with the lap button. Cooldown notes say two laps together; no lap length is
assumed. The stated 40-minute session duration is descriptive, not a timer that
cuts the training short.

All three blocks are expanded explicitly (25 steps for group 1, 19 for group 2),
so the last block has no extra rest and does not depend on skip-last-rest flags.
The current Dart training model has a single `vmaPercent`, so it cannot yet
represent an 80–85% range faithfully. These Python fixtures do not change the
app's training data or UI.

Preview with an **example** VMA of 16 km/h (replace with the runner's actual VMA):

```sh
.tools/garmin-venv/bin/python tool/garmin_club_session.py --vma 16 --group 1
```

Add `--live-probe` to create, read back, FIT-export, and delete the selected
session; this never sends it to a watch or retains it as a personal workout.
Without `--group`, both group variants are selected.

Live validation on 2026-11-12 at VMA **16 km/h**: both groups were stored with
zero requested-field changes and exported with 25 and 19 FIT steps respectively.
Every exported step's duration, distance, intensity, notes, and pace bounds was
checked against the requested session; single-value percentages exported as
equal lower/upper speed bounds. Both temporary workouts were deleted. Evidence:
[sanitized club observations](fixtures/garmin_club_observations.json).
Physical watch execution remains unverified for this session.
