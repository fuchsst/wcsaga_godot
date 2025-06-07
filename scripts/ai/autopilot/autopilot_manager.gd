class_name AutopilotManager
extends Node

## Central autopilot system for player assistance and automation
## Handles mode switching, control handoff, and integration with navigation systems

signal autopilot_engaged(destination: Vector3, mode: AutopilotMode)
signal autopilot_disengaged(reason: String)
signal autopilot_destination_reached(final_position: Vector3)
signal autopilot_interrupted(threat: Node3D, reason: String)
signal control_handoff_requested(from_mode: String, to_mode: String)
signal squadron_autopilot_activated(formation_id: String)

enum AutopilotMode {
	DISABLED,           # Autopilot completely disabled
	WAYPOINT_NAV,      # Navigate to single waypoint
	PATH_FOLLOWING,    # Follow multi-waypoint path
	FORMATION_FOLLOW,  # Follow formation leader
	SQUADRON_AUTOPILOT,# Coordinate multiple player ships
	ASSIST_ONLY        # Manual control with AI assistance
}

enum EngagementState {
	DISENGAGED,
	ENGAGING,
	ENGAGED,
	DISENGAGING,
	EMERGENCY_STOP
}

enum DisengagementReason {
	MANUAL_REQUEST,
	THREAT_DETECTED,
	COLLISION_IMMINENT,
	NAVIGATION_FAILED,
	DESTINATION_REACHED,
	SYSTEM_ERROR
}

# Core autopilot configuration
@export var default_navigation_speed: float = 0.8
@export var threat_detection_radius: float = 2000.0
@export var auto_disengage_on_combat: bool = true
@export var formation_coordination_enabled: bool = true
@export var time_compression_enabled: bool = true

# System references
var player_ship: Node3D
var ship_controller: Node
var navigation_controller: WCSNavigationController
var threat_detector: Node
var ui_manager: Node

# Current autopilot state
var current_mode: AutopilotMode = AutopilotMode.DISABLED
var engagement_state: EngagementState = EngagementState.DISENGAGED
var current_destination: Vector3 = Vector3.ZERO
var current_path: Array[Vector3] = []
var autopilot_start_time: float = 0.0

# Squadron autopilot system
var squadron_formations: Dictionary = {}
var squadron_members: Array[Node3D] = []
var is_squadron_leader: bool = false

# Safety and threat monitoring
var safety_monitor: AutopilotSafetyMonitor
var last_threat_check_time: float = 0.0
var threat_check_frequency: float = 0.5  # Check every 500ms

# Control handoff management
var handoff_in_progress: bool = false
var handoff_timeout: float = 2.0
var handoff_start_time: float = 0.0
var previous_control_mode: String = ""

# Performance tracking
var autopilot_efficiency: float = 1.0
var total_autopilot_time: float = 0.0
var successful_navigations: int = 0
var emergency_disengagements: int = 0

func _ready() -> void:
	_initialize_autopilot_systems()
	set_process(true)

func _process(delta: float) -> void:
	_update_autopilot_state(delta)
	_update_threat_monitoring(delta)
	_update_control_handoff(delta)
	_update_squadron_coordination(delta)

# Public autopilot interface

func engage_autopilot_to_position(destination: Vector3, mode: AutopilotMode = AutopilotMode.WAYPOINT_NAV) -> bool:
	"""Engage autopilot to navigate to a single destination"""
	if not _validate_autopilot_engagement(destination):
		return false
	
	current_destination = destination
	current_path = [destination]
	
	return _start_autopilot_engagement(mode)

func engage_autopilot_along_path(path: Array[Vector3], mode: AutopilotMode = AutopilotMode.PATH_FOLLOWING) -> bool:
	"""Engage autopilot to follow a multi-waypoint path"""
	if path.is_empty() or not _validate_autopilot_engagement(path[-1]):
		return false
	
	current_destination = path[-1]
	current_path = path
	
	return _start_autopilot_engagement(mode)

func engage_formation_autopilot(formation_leader: Node3D, formation_offset: Vector3 = Vector3.ZERO) -> bool:
	"""Engage autopilot to follow formation leader"""
	if not formation_leader or not _validate_player_ship():
		return false
	
	# Enable formation following in navigation controller
	if navigation_controller:
		if not navigation_controller.enable_formation_following(formation_leader.get_node("NavigationController"), formation_offset):
			push_error("AutopilotManager: Failed to enable formation following")
			return false
	
	return _start_autopilot_engagement(AutopilotMode.FORMATION_FOLLOW)

