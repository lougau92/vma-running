"""Club session semantics, independent of Garmin network access."""

import math
import json
from pathlib import Path
import unittest

from garmin_club_session import build_club_workout


class ClubSessionTests(unittest.TestCase):
    def steps(self, group=1, vma=16):
        return build_club_workout(group, vma)["workoutSegments"][0]["workoutSteps"]

    def test_group_one_order_and_distance(self):
        steps = self.steps()
        runs = [s for s in steps if s["stepType"]["stepTypeKey"] == "interval"]
        self.assertEqual([s["endConditionValue"] for s in runs], [400, 400, 200, 1200] * 3)
        self.assertEqual(sum(s["endConditionValue"] for s in runs), 6600)
        self.assertEqual(len(steps), 25)

    def test_group_two_order_and_distance(self):
        steps = self.steps(2)
        runs = [s for s in steps if s["stepType"]["stepTypeKey"] == "interval"]
        self.assertEqual([s["endConditionValue"] for s in runs], [400, 200, 1000] * 3)
        self.assertEqual(sum(s["endConditionValue"] for s in runs), 4800)
        self.assertEqual(len(steps), 19)

    def test_recovery_counts_and_interblock_rest(self):
        for group, count in ((1, 9), (2, 6)):
            steps = self.steps(group)
            recovery = [s for s in steps if s["stepType"]["stepTypeKey"] == "recovery"]
            rests = [s for s in steps if s["stepType"]["stepTypeKey"] == "rest"]
            self.assertEqual(len(recovery), count)
            self.assertTrue(all(s["endConditionValue"] == 60 and s["endCondition"]["conditionTypeKey"] == "time" for s in recovery))
            self.assertTrue(all("200 m" in s["description"] for s in recovery))
            self.assertEqual(len(rests), 2)
            self.assertTrue(all(s["endConditionValue"] == 120 for s in rests))
            self.assertEqual(steps[-2]["stepType"]["stepTypeKey"], "interval")
            self.assertEqual(steps[-1]["stepType"]["stepTypeKey"], "cooldown")

    def test_pace_ranges_and_vma_conversion(self):
        for group, percentages in ((1, [(90, 90), (100, 100), (110, 110), (80, 85)]), (2, [(90, 90), (100, 100), (80, 85)])):
            for vma in (12, 16, 18):
                runs = [s for s in self.steps(group, vma) if s["stepType"]["stepTypeKey"] == "interval"]
                for step, (low, high) in zip(runs, percentages * 3):
                    self.assertAlmostEqual(step["targetValueOne"], vma * high / 100 / 3.6)
                    self.assertAlmostEqual(step["targetValueTwo"], vma * low / 100 / 3.6)

    def test_lap_warmup_and_two_lap_cooldown_no_invented_length(self):
        for group in (1, 2):
            steps = self.steps(group)
            for step in (steps[0], steps[-1]):
                self.assertEqual(step["endCondition"]["conditionTypeKey"], "lap.button")
                self.assertNotIn("endConditionValue", step)
            self.assertIn("2 tours", steps[-1]["description"])
            self.assertEqual([s["stepOrder"] for s in steps], list(range(1, len(steps) + 1)))

    def test_invalid_vma_is_rejected(self):
        for vma in (0, -1, math.nan, math.inf):
            with self.assertRaises(ValueError):
                build_club_workout(1, vma)

    def test_live_club_fit_preserves_every_instruction(self):
        evidence = json.loads((Path(__file__).parent / "fixtures/garmin_club_observations.json").read_text())
        for group in (1, 2):
            case = evidence["cases"][f"group_{group}"]
            self.assertEqual(case["payload"], build_club_workout(group, 16))
            self.assertEqual(case["changes"], [])
            self.assertEqual(case["cleanup"], "deleted")
            exported = [m["fields"] for m in case["fit"] if m["message"] == "workout_step"]
            self.assertEqual(len(exported), len(self.steps(group)))
            for source, fit in zip(self.steps(group), exported):
                with self.subTest(group=group, step=source["stepOrder"]):
                    kind = source["stepType"]["stepTypeKey"]
                    self.assertEqual(fit["intensity"], "active" if kind == "interval" else kind)
                    self.assertEqual(fit["notes"], source["description"])
                    condition = source["endCondition"]["conditionTypeKey"]
                    self.assertEqual(fit["duration_type"], "open" if condition == "lap.button" else condition)
                    if condition in ("time", "distance"):
                        self.assertEqual(fit[f"duration_{condition}"], source["endConditionValue"])
                    if kind == "interval":
                        self.assertAlmostEqual(fit["custom_target_speed_low"], source["targetValueTwo"], delta=0.001)
                        self.assertAlmostEqual(fit["custom_target_speed_high"], source["targetValueOne"], delta=0.001)


if __name__ == "__main__":
    unittest.main()
