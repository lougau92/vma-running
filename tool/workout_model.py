"""Typed workout contract 0.1 (Python 3.10+, standard library only).

JSON names match docs/workouts/workout.schema.json; Python uses snake_case.
Use WorkoutConversion.from_dict/from_json and to_dict/to_json at boundaries.
Structural validation runs on construction; unresolved review issues are retained.
"""
from __future__ import annotations

import json
import math
from dataclasses import dataclass, field, fields
from datetime import date, datetime
from types import UnionType
from typing import Any, Literal, TypeVar, Union, get_args, get_origin, get_type_hints

T = TypeVar("T", bound="JsonModel")


def _decode(value: Any, annotation: Any) -> Any:
    origin, args = get_origin(annotation), get_args(annotation)
    if origin in (Union, UnionType):
        for option in args:
            try:
                return _decode(value, option)
            except (ValueError, TypeError):
                pass
        raise ValueError(f"Value does not match {annotation}: {value!r}")
    if origin is Literal:
        if value not in args or type(value) is not type(args[0]):
            raise ValueError(f"Expected one of {args}, got {value!r}")
        return value
    if origin is list:
        if not isinstance(value, list):
            raise ValueError("Expected a list")
        return [_decode(item, args[0]) for item in value]
    if annotation is type(None):
        if value is not None:
            raise ValueError("Expected None")
        return None
    if isinstance(annotation, type) and issubclass(annotation, JsonModel):
        if isinstance(value, annotation):
            return value
        return annotation.from_dict(value)
    valid = (type(value) in (int, float) and math.isfinite(value)) if annotation is float else type(value) is annotation
    if not valid:
        raise ValueError(f"Expected {annotation}, got {value!r}")
    return value


def _encode(value: Any) -> Any:
    if isinstance(value, JsonModel):
        return value.to_dict()
    if isinstance(value, list):
        return [_encode(item) for item in value]
    return value


class JsonModel:
    """Strict JSON conversion; omitted optional fields use their Python defaults."""

    @classmethod
    def from_dict(cls: type[T], data: dict[str, Any]) -> T:
        if not isinstance(data, dict):
            raise ValueError(f"{cls.__name__}: expected an object")
        declared = {f.metadata.get("json", f.name): f for f in fields(cls)}
        unknown = data.keys() - declared.keys()
        if unknown:
            raise ValueError(f"{cls.__name__}: unknown fields {sorted(unknown)}")
        hints = get_type_hints(cls)
        values = {}
        for key, value in data.items():
            if value is None:
                raise ValueError(f"{cls.__name__}.{key}: JSON null is not allowed; omit the field")
            f = declared[key]
            try:
                values[f.name] = _decode(value, hints[f.name])
            except (ValueError, TypeError) as exc:
                raise ValueError(f"{cls.__name__}.{key}: {exc}") from exc
        try:
            return cls(**values)
        except TypeError as exc:
            raise ValueError(f"{cls.__name__}: {exc}") from exc

    @classmethod
    def from_json(cls: type[T], text: str) -> T:
        return cls.from_dict(json.loads(text))

    def to_dict(self) -> dict[str, Any]:
        return {f.metadata.get("json", f.name): _encode(getattr(self, f.name))
                for f in fields(self) if getattr(self, f.name) is not None}

    def to_json(self, *, indent: int | None = 2) -> str:
        return json.dumps(self.to_dict(), ensure_ascii=False, indent=indent, allow_nan=False)

    def __post_init__(self) -> None:
        hints = get_type_hints(type(self))
        for f in fields(self):
            value = getattr(self, f.name)
            decoded = _decode(value, hints[f.name])
            _require_typed(value, decoded)
            if isinstance(value, str) and not value and f.name != "paths":
                raise ValueError(f"{type(self).__name__}.{f.name} must not be empty")
        if isinstance(self, (PositiveBounds, ValueBounds, Count)):
            lower = 0 if isinstance(self, ValueBounds) else 1 if isinstance(self, Count) else 0
            if self.min > self.max or self.min < lower or (isinstance(self, PositiveBounds) and self.min == 0):
                raise ValueError("Invalid bounds: require ordered bounds in the allowed range")
        if isinstance(self, Phase) and ((self.status == "specified") != (self.plan is not None)):
            raise ValueError("Only a specified phase must have a plan")
        if isinstance(self, Sequence) and not self.children:
            raise ValueError("Sequence needs at least one child")
        if isinstance(self, Choice) and len(self.options) < 2:
            raise ValueError("Choice needs at least two options")
        if isinstance(self, (AnyOfEnd, AllOfEnd)) and len(self.conditions) < 2:
            raise ValueError("Combined end conditions need at least two conditions")
        if isinstance(self, LapsEnd) and self.lap_length_meters is not None and self.lap_length_meters <= 0:
            raise ValueError("Lap length must be positive")
        if isinstance(self, Movement) and self.allowed == []:
            raise ValueError("Allowed movements must be nonempty or omitted")
        if isinstance(self, ReviewIssue) and not self.paths:
            raise ValueError("Issue needs at least one affected path")
        if isinstance(self, Source) and self.sent_at is not None:
            stamp = datetime.fromisoformat(self.sent_at.replace("Z", "+00:00"))
            if stamp.tzinfo is None:
                raise ValueError("Source sent_at requires a timezone")
        if isinstance(self, Workout):
            if not self.versions:
                raise ValueError("Workout needs at least one version")
            if self.scheduled_date is not None:
                date.fromisoformat(self.scheduled_date)
        if isinstance(self, Repeat) and self.between is not None:
            if self.count.max == 1 or not _recovery_only(self.between):
                raise ValueError("Between requires repeated iterations and only recovery leaves")
        if isinstance(self, (NumericTarget, ProgressionTarget)):
            values = [self.value.min, self.value.max] if isinstance(self, NumericTarget) else [self.from_, self.to]
            limit = {"rpe_0_10": 10, "heart_rate_max_percent": 100}.get(self.metric)
            if min(values) < 0 or (limit is not None and max(values) > limit):
                raise ValueError("Target outside metric bounds")
        if isinstance(self, WorkoutConversion):
            if not self.sources or ((self.status == "workout") != bool(self.workouts)):
                raise ValueError("Conversion requires sources and workouts only for workout status")


