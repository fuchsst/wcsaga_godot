class_name HasTargetCondition
extends WCSBTCondition

## Condition that checks if the AI agent has a valid target

@export var check_target_alive: bool = true
@export var check_line_of_sight: bool = false
@export var max_target_distance: float = 0.0  # 0 means no distance limit

func evaluate_wcs_condition(delta: float) -> bool:
	var target: Node = get_current_target()
	
	# No target at all
	if not target:
		return false
	
	# Check if target is still valid/alive
	if check_target_alive:
		if not is_instance_valid(target):
			return false
		
		# Check if target has health and is alive
		if target.has_method("is_alive") and not target.is_alive():
			return false
		
		if target.has_method("get_health") and target.get_health() <= 0:
			return false
	
	# Check distance limit
	if max_target_distance > 0.0:
		var distance: float = distance_to_target(target)
		if distance > max_target_distance:
			return false
	
	# Check line of sight
	if check_line_of_sight:
		if not has_line_of_sight(target):
			return false
	
	return true