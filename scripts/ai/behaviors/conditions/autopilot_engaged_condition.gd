class_name AutopilotEngagedCondition
extends WCSBTCondition

## Behavior tree condition to check if autopilot is engaged and active
## Used to control autopilot behavior tree execution

@export var check_safety_status: bool = true
@export var check_destination_set: bool = true
@export var check_navigation_active: bool = true

var autopilot_manager: AutopilotManager

func _setup() -> void:
	super._setup()
	
	# Find autopilot manager
	autopilot_manager = get_node("/root/AutopilotManager")
	if not autopilot_manager:
		push_error("AutopilotEngagedCondition: AutopilotManager not found")

func check_wcs_condition() -> bool:
	if not autopilot_manager:
		return false
	
	# Check if autopilot is engaged
	if not autopilot_manager.is_autopilot_engaged():
		return false
	
	# Optional safety status check
	if check_safety_status:
		var safety_monitor: AutopilotSafetyMonitor = autopilot_manager.get_node_or_null("AutopilotSafetyMonitor")
		if safety_monitor and not safety_monitor.is_safe_to_navigate():
			return false
	
	# Optional destination check
	if check_destination_set:
		var status: Dictionary = autopilot_manager.get_autopilot_status()
		var destination: Vector3 = status.get("destination", Vector3.ZERO)
		if destination == Vector3.ZERO:
			return false
	
	# Optional navigation active check
	if check_navigation_active:
		var status: Dictionary = autopilot_manager.get_autopilot_status()
		var state: String = status.get("state", "DISENGAGED")
		if state != "ENGAGED":
			return false
	
	return true