def _recovery_only(node: WorkoutNode) -> bool:
    if isinstance(node, Step):
        return node.role == "recovery"
    if isinstance(node, Sequence):
        return all(_recovery_only(n) for n in node.children)
    if isinstance(node, Repeat):
        return _recovery_only(node.body) and (node.between is None or _recovery_only(node.between))
    return all(_recovery_only(o.plan) for o in node.options)


def _require_typed(value: Any, decoded: Any) -> None:
    """Constructors accept model objects; JSON dictionaries use from_dict."""
    if isinstance(decoded, JsonModel) and not isinstance(value, JsonModel):
        raise ValueError("Use a model instance, or load dictionaries with from_dict")
    if isinstance(decoded, list):
        for original, converted in zip(value, decoded):
            _require_typed(original, converted)


@dataclass(frozen=True, kw_only=True)
class PositiveBounds(JsonModel):
    min: float
    max: float

@dataclass(frozen=True, kw_only=True)
class ValueBounds(JsonModel):
    min: float
    max: float

@dataclass(frozen=True, kw_only=True)
class Count(JsonModel):
    min: int
    max: int

@dataclass(frozen=True, kw_only=True)
class Note(JsonModel):
    text: str
    category: Literal['instruction', 'route', 'terrain', 'technique', 'coordination', 'context'] | None = field(default=None)

@dataclass(frozen=True, kw_only=True)
class ReviewIssue(JsonModel):
    severity: Literal['blocking', 'warning']
    code: Literal['ambiguous', 'conflicting', 'missing', 'inferred', 'unresolved_reference']
    message: str
    paths: list[str]
    resolution: Resolution | None = field(default=None)

@dataclass(frozen=True, kw_only=True)
class Source(JsonModel):
    type: Literal['email', 'attachment', 'review_feedback']
    reference: str
    subject: str | None = field(default=None)
    sent_at: str | None = field(default=None, metadata={"json": 'sentAt'})

@dataclass(frozen=True, kw_only=True)
class Phase(JsonModel):
    status: Literal['specified', 'not_specified', 'explicitly_none']
    plan: WorkoutNode | None = field(default=None)

@dataclass(frozen=True, kw_only=True)
class Step(JsonModel):
    kind: Literal['step'] = field(default='step')
    label: str | None = field(default=None)
    notes: list[Note] | None = field(default=None)
    optional: bool | None = field(default=None)
    role: Literal['effort', 'recovery', 'drill']
    end: EndCondition
    targets: list[Target] | None = field(default=None)
    movement: Movement | None = field(default=None)

@dataclass(frozen=True, kw_only=True)
class Sequence(JsonModel):
    kind: Literal['sequence'] = field(default='sequence')
    label: str | None = field(default=None)
    notes: list[Note] | None = field(default=None)
    optional: bool | None = field(default=None)
    children: list[WorkoutNode]
    declared_duration_seconds: PositiveBounds | None = field(default=None, metadata={"json": 'declaredDurationSeconds'})

@dataclass(frozen=True, kw_only=True)
class Repeat(JsonModel):
    kind: Literal['repeat'] = field(default='repeat')
    label: str | None = field(default=None)
    notes: list[Note] | None = field(default=None)
    optional: bool | None = field(default=None)
    count: Count
    body: WorkoutNode
    between: WorkoutNode | None = field(default=None)