func engage_squadron_autopilot(squadron_ships: Array[Node3D], formation_type: FormationManager.FormationType = FormationManager.FormationType.DIAMOND) -> bool:
	"""Engage coordinated autopilot for multiple player ships"""
	if squadron_ships.size() < 2 or not formation_coordination_enabled:
		return false
	
	# Create formation for squadron
	var formation_manager: FormationManager = get_node("/root/AIManager/FormationManager")
	if not formation_manager:
		push_error("AutopilotManager: FormationManager not available for squadron autopilot")
		return false
	
	var formation_id: String = formation_manager.create_formation(player_ship, formation_type, 150.0)
	if formation_id.is_empty():
		return false
	
	# Add squadron members to formation
	for ship in squadron_ships:
		if ship != player_ship:
			formation_manager.add_ship_to_formation(formation_id, ship)
			squadron_members.append(ship)
	
	squadron_formations[formation_id] = formation_type
	is_squadron_leader = true
	
	squadron_autopilot_activated.emit(formation_id)
	return _start_autopilot_engagement(AutopilotMode.SQUADRON_AUTOPILOT)

func disengage_autopilot(reason: DisengagementReason = DisengagementReason.MANUAL_REQUEST) -> void:
	"""Disengage autopilot and return control to player"""
	if engagement_state == EngagementState.DISENGAGED:
		return
	
	_set_engagement_state(EngagementState.DISENGAGING)
	
	var reason_string: String = DisengagementReason.keys()[reason]
	
	# Stop navigation
	if navigation_controller:
		navigation_controller.interrupt_navigation("autopilot_disengagement")
	
	# Disable AI control
	if ship_controller and ship_controller.has_method("disable_ai_control"):
		ship_controller.disable_ai_control()
	
	# Clean up squadron autopilot if active
	if current_mode == AutopilotMode.SQUADRON_AUTOPILOT:
		_cleanup_squadron_autopilot()
	
	# Record performance metrics
	_record_autopilot_session()
	
	# Reset autopilot state
	current_mode = AutopilotMode.DISABLED
	_set_engagement_state(EngagementState.DISENGAGED)
	current_destination = Vector3.ZERO
	current_path.clear()
	
	autopilot_disengaged.emit(reason_string)

func toggle_autopilot_assist() -> bool:
	"""Toggle AI assistance mode while maintaining manual control"""
	if current_mode == AutopilotMode.ASSIST_ONLY:
		disengage_autopilot()
		return false
	else:
		return _start_autopilot_engagement(AutopilotMode.ASSIST_ONLY)

func set_autopilot_destination(destination: Vector3) -> bool:
	"""Update autopilot destination during flight"""
	if engagement_state != EngagementState.ENGAGED:
		return false
	
	current_destination = destination
	current_path = [destination]
	
	if navigation_controller:
		return navigation_controller.navigate_to_position(destination, WCSNavigationController.NavigationMode.AUTOPILOT)
	
	return false

func emergency_stop() -> void:
	"""Emergency autopilot stop with immediate control return"""
	_set_engagement_state(EngagementState.EMERGENCY_STOP)
	
	# Immediate stop
	if ship_controller and ship_controller.has_method("stop_movement"):
		ship_controller.stop_movement()
	
	# Force disengage
	disengage_autopilot(DisengagementReason.SYSTEM_ERROR)
	
	emergency_disengagements += 1

# Status and information interface

func get_autopilot_status() -> Dictionary:
	"""Get comprehensive autopilot status for UI display"""
	var status: Dictionary = {
		"enabled": current_mode != AutopilotMode.DISABLED,
		"mode": AutopilotMode.keys()[current_mode],
		"state": EngagementState.keys()[engagement_state],
		"destination": current_destination,
		"path_length": current_path.size(),
		"squadron_active": current_mode == AutopilotMode.SQUADRON_AUTOPILOT,
		"squadron_size": squadron_members.size(),
		"can_disengage": engagement_state == EngagementState.ENGAGED,
		"threat_detected": safety_monitor.has_active_threats() if safety_monitor else false,
		"efficiency": autopilot_efficiency,
		"session_time": Time.get_time_from_start() - autopilot_start_time if engagement_state == EngagementState.ENGAGED else 0.0
	}
	
	# Add navigation status if available
	if navigation_controller and engagement_state == EngagementState.ENGAGED:
		var nav_status: Dictionary = navigation_controller.get_autopilot_status()
		status.merge(nav_status)
	
	return status

