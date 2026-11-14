"""Workout delivery to registered running watches.

The list POST to device-service was verified live with a fenix 3 HR. Avoid
mylastused: Garmin can return an old device absent from the registered list.
"""


class DeliveryError(RuntimeError):
    """Safe stage information; never include raw responses or request headers."""


def send_workout(client, workout_id: int, device_id: int | None = None):
    stage = "registered running-watch selection"
    try:
        devices = client.get_devices()
        eligible = [device for device in devices
                    if device.get("runningWorkoutCapable") is True
                    and device.get("activeInd", 1) in (1, True)]
        if device_id is None:
            if not eligible:
                raise DeliveryError("No active registered device supports running workouts.")
            if len(eligible) != 1:
                raise DeliveryError("Multiple running-capable devices found; select one with --device-id.")
            device_id = eligible[0]["deviceId"]
        if isinstance(device_id, bool) or int(device_id) <= 0:
            raise ValueError("Invalid device ID")
        device_id = int(device_id)
        selected = [device for device in eligible if str(device.get("deviceId")) == str(device_id)]
        if not selected:
            raise DeliveryError("Selected device is not an active registered running-capable device.")
        name = str(selected[0].get("displayName") or "running watch")
        print("Delivery target: " + "".join(c for c in name if c.isprintable())[:100])
        stage = "existing workout lookup"
        workout = client.get_workout_by_id(workout_id)
        stage = "device-message submission"
        return client.client.post(
            "connectapi", "/device-service/devicemessage/messages",
            json=[{
                "deviceId": device_id,
                "messageUrl": f"workout-service/workout/FIT/{workout_id}",
                "messageType": "workouts",
                "groupName": None,
                "messageName": workout["workoutName"],
                "priority": 1,
                "fileType": "FIT",
                "metaDataId": workout_id,
            }],
            api=True,
        )
    except DeliveryError:
        raise
    except Exception as error:
        status = getattr(getattr(error, "response", None), "status_code", None)
        suffix = f", HTTP {status}" if isinstance(status, int) else ""
        raise DeliveryError(f"{stage}: {type(error).__name__}{suffix}") from None
