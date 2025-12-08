@tool
class_name BTChaseTarget
extends BTAction

## Behavior Tree Action: Chase Target
## Pursues a target Node3D defined in blackboard

@export var target_var: String = "target"
@export var optimal_range: float = 300.0

func _tick(delta: float) -> Status:
	var ship: ShipEntity = agent as ShipEntity
	if not ship:
		return FAILURE
		
	var target = blackboard.get_var(target_var) as Node3D
	if not is_instance_valid(target):
		return FAILURE
		
	# Calculate intercept point? For now just chase position
	var to_target = target.global_position - ship.global_position
	var dist = to_target.length()
	var local_target = ship.to_local(target.global_position)
	var dir = local_target.normalized()
	
	var steer_yaw = clamp(dir.x * 5.0, -1.0, 1.0)
	var steer_pitch = clamp(dir.y * 5.0, -1.0, 1.0)
	
	# Throttle logic
	var throttle = 1.0
	if dist < optimal_range:
		throttle = 0.5
	if dist < optimal_range * 0.5:
		throttle = 0.0
		
	ship.set_control_input(steer_pitch, steer_yaw, 0.0, throttle)
	
	return RUNNING
