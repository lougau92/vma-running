"""Regressions against sanitized observations from the real Garmin service."""

import json
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

from garmin_payload_probe import differences, probes, run_probe, sanitize


class ProbeLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.client = Mock()
        self.client.upload_workout.return_value = {"workoutId": 123}
        self.client.get_workout_by_id.return_value = probes()["lap_button"]

    def test_deletes_created_probe_after_readback_failure(self):
        self.client.get_workout_by_id.side_effect = RuntimeError("private response")
        journal = Mock()
        record = run_probe(self.client, "lap_button", probes()["lap_button"], journal)
        self.client.delete_workout.assert_called_once_with(123)
        self.assertEqual(record["failure_stage"], "readback")
        self.assertEqual(record["cleanup"], "deleted")
        self.assertNotIn("private response", json.dumps(record))
        self.assertEqual(journal.call_count, 2)

    def test_does_not_delete_on_rejected_upload(self):
        self.client.upload_workout.side_effect = ValueError()
        record = run_probe(self.client, "lap_button", probes()["lap_button"], Mock())
        self.client.delete_workout.assert_not_called()
        self.assertEqual(record["cleanup"], "not_created")

    def test_cleanup_failure_is_recorded(self):
        self.client.delete_workout.side_effect = RuntimeError("private response")
        with patch("garmin_payload_probe.fit_summary", return_value=[{"message": "workout_step"}]):
            record = run_probe(self.client, "lap_button", probes()["lap_button"], Mock())
        self.assertEqual(record["cleanup"], "failed:RuntimeError")

    def test_snapshot_discards_owner_and_author_fields(self):
        stored = {"ownerId": 123, "author": {"email": "private"}, "workoutSegments": [{"owner": "private", "workoutSteps": [{"description": "Safe note", "ownerId": 123}]}]}
        self.assertNotIn("private", json.dumps(sanitize(stored)))
        self.assertIn("Safe note", json.dumps(sanitize(stored)))

    def test_comparison_detects_dropped_fields_and_rounding(self):
        self.assertEqual(differences({"pace": 3.333333}, {"pace": 3.3333331}), [])
        self.assertEqual(differences({"pace": 3.333333}, {})[0]["stored"], "<missing>")


class LiveEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = Path(__file__).parent / "fixtures/garmin_payload_observations.json"
        cls.evidence = json.loads(path.read_text())["cases"]

    def fit_steps(self, name):
        return [m["fields"] for m in self.evidence[name]["fit"] if m["message"] == "workout_step"]

    def test_every_current_probe_has_live_evidence(self):
        self.assertEqual(set(probes()), set(self.evidence))

    def test_generated_cases_match_live_tested_requests(self):
        for name, payload in probes().items():
            with self.subTest(case=name):
                payload["workoutName"] = "VMA probe " + name
                self.assertEqual(payload, self.evidence[name]["payload"])

    def test_all_created_probes_were_deleted(self):
        self.assertTrue(all(c["cleanup"] in ("deleted", "not_created") for c in self.evidence.values()))

    def test_time_and_distance_are_seconds_and_meters(self):
        steps = self.fit_steps("timed_and_distance")
        self.assertEqual(steps[0]["duration_time"], 60)
        self.assertEqual(steps[1]["duration_distance"], 200)
        self.assertEqual([s["intensity"] for s in steps], ["warmup", "active", "recovery", "rest", "cooldown"])

    def test_lap_button_exports_as_open_duration(self):
        steps = self.fit_steps("lap_button")
        self.assertEqual(steps[0]["duration_type"], "open")
        self.assertEqual(steps[-1]["duration_type"], "open")

    def test_both_pace_orders_export_same_sorted_speed_range(self):
        fast = self.fit_steps("pace_fast_first")[0]
        slow = self.fit_steps("pace_slow_first")[0]
        self.assertEqual(fast, slow)
        self.assertEqual(fast["custom_target_speed_low"], 3.333)
        self.assertEqual(fast["custom_target_speed_high"], 3.704)

    def test_repeat_targets_correct_zero_based_fit_step(self):
        steps = self.fit_steps("repeat_distance_recovery")
        self.assertEqual(steps[3]["duration_type"], "repeat_until_steps_cmplt")
        self.assertEqual(steps[3]["duration_step"], 1)
        self.assertEqual(steps[3]["repeat_steps"], 2)

    def test_nested_repeats_export_two_repeat_instructions(self):
        repeats = [s for s in self.fit_steps("nested_repeats") if s["duration_type"] == "repeat_until_steps_cmplt"]
        self.assertEqual(len(repeats), 2)
        self.assertEqual([s["duration_step"] for s in repeats], [0, 0])

    def test_heart_rate_offset_and_cadence_encoding(self):
        steps = self.fit_steps("heart_rate_and_cadence")
        # FIT workout_hr values above 100 encode BPM + 100, per Garmin's profile.
        self.assertEqual(steps[0]["custom_target_heart_rate_low"] - 100, 130)
        self.assertEqual(steps[0]["custom_target_heart_rate_high"] - 100, 150)
        self.assertEqual(steps[1]["target_hr_zone"], 2)
        # Observe representation only; watch display is still unverified.
        self.assertEqual(steps[2]["custom_target_cadence_low"], 80)
        self.assertEqual(steps[2]["custom_target_cadence_high"], 90)

    def test_secondary_target_and_notes_reach_fit(self):
        step = self.fit_steps("secondary_target_and_notes")[0]
        self.assertEqual(step["secondary_target_type"], "cadence")
        self.assertEqual(step["notes"], "Easy pace – récupération")

    def test_unknown_field_is_discarded(self):
        changes = self.evidence["unknown_field"]["changes"]
        self.assertEqual(len(changes), 1)
        self.assertTrue(changes[0]["path"].endswith("vmaProbeUnknown"))

    def test_omitting_orders_reorders_workout(self):
        stored = self.evidence["omitted_orders"]["stored"]["workoutSegments"][0]["workoutSteps"]
        self.assertEqual(stored[0]["type"], "RepeatGroupDTO")
        self.assertEqual(stored[1]["type"], "ExecutableStepDTO")

    def test_missing_sport_and_time_repeat_rejected(self):
        for case in ("omitted_sport", "minimal_top_level", "time_based_repeat"):
            self.assertEqual(self.evidence[case]["failure_stage"], "upload")
            self.assertEqual(self.evidence[case]["http_status"], 400)

    def test_estimate_and_description_can_be_omitted(self):
        for case in ("omitted_estimate", "omitted_description", "repeat_without_condition_value"):
            self.assertEqual(self.evidence[case]["outcome"], "exported")


if __name__ == "__main__":
    unittest.main()
