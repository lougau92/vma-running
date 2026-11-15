# Workout structure — draft 0.1

The contract is [workout.schema.json](workout.schema.json); this document is
its detailed data-model reference. The operational agent instructions are
[`.agents/skills/convert-workout-email/SKILL.md`](../../.agents/skills/convert-workout-email/SKILL.md).
Use `$convert-workout-email` with an input email and output path. The skill can
also be read directly by a worker with no prior conversation context.
The existing `lib/training_plan.dart` still serves the app; these conversions
remain separate draft artifacts.

## Python model

[`tool/workout_model.py`](../../tool/workout_model.py) implements the contract
as frozen dataclasses using Python 3.10+ and the standard library. Python fields
use snake_case; JSON preserves the schema's names, including `schemaVersion`,
`sourceId`, and progression target `from` (Python `from_`). Nested nodes, targets
and end conditions deserialize into their concrete dataclass types.

```python
from pathlib import Path
from tool.workout_model import (
    WorkoutConversion, Repeat, Step, TimeEnd, PositiveBounds, Count,
)

plan = WorkoutConversion.from_json(
    Path("path/to/converted-workout.json").read_text()
)
json_text = plan.to_json()

interval = Repeat(
    count=Count(min=4, max=5),
    body=Step(
        role="effort",
        end=TimeEnd(seconds=PositiveBounds(min=60, max=60)),
    ),
)
```

Construction validates types, quantities, phase states, nonempty sequences,
choices, target limits and recovery-only `between` trees. JSON loading also
rejects unknown properties and explicit nulls. Optional fields use `None` in
Python and are omitted from JSON. Loading and saving preserve the plan's data;
formatting and object key order may change. Collection fields are ordinary
lists: frozen dataclasses prevent field reassignment, not list mutation.

These checks do not establish source completeness or approval. The broader
semantic review rules below (including workout IDs, issue paths
and unresolved source interpretations) still apply.

## Why the current model needs to change

The current model assumes a flat list of interval sets, one VMA percentage and
one recovery per set. Warmup and cooldown are strings. This cannot faithfully
represent `3 × (400 + recovery + 400 + recovery + 200 + recovery + 1200)`, a
range of repetitions, choices of workout, or structured preparation drills.

Recovery is part of the workout: its duration, placement, movement and
exceptions must survive conversion. A summary pointing to a similar email is not a complete conversion.

## Data types

The JSON is independent of Garmin and of any athlete's VMA. These types can
later become immutable Dart classes, with a sealed `WorkoutNode` hierarchy.

| Type | Responsibility |
| --- | --- |
| `WorkoutConversion` | Schema version, sources, extraction outcome, workouts, notes and review issues. |
| `Workout` | One session: title, sport, optional date/location, notes and versions. |
| `WorkoutVersion` | One group or named complete variation, with warmup, main and cooldown. |
| `Phase` | Whether the phase is specified, absent from the source, or explicitly omitted; its plan when specified. |
| `Step` | An effort, recovery or drill; its end condition, targets, movement and notes. |
| `Sequence` | Nodes performed once, in order. Also represents a named block or preparation section. |
| `Repeat` | A node repeated a fixed number or range of times, with optional recovery **between** iterations. |
| `Choice` | Two or more alternative plans; exactly one must be selected for execution. |
| `EndCondition` | Time, distance, laps, drill repetitions, manual end, a route/event, unknown, or an explicit combination. |
| `Target` | Numeric target, qualitative effort or a stated progression. |
| `Note` | Coaching instructions at the scope where they apply. |
| `ReviewIssue` | Missing, ambiguous, conflicting or inferred interpretation, pointing to the affected JSON paths. |

Only a workout has an `id`. Versions use labels, and nested elements are
identified by their position in the structure. Every node can have a `label`,
`notes` and `optional` flag. A note can belong to the whole workout, a version, a block,
a repeat, a choice or an individual step. Notes do not substitute for a
structured field when the source gives enough information to fill that field.
Keep notes that affect workout execution (route, meeting/start time, technique,
pacing, recovery or coordination). Omit club administration, changing rooms,
showers, bag storage, refreshments, contact details and signatures. The source
email retains that context; the workout is not a full email summary.

An envelope can contain several sessions if an email supplies several complete
workouts. `versions` has no assumed count: preserve Groupe 1 and Groupe 2 when
present, but do not invent Groupe 2 when only Groupe 1 is supplied. Identical
shared plans can be copied into two named versions when the email names both
groups. Each version is self-contained; shared warmup/cooldown are copied too.
Versions contain their complete plans, rather than inheritance or patches.