func get_squadron_status() -> Dictionary:
	"""Get squadron autopilot status"""
	return {
		"is_leader": is_squadron_leader,
		"members": squadron_members.size(),
		"formations": squadron_formations.keys(),
		"coordination_enabled": formation_coordination_enabled
	}

func is_autopilot_engaged() -> bool:
	"""Check if autopilot is currently engaged"""
	return engagement_state == EngagementState.ENGAGED

func can_engage_autopilot() -> bool:
	"""Check if autopilot can be engaged"""
	return (engagement_state == EngagementState.DISENGAGED and 
			_validate_player_ship() and 
			not (safety_monitor and safety_monitor.has_active_threats()))

# Configuration interface

func set_threat_detection_enabled(enabled: bool) -> void:
	"""Enable/disable automatic threat detection"""
	auto_disengage_on_combat = enabled
	if safety_monitor:
		safety_monitor.set_threat_monitoring_enabled(enabled)

func set_formation_coordination_enabled(enabled: bool) -> void:
	"""Enable/disable formation coordination features"""
	formation_coordination_enabled = enabled

func set_time_compression_enabled(enabled: bool) -> void:
	"""Enable/disable time compression during autopilot"""
	time_compression_enabled = enabled

func set_navigation_speed(speed: float) -> void:
	"""Set autopilot navigation speed (0.1 to 1.0)"""
	default_navigation_speed = clamp(speed, 0.1, 1.0)

# Private implementation

func _initialize_autopilot_systems() -> void:
	"""Initialize autopilot subsystems"""
	# Find player ship
	player_ship = get_node_or_null("/root/PlayerShip")
	if not player_ship:
		player_ship = get_tree().get_first_node_in_group("player_ships")
	
	if not player_ship:
		push_error("AutopilotManager: No player ship found")
		return
	
	# Find ship controller
	ship_controller = player_ship.get_node_or_null("AIShipController")
	if not ship_controller:
		ship_controller = player_ship.get_node_or_null("ShipController")
	
	# Find or create navigation controller
	navigation_controller = player_ship.get_node_or_null("NavigationController")
	if not navigation_controller:
		navigation_controller = WCSNavigationController.new()
		navigation_controller.name = "NavigationController"
		navigation_controller.controller_id = "player_autopilot"
		player_ship.add_child(navigation_controller)
	
	# Initialize safety monitor
	safety_monitor = AutopilotSafetyMonitor.new()
	safety_monitor.threat_detection_radius = threat_detection_radius
	safety_monitor.player_ship = player_ship
	add_child(safety_monitor)
	
	# Connect safety signals
	safety_monitor.threat_detected.connect(_on_threat_detected)
	safety_monitor.collision_imminent.connect(_on_collision_imminent)
	
	# Connect navigation signals
	if navigation_controller:
		navigation_controller.navigation_completed.connect(_on_navigation_completed)
		navigation_controller.navigation_interrupted.connect(_on_navigation_interrupted)

func _start_autopilot_engagement(mode: AutopilotMode) -> bool:
	"""Start autopilot engagement process"""
	if not _validate_autopilot_engagement(current_destination):
		return false
	
	_set_engagement_state(EngagementState.ENGAGING)
	current_mode = mode
	autopilot_start_time = Time.get_time_from_start()
	
	# Configure ship controller for autopilot
	if ship_controller and ship_controller.has_method("enable_ai_control"):
		ship_controller.enable_ai_control()
	
	# Start navigation based on mode
	var navigation_success: bool = false
	match mode:
		AutopilotMode.WAYPOINT_NAV:
			navigation_success = navigation_controller.navigate_to_position(current_destination, WCSNavigationController.NavigationMode.AUTOPILOT)
		
		AutopilotMode.PATH_FOLLOWING:
			navigation_success = navigation_controller.navigate_along_path(current_path, WCSNavigationController.NavigationMode.AUTOPILOT)
		
		AutopilotMode.FORMATION_FOLLOW:
			# Formation following already configured in engage_formation_autopilot
			navigation_success = true
		
		AutopilotMode.SQUADRON_AUTOPILOT:
			# Squadron coordination already configured
			navigation_success = navigation_controller.navigate_to_position(current_destination, WCSNavigationController.NavigationMode.AUTOPILOT)
		
		AutopilotMode.ASSIST_ONLY:
			# Assistance mode doesn't take full control
			navigation_success = true
	
	if navigation_success:
		_set_engagement_state(EngagementState.ENGAGED)
		autopilot_engaged.emit(current_destination, mode)
		return true
	else:
		_set_engagement_state(EngagementState.DISENGAGED)
		current_mode = AutopilotMode.DISABLED
		push_error("AutopilotManager: Failed to start navigation for autopilot")
		return false

