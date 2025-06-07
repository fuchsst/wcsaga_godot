class_name AutopilotSafeCondition
extends WCSBTCondition

## Behavior tree condition to check if it's safe for autopilot operation
## Monitors threats, collisions, and other safety factors

@export var max_allowed_threat_level: AutopilotSafetyMonitor.ThreatLevel = AutopilotSafetyMonitor.ThreatLevel.MEDIUM
@export var check_collision_prediction: bool = true
@export var check_emergency_situations: bool = true

var safety_monitor: AutopilotSafetyMonitor

func _setup() -> void:
	super._setup()
	
	# Find safety monitor
	var autopilot_manager: AutopilotManager = get_node("/root/AutopilotManager")
	if autopilot_manager:
		safety_monitor = autopilot_manager.get_node_or_null("AutopilotSafetyMonitor")
	
	if not safety_monitor:
		push_error("AutopilotSafeCondition: AutopilotSafetyMonitor not found")

func check_wcs_condition() -> bool:
	if not safety_monitor:
		return false
	
	# Check overall safety status
	if not safety_monitor.is_safe_to_navigate():
		return false
	
	# Check threat level
	var current_threat_level: AutopilotSafetyMonitor.ThreatLevel = safety_monitor.get_highest_threat_level()
	if current_threat_level > max_allowed_threat_level:
		return false
	
	# Check collision predictions
	if check_collision_prediction:
		var collision_predictions: Dictionary = safety_monitor.collision_predictions
		for prediction_data in collision_predictions.values():
			if prediction_data.collision_time <= 3.0:  # 3 second warning
				return false
	
	# Check emergency situations
	if check_emergency_situations:
		var emergency_situations: Dictionary = safety_monitor.emergency_situations
		if not emergency_situations.is_empty():
			return false
	
	return true