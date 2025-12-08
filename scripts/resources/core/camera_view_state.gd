## CameraViewState - Persistent camera configuration resource
## Stores view preferences that persist across sessions

class_name CameraViewState
extends Resource

## External view rotation angles (pitch, yaw in radians)
@export var external_angles: Vector3 = Vector3.ZERO

## External view distance
@export var external_distance: float = 20.0

## Chase view distance
@export var chase_distance: float = 15.0

## Default field of view in degrees
@export var default_fov: float = 50.0

## Target/zoom field of view in degrees
@export var target_fov: float = 40.0

## Preferred view mode on mission start
@export var preferred_start_mode: int = 0 # WCSCameraController.ViewMode.COCKPIT

## Camera shake intensity multiplier
@export var shake_intensity: float = 1.0

## Head bob intensity multiplier
@export var head_bob_intensity: float = 0.5


## Reset to defaults
func reset_to_defaults() -> void:
	external_angles = Vector3.ZERO
	external_distance = 20.0
	chase_distance = 15.0
	default_fov = 50.0
	target_fov = 40.0
	preferred_start_mode = 0
	shake_intensity = 1.0
	head_bob_intensity = 0.5
