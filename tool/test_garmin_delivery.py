"""Offline delivery regression checks; no Garmin requests."""

from contextlib import contextmanager
import unittest
from unittest.mock import Mock, patch

from garmin_delivery import DeliveryError, send_workout
import garmin_upload_test


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.client = Mock()
        self.client.get_device_last_used.return_value = {"userDeviceId": 42}
        self.client.get_devices.return_value = [{"deviceId": 99, "displayName": "Test watch", "runningWorkoutCapable": True, "activeInd": 1}]
        self.client.get_workout_by_id.return_value = {"workoutName": "Test"}

    def test_uses_verified_endpoint_and_registered_watch(self):
        send_workout(self.client, 123)
        args, kwargs = self.client.client.post.call_args
        self.assertEqual(args, ("connectapi", "/device-service/devicemessage/messages"))
        self.assertIsInstance(kwargs["json"], list)
        self.assertEqual(kwargs["json"][0]["deviceId"], 99)
        self.assertEqual(kwargs["json"][0]["metaDataId"], 123)
        self.assertEqual(kwargs["json"][0]["messageUrl"], "workout-service/workout/FIT/123")
        self.client.get_device_last_used.assert_not_called()
        self.assertTrue(kwargs["api"])

    def test_explicit_device_skips_lookup(self):
        send_workout(self.client, 123, 99)
        self.client.get_device_last_used.assert_not_called()
        self.assertEqual(self.client.client.post.call_args.kwargs["json"][0]["deviceId"], 99)

    def test_identifies_failure_without_server_details(self):
        self.client.get_devices.side_effect = RuntimeError("private response")
        with self.assertRaises(DeliveryError) as context:
            send_workout(self.client, 123)
        self.assertIn("registered running-watch selection", str(context.exception))
        self.assertNotIn("private response", str(context.exception))
        self.client.client.post.assert_not_called()

    def test_ambiguous_watch_selection_does_not_send(self):
        self.client.get_devices.return_value *= 2
        with self.assertRaisesRegex(DeliveryError, "Multiple"):
            send_workout(self.client, 123)
        self.client.client.post.assert_not_called()

    def test_unregistered_device_is_rejected(self):
        with self.assertRaisesRegex(DeliveryError, "not an active registered"):
            send_workout(self.client, 123, 42)
        self.client.client.post.assert_not_called()

    def test_no_running_watch_does_not_send(self):
        self.client.get_devices.return_value[0]["runningWorkoutCapable"] = False
        with self.assertRaisesRegex(DeliveryError, "No active"):
            send_workout(self.client, 123)
        self.client.client.post.assert_not_called()

    def test_existing_workout_never_creates_duplicate(self):
        @contextmanager
        def session(_):
            yield self.client

        with patch("sys.argv", ["test", "--workout-id", "123"]), \
             patch("sys.stdin.isatty", return_value=True), \
             patch("builtins.input", return_value="y"), \
             patch.object(garmin_upload_test, "authenticated_session", session), \
             patch.object(garmin_upload_test, "send_workout") as send:
            self.assertEqual(garmin_upload_test.main(), 0)
        self.client.upload_workout.assert_not_called()
        send.assert_called_once_with(self.client, 123, None)


if __name__ == "__main__":
    unittest.main()