## Composition and recovery placement

The main distinction is between a repeated *step* and a repeated *sequence*:

```text
Workout
  Groupe 1
    Warmup: route/event on the promenade verte
    Main: repeat 3 times
      Body: sequence
        400 m @ 90% VMA
        60 s active recovery [note: 200 m]
        400 m @ 100% VMA
        60 s active recovery [note: 200 m]
        200 m @ 110% VMA
        60 s active recovery [note: 200 m]
        1200 m @ 80–85% VMA
      Between iterations: 120 s passive recovery
    Cooldown: 2 laps, together
  Groupe 2
    Its own complete warmup, main and cooldown
```

For review displays, present a repeat as one group: its body actions followed by
its recovery. Hide an anonymous body sequence's extra heading and indentation;
keep named groups, notes and budgets visible. Show “between repetitions” on a
between-only recovery rather than a separate structural heading. This display
simplification does not move the recovery into the body or add a final rest.
Use a step for one action; avoid redundant one-child sequences and quantity labels.

`Repeat(count=N, body=B, between=R)` expands to `B, R, B, …, R, B`.
For N iterations it contains N−1 recoveries. There is **no final recovery**
from `between`. To include recovery after every repetition, including the
last, put it inside the body sequence. To rest between two blocks, insert a
recovery step between those blocks in their parent sequence.
A recovery listed at the end of a repeated block stays inside the repeated body,
including its final iteration, unless the source restricts it or indicates a
replacement. A merely hypothetical alternative does not warrant a blocking
ambiguity issue.

For example, `4 × 300 m, R: 1 min walk/jog`, followed by `2 min pause sèche`,
can be represented as:

```text
Sequence
  Repeat 4
    Body: 300 m effort
    Between: 60 s recovery, active, walk or jog
  120 s recovery, passive
  Next block
```

Whether that section rest replaces or adds to the final short recovery is a
source interpretation. Record a blocking issue when the source leaves that
boundary genuinely unresolved.
The structure makes the proposed interpretation explicit, without hiding a
default in an exporter.

If recovery changes after the first eight efforts, split the repeat into named
sections and insert the correct boundary recovery explicitly. Preserve
“jogging allowed for the first eight; passive for the final four” in notes and
movement fields. If the same wording is attached to a nine-effort version,
record a conflict instead of silently adjusting the counts.

## Quantities, end conditions and intensity

Quantities use explicit units: seconds, meters, laps and repetitions. A numeric
prescription has `min` and `max`; equal values mean exact, for example
`{"min": 60, "max": 60}`. `4–5 repeats`, `60–90 seconds` and `80–85% VMA`
remain ranges. Do not choose a midpoint or lower bound during extraction.

End conditions are distinct from targets. A 400 m step ends after 400 m; its
VMA percentage describes the effort. A recovery can end by time or distance.
When a reviewer confirms that “1 min active (200 m)” means a timed recovery,
use a 60-second end condition and a 200 m note. That source-specific decision
does not automatically resolve other emails with similar wording.

| End kind | Meaning |
| --- | --- |
| `time` / `distance` | End after the prescribed seconds or meters. |
| `laps` | End after a lap count; lap length is optional and must be sourced or supplied at execution. |
| `repetitions` | Counted drill movements or exercises, distinct from repeating a plan node. |
| `manual` | Source explicitly calls for athlete/coach termination. |
| `event` | Qualitative endpoint, such as reaching the park or returning downhill. |
| `unknown` | End information is absent or unintelligible; retain source wording or describe what is missing. |
| `any_of` / `all_of` | Source explicitly states combined stop conditions; list them without inventing a priority. |

Missing duration is not zero and does not imply manual termination. Warmup
“on the promenade verte” can remain an event with the source wording, without
inventing a distance. Two cooldown laps remain two laps, without assuming
400 m per lap. “15 min + 3 gammes” is a sequence of a timed effort and a drill.
Its stated 20-minute preparation budget is stored as
`declaredDurationSeconds` on the sequence; it does not make the drills five
minutes long. Stated session budgets and calculated durations remain distinct.