func _set_engagement_state(new_state: EngagementState) -> void:
	"""Set engagement state and handle transitions"""
	var old_state: EngagementState = engagement_state
	engagement_state = new_state
	
	# Handle state transitions
	match new_state:
		EngagementState.ENGAGING:
			_handle_engagement_start()
		EngagementState.ENGAGED:
			_handle_engagement_complete()
		EngagementState.DISENGAGING:
			_handle_disengagement_start()

func _update_autopilot_state(delta: float) -> void:
	"""Update autopilot state machine"""
	match engagement_state:
		EngagementState.ENGAGED:
			_update_engaged_state(delta)
		EngagementState.ENGAGING:
			_update_engaging_state(delta)
		EngagementState.DISENGAGING:
			_update_disengaging_state(delta)

func _update_engaged_state(delta: float) -> void:
	"""Update autopilot during engaged state"""
	# Update performance tracking
	total_autopilot_time += delta
	
	# Check if destination reached for single waypoint navigation
	if current_mode == AutopilotMode.WAYPOINT_NAV and navigation_controller:
		var nav_status: Dictionary = navigation_controller.get_navigation_status()
		if nav_status.get("distance_to_destination", INF) < 100.0:
			var final_position: Vector3 = player_ship.global_position if player_ship else Vector3.ZERO
			autopilot_destination_reached.emit(final_position)
			disengage_autopilot(DisengagementReason.DESTINATION_REACHED)

func _update_engaging_state(delta: float) -> void:
	"""Update autopilot during engagement transition"""
	# Check if engagement completed
	if navigation_controller and navigation_controller.current_state == WCSNavigationController.NavigationState.NAVIGATING:
		_set_engagement_state(EngagementState.ENGAGED)

func _update_disengaging_state(delta: float) -> void:
	"""Update autopilot during disengagement transition"""
	# Automatically complete disengagement after brief transition
	if Time.get_time_from_start() - handoff_start_time > 0.5:
		_set_engagement_state(EngagementState.DISENGAGED)

func _update_threat_monitoring(delta: float) -> void:
	"""Update threat detection and safety monitoring"""
	if engagement_state != EngagementState.ENGAGED or not auto_disengage_on_combat:
		return
	
	var current_time: float = Time.get_time_from_start()
	if current_time - last_threat_check_time >= threat_check_frequency:
		last_threat_check_time = current_time
		
		if safety_monitor and safety_monitor.has_active_threats():
			var threats: Array = safety_monitor.get_active_threats()
			if not threats.is_empty():
				autopilot_interrupted.emit(threats[0], "threat_detected")
				disengage_autopilot(DisengagementReason.THREAT_DETECTED)

func _update_control_handoff(delta: float) -> void:
	"""Update control handoff between autopilot and manual control"""
	if handoff_in_progress:
		var handoff_time: float = Time.get_time_from_start() - handoff_start_time
		if handoff_time > handoff_timeout:
			handoff_in_progress = false
			push_warning("AutopilotManager: Control handoff timed out")

func _update_squadron_coordination(delta: float) -> void:
	"""Update squadron autopilot coordination"""
	if current_mode != AutopilotMode.SQUADRON_AUTOPILOT:
		return
	
	# Update squadron formation integrity
	for formation_id in squadron_formations.keys():
		var formation_manager: FormationManager = get_node_or_null("/root/AIManager/FormationManager")
		if formation_manager:
			var integrity: float = formation_manager.get_formation_integrity(formation_id)
			if integrity < 0.6:  # Formation is breaking up
				push_warning("AutopilotManager: Squadron formation integrity low: ", integrity)