@dataclass(frozen=True, kw_only=True)
class Choice(JsonModel):
    kind: Literal['choice'] = field(default='choice')
    label: str | None = field(default=None)
    notes: list[Note] | None = field(default=None)
    optional: bool | None = field(default=None)
    reason: str
    options: list[ChoiceOption]

@dataclass(frozen=True, kw_only=True)
class WorkoutVersion(JsonModel):
    label: str
    audience: str | None = field(default=None)
    notes: list[Note] | None = field(default=None)
    warmup: Phase
    main: Phase
    cooldown: Phase

@dataclass(frozen=True, kw_only=True)
class Workout(JsonModel):
    id: str
    title: str
    sport: Literal['running']
    scheduled_date: str | None = field(default=None, metadata={"json": 'scheduledDate'})
    location: str | None = field(default=None)
    notes: list[Note] | None = field(default=None)
    versions: list[WorkoutVersion]

@dataclass(frozen=True, kw_only=True)
class TimeEnd(JsonModel):
    kind: Literal['time'] = field(default='time')
    seconds: PositiveBounds

@dataclass(frozen=True, kw_only=True)
class DistanceEnd(JsonModel):
    kind: Literal['distance'] = field(default='distance')
    meters: PositiveBounds

@dataclass(frozen=True, kw_only=True)
class LapsEnd(JsonModel):
    kind: Literal['laps'] = field(default='laps')
    count: Count
    lap_length_meters: float | None = field(default=None, metadata={"json": 'lapLengthMeters'})

@dataclass(frozen=True, kw_only=True)
class RepetitionsEnd(JsonModel):
    kind: Literal['repetitions'] = field(default='repetitions')
    count: Count

@dataclass(frozen=True, kw_only=True)
class ManualEnd(JsonModel):
    kind: Literal['manual'] = field(default='manual')

@dataclass(frozen=True, kw_only=True)
class EventEnd(JsonModel):
    kind: Literal['event'] = field(default='event')
    description: str

@dataclass(frozen=True, kw_only=True)
class UnknownEnd(JsonModel):
    kind: Literal['unknown'] = field(default='unknown')
    text: str

@dataclass(frozen=True, kw_only=True)
class AnyOfEnd(JsonModel):
    kind: Literal['any_of'] = field(default='any_of')
    conditions: list[EndCondition]

@dataclass(frozen=True, kw_only=True)
class AllOfEnd(JsonModel):
    kind: Literal['all_of'] = field(default='all_of')
    conditions: list[EndCondition]

@dataclass(frozen=True, kw_only=True)
class NumericTarget(JsonModel):
    kind: Literal['numeric'] = field(default='numeric')
    metric: Literal['vma_percent', 'speed_mps', 'pace_seconds_per_km', 'heart_rate_bpm', 'heart_rate_max_percent', 'power_watts', 'cadence_spm', 'rpe_0_10']
    value: ValueBounds
    approximate: bool | None = field(default=None)

@dataclass(frozen=True, kw_only=True)
class EffortTarget(JsonModel):
    kind: Literal['effort'] = field(default='effort')
    value: Literal['easy', 'steady', 'hard', 'submaximal', 'all_out', 'unspecified']
    text: str

@dataclass(frozen=True, kw_only=True)
class ProgressionTarget(JsonModel):
    kind: Literal['progression'] = field(default='progression')
    metric: Literal['vma_percent', 'speed_mps', 'pace_seconds_per_km', 'heart_rate_bpm', 'heart_rate_max_percent', 'power_watts', 'cadence_spm', 'rpe_0_10']
    from_: float = field(metadata={"json": 'from'})
    to: float
    distribution: Literal['unspecified', 'linear']
    scope: Literal['within_step', 'across_iterations']

@dataclass(frozen=True, kw_only=True)
class Resolution(JsonModel):
    text: str
    by: Literal['reviewer', 'source']

@dataclass(frozen=True, kw_only=True)
class Movement(JsonModel):
    mode: Literal['active', 'passive', 'unspecified']
    allowed: list[Literal['run', 'jog', 'walk', 'stand', 'sit', 'other']] | None = field(default=None)

@dataclass(frozen=True, kw_only=True)
class ChoiceOption(JsonModel):
    label: str
    audience: str | None = field(default=None)
    plan: WorkoutNode

@dataclass(frozen=True, kw_only=True)
class WorkoutConversion(JsonModel):
    schema_version: Literal['0.1'] = field(default='0.1', metadata={"json": 'schemaVersion'})
    status: Literal['workout', 'no_workout', 'unreadable']
    sources: list[Source]
    workouts: list[Workout]
    notes: list[Note] | None = field(default=None)
    issues: list[ReviewIssue]


EndCondition = TimeEnd | DistanceEnd | LapsEnd | RepetitionsEnd | ManualEnd | EventEnd | UnknownEnd | AnyOfEnd | AllOfEnd
Target = NumericTarget | EffortTarget | ProgressionTarget
WorkoutNode = Step | Sequence | Repeat | Choice
