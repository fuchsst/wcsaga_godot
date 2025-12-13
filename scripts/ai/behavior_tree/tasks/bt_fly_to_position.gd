@tool
class_name BTFlyToPosition
extends BTAction

## Behavior Tree Action: Fly To Position
## Navigates the ship to a target position defined in the blackboard

@export var target_pos_var: String = "target_pos"
@export var stop_distance: float = 50.0
@export var throttle_scale: float = 1.0

func _tick(delta: float) -> Status:
	var ship: ShipEntity = agent as ShipEntity
	if not ship:
		return FAILURE

	var target_pos = blackboard.get_var(target_pos_var, Vector3.ZERO)
	if target_pos == Vector3.ZERO:
		return FAILURE

	var to_target = target_pos - ship.global_position
	var dist = to_target.length()

	if dist < stop_distance:
		# Arrived
		ship.set_throttle(0.0)
		return SUCCESS

	# Simple steering logic
	# Transform target to local space
	var local_target = ship.to_local(target_pos)

	# Calculate pitch/yaw to face target
	# Local target negative Z is forward
	# We want local_target to map to -Z

	# Pass simple steering command
	# (Actual steering would be PID controller or simple proportional)
	var steer_yaw = 0.0
	var steer_pitch = 0.0

	# Standard Godot forward is -Z.
	# We want to minimize x and y of the local vector normalized
	var dir = local_target.normalized()

	# Yaw: rotate around Y to minimize X. if local.x > 0, we need to turn LEFT (positive yaw? No, +Yaw is usually left in WCS physics?)
	# WCSPhysicsBody: "yaw": 0.0, # -1 = left, +1 = right
	# If local.x is positive (right), we want to yaw RIGHT (+1)
	steer_yaw = clamp(dir.x * 5.0, -1.0, 1.0)

	# Pitch: rotate around X to minimize Y. if local.y > 0 (up), we need to pitch UP (+1 or -1?)
	# WCSPhysicsBody: "pitch": 0.0, # -1 = nose down, +1 = nose up
	# If local.y is positive (up), we want to pitch UP (+1)
	steer_pitch = - clamp(dir.y * 5.0, -1.0, 1.0) # wait, pitch axis direction depends.
	# usually pitch_up means local target Y goes down?
	# Let's verify: Pitch up rotates around +X (Right).
	# Rotated vector (0,1,0) by +90deg X -> (0,0,1). Y became Z.
	# So pitch up moves +Y to +Z (behind).
	# So if target is +Y, we pitch UP to bring it to center (-Z)?
	# Actually simpler: Proportional navigation
	steer_pitch = clamp(dir.y * 5.0, -1.0, 1.0)

	ship.set_control_input(steer_pitch, steer_yaw, 0.0, 1.0 * throttle_scale)

	return RUNNING