func _validate_autopilot_engagement(destination: Vector3) -> bool:
	"""Validate that autopilot can be engaged"""
	if not _validate_player_ship():
		return false
	
	if destination == Vector3.ZERO:
		push_warning("AutopilotManager: Invalid destination for autopilot")
		return false
	
	if engagement_state != EngagementState.DISENGAGED:
		push_warning("AutopilotManager: Autopilot already engaged or transitioning")
		return false
	
	if safety_monitor and safety_monitor.has_active_threats():
		push_warning("AutopilotManager: Cannot engage autopilot with active threats")
		return false
	
	return true

func _validate_player_ship() -> bool:
	"""Validate that player ship is available and functional"""
	if not player_ship:
		push_error("AutopilotManager: No player ship available")
		return false
	
	if ship_controller and ship_controller.has_method("is_ship_destroyed"):
		if ship_controller.is_ship_destroyed():
			push_error("AutopilotManager: Player ship is destroyed")
			return false
	
	return true

func _cleanup_squadron_autopilot() -> void:
	"""Clean up squadron autopilot formations and members"""
	var formation_manager: FormationManager = get_node_or_null("/root/AIManager/FormationManager")
	if formation_manager:
		for formation_id in squadron_formations.keys():
			formation_manager.destroy_formation(formation_id)
	
	squadron_formations.clear()
	squadron_members.clear()
	is_squadron_leader = false

func _record_autopilot_session() -> void:
	"""Record autopilot session performance metrics"""
	if engagement_state == EngagementState.ENGAGED:
		successful_navigations += 1
		
		# Calculate efficiency based on navigation controller
		if navigation_controller:
			var nav_status: Dictionary = navigation_controller.get_navigation_status()
			autopilot_efficiency = nav_status.get("navigation_efficiency", 1.0)

func _handle_engagement_start() -> void:
	"""Handle start of autopilot engagement"""
	handoff_in_progress = true
	handoff_start_time = Time.get_time_from_start()
	previous_control_mode = "manual"
	control_handoff_requested.emit("manual", "autopilot")

func _handle_engagement_complete() -> void:
	"""Handle completion of autopilot engagement"""
	handoff_in_progress = false

func _handle_disengagement_start() -> void:
	"""Handle start of autopilot disengagement"""
	handoff_in_progress = true
	handoff_start_time = Time.get_time_from_start()
	control_handoff_requested.emit("autopilot", "manual")

# Signal handlers

func _on_threat_detected(threat: Node3D, threat_level: float) -> void:
	"""Handle threat detection from safety monitor"""
	if auto_disengage_on_combat and engagement_state == EngagementState.ENGAGED:
		autopilot_interrupted.emit(threat, "threat_detected")
		disengage_autopilot(DisengagementReason.THREAT_DETECTED)

func _on_collision_imminent(obstacle: Node3D, time_to_collision: float) -> void:
	"""Handle imminent collision detection"""
	autopilot_interrupted.emit(obstacle, "collision_imminent")
	disengage_autopilot(DisengagementReason.COLLISION_IMMINENT)

func _on_navigation_completed(controller_id: String, final_position: Vector3) -> void:
	"""Handle navigation completion"""
	if controller_id == "player_autopilot":
		autopilot_destination_reached.emit(final_position)
		disengage_autopilot(DisengagementReason.DESTINATION_REACHED)

func _on_navigation_interrupted(controller_id: String, reason: String) -> void:
	"""Handle navigation interruption"""
	if controller_id == "player_autopilot":
		disengage_autopilot(DisengagementReason.NAVIGATION_FAILED)

# Debug interface

func get_debug_info() -> Dictionary:
	"""Get debug information for development"""
	return {
		"mode": AutopilotMode.keys()[current_mode],
		"state": EngagementState.keys()[engagement_state],
		"destination": current_destination,
		"path_length": current_path.size(),
		"safety_monitor_active": safety_monitor != null,
		"navigation_controller_active": navigation_controller != null,
		"squadron_members": squadron_members.size(),
		"efficiency": autopilot_efficiency,
		"total_time": total_autopilot_time,
		"successful_navigations": successful_navigations,
		"emergency_stops": emergency_disengagements
	}