Numeric target metrics include `vma_percent`, `speed_mps`,
`pace_seconds_per_km`, heart rate, power, cadence and `rpe_0_10`. Retain the
source metric. An athlete's VMA belongs in execution/export settings, so the
same plan remains usable by runners with different VMA values. Percent VMA is
a speed ratio: `speed = VMA × percentage / 100`; pace is its reciprocal.

Qualitative efforts such as easy, controlled/submaximal sprint or all out
remain qualitative. “90% of maximum intensity” does not become 90% VMA;
preserve it as effort text when the metric is unclear. A progression can carry
its start, end and scope (`within_step` or `across_iterations`), with
`distribution: unspecified` unless the source specifies how to progress.
An explicit sequence like 80%, 83%, 85% becomes three steps, not a range.

`movement.mode` is active, passive or unspecified. Optional `allowed` lists
the permitted movements, e.g. `["walk", "jog"]`. A bare recovery duration does not imply active or passive movement: omit
`movement` or use `mode: unspecified`, without raising a missing-data issue.
“Active” alone does not imply jogging. “Pause sèche” maps to passive without assuming a posture.
Preserve unusual instructions, such as passive recovery while returning down
a hill, and flag a conflict if necessary.

## Versions, choices and optional work

Use a version for a complete group/session variant. A named “Groupe 1 — version
allégée” can be a separate self-contained version when its changes are clear.
Use a choice when alternatives occur inside a session: a block of 8 × 500 m,
5 × 500 m for 20 km runners, **or** 2 × 1000 m for those runners. Each option
includes its own recovery and audience; options are not concatenated.

When choices in different blocks may be linked, preserve the choices and add a
blocking issue until the allowed combinations are understood. Do not generate
every combination as an approved version. If the source clearly pairs the
choices, create complete named versions instead.

An `optional: true` node represents an explicitly optional extra, such as two
additional 400 m efforts. Its inclusion must be decided before execution.
A repeat range expresses the coach's allowed count range; it does not by
itself mean the source is ambiguous. Both require an execution decision later.

## Uncertainty and validation

`status` describes the email extraction outcome: `workout`, `no_workout`, or
`unreadable`. `no_workout` has no workouts; it may retain a short contextual
note. `unreadable` means extraction failed and must have a blocking issue.
A workout can be structurally valid yet contain unresolved review issues.

Each issue has severity, code, explanation, JSON Pointer `paths` and affected locations in the plan. A reviewer resolution records what was decided and by whom;
update the affected plan at the same time.
A blocking issue without a resolution prevents publication as an approved
workout. Warnings remain visible but need not block approval.

Unknown fields, inferred recovery placement and contradictory group labels
must be visible. A conversion must contain the full session even when another
email looks identical. Source references support traceability, not shortcuts
such as “same as Tuesday”.

The JSON Schema checks shapes, enums, required fields and positive quantities.
Consumers also need these semantic checks before approval/execution:

- Workout IDs are unique per envelope. Issue paths resolve in the document
  and must be updated when elements are reordered.
- Every bound satisfies `min <= max`. RPE stays in 0–10 and percentages of
  maximum heart rate stay in 0–100; VMA percentages may exceed 100.
- `between` contains only recovery steps (or trees whose leaves are recovery
  steps). No recovery is added implicitly at any boundary.
- A repeat with maximum count 1 has no `between`. Progression across iterations
  belongs to a step inside a repeat. Conflicting targets for the same metric
  require a review issue rather than automatic merging.
- Each specified phase has a plan; `not_specified` and `explicitly_none` have
  none. Unspecified phases remain visible in review. An `unknown` end requires
  a blocking issue, and missing main content requires a blocking issue.
- Passive recovery cannot simultaneously allow only running/jogging/walking
  without a conflict issue. Recovery movement is never defaulted from a target.
- A source cross-check accounts for every effort, repeat, recovery, alternative,
  warmup, cooldown and coaching instruction. Schema validity cannot establish
  that extraction was complete or faithful.

Approval and execution readiness are separate. To execute or export, select a
version, choice options, repeat counts, optional extras and required range
values. Resolve unknown/event conditions or unsupported target types for the
destination. Supply athlete VMA and lap length when needed. Keep those
decisions in an execution record referencing the workout ID and JSON paths within this plan; do not
rewrite the coach's original prescription. A future execution-record contract
and Dart implementation are outside this draft.

Garmin is an export adapter: it receives a resolved executable plan, converts
supported units and targets, and reports unsupported instructions or device
limits. It must not silently discard drills, choices, route instructions or
recovery notes. An app display can support more of this structure than a watch.
