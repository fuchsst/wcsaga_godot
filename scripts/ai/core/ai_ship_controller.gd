class_name AIShipController
extends Node

## AIShipController integrates AI agents with ship objects for movement and control
## Provides AI-specific interface to ship systems from EPIC-009

signal ai_control_enabled()
signal ai_control_disabled()
signal movement_command_executed(command: String, target: Vector3)
signal weapon_fired(weapon_type: String, target: Node3D)
signal evasive_maneuvers_started(pattern: String)
signal formation_position_reached(position: Vector3)

@export var ship_controller: Node ## Reference to ship controller from EPIC-009
@export var ai_enabled: bool = true
@export var movement_precision: float = 10.0  # Distance tolerance for reaching targets
@export var rotation_precision: float = 0.1  # Angle tolerance in radians

var ai_agent: Node  # WCSAIAgent - avoiding circular dependency
var current_movement_target: Vector3
var current_facing_target: Vector3
var current_movement_mode: MovementMode = MovementMode.DIRECT
var is_executing_maneuver: bool = false
var maneuver_start_time: float = 0.0

enum MovementMode {
	DIRECT,           # Direct movement to target
	INTERCEPT,        # Intercept moving target
	FORMATION,        # Formation flying
	EVASIVE,          # Evasive maneuvers
	PATROL,           # Patrol pattern
	DOCK_APPROACH     # Docking approach
}

enum WeaponSystem {
	PRIMARY,
	SECONDARY,
	TERTIARY,
	ALL_WEAPONS
}

func _ready() -> void:
	# Get AI agent from parent or child
	ai_agent = get_parent()  # as WCSAIAgent - avoiding circular type reference
	if not ai_agent:
		ai_agent = get_node_or_null("WCSAIAgent")
	
	if not ai_agent:
		push_error("AIShipController: No WCSAIAgent found")
		return
	
	# Find ship controller if not assigned
	if not ship_controller:
		ship_controller = get_parent().get_parent()  # Ship -> AI -> Controller
		if not ship_controller:
			push_error("AIShipController: No ship controller found")
			return
	
	# Connect to ship controller signals if available
	_connect_ship_signals()

func _connect_ship_signals() -> void:
	if ship_controller and ship_controller.has_signal("position_reached"):
		if not ship_controller.position_reached.is_connected(_on_position_reached):
			ship_controller.position_reached.connect(_on_position_reached)
	
	if ship_controller and ship_controller.has_signal("target_hit"):
		if not ship_controller.target_hit.is_connected(_on_target_hit):
			ship_controller.target_hit.connect(_on_target_hit)

func _process(delta: float) -> void:
	if not ai_enabled or not ship_controller:
		return
	
	# Update movement execution
	_update_movement_execution(delta)
	
	# Update facing execution
	_update_facing_execution(delta)

# Movement Control Interface
func set_movement_target(target_position: Vector3, mode: MovementMode = MovementMode.DIRECT) -> void:
	current_movement_target = target_position
	current_movement_mode = mode
	
	if ship_controller and ship_controller.has_method("set_target_position"):
		ship_controller.set_target_position(target_position)
	
	movement_command_executed.emit("move_to", target_position)

func set_intercept_target(target: Node3D, lead_time: float = 1.0) -> void:
	if not target:
		return
	
	var target_velocity: Vector3 = Vector3.ZERO
	if target.has_method("get_velocity"):
		target_velocity = target.get_velocity()
	
	var intercept_position: Vector3 = calculate_intercept_position(target.global_position, target_velocity, lead_time)
	set_movement_target(intercept_position, MovementMode.INTERCEPT)

func set_formation_position(formation_leader: Node3D, offset: Vector3) -> void:
	if not formation_leader:
		return
	
	var formation_position: Vector3 = formation_leader.global_position + offset
	set_movement_target(formation_position, MovementMode.FORMATION)

func execute_evasive_maneuvers(threat_direction: Vector3, pattern: String = "barrel_roll") -> void:
	is_executing_maneuver = true
	maneuver_start_time = Time.get_time_dict_from_system()["unix"]
	current_movement_mode = MovementMode.EVASIVE
	
	var evasion_vector: Vector3 = calculate_evasion_vector(threat_direction, pattern)
	set_movement_target(global_position + evasion_vector, MovementMode.EVASIVE)
	
	evasive_maneuvers_started.emit(pattern)

func stop_movement() -> void:
	current_movement_target = global_position
	if ship_controller and ship_controller.has_method("stop"):
		ship_controller.stop()

# Rotation/Facing Control
func set_facing_target(target_position: Vector3) -> void:
	current_facing_target = target_position
	
	if ship_controller and ship_controller.has_method("set_facing_target"):
		ship_controller.set_facing_target(target_position)

func face_target(target: Node3D) -> void:
	if target:
		set_facing_target(target.global_position)

func face_movement_direction() -> void:
	var movement_direction: Vector3 = (current_movement_target - global_position).normalized()
	set_facing_target(global_position + movement_direction * 1000.0)

# Weapon Control Interface
func fire_weapons(weapon_system: WeaponSystem = WeaponSystem.PRIMARY, target: Node3D = null) -> bool:
	if not ship_controller:
		return false
	
	var success: bool = false
	var weapon_type: String = ""
	
	match weapon_system:
		WeaponSystem.PRIMARY:
			if ship_controller.has_method("fire_primary_weapons"):
				success = ship_controller.fire_primary_weapons()
				weapon_type = "primary"
		WeaponSystem.SECONDARY:
			if ship_controller.has_method("fire_secondary_weapons"):
				success = ship_controller.fire_secondary_weapons()
				weapon_type = "secondary"
		WeaponSystem.TERTIARY:
			if ship_controller.has_method("fire_tertiary_weapons"):
				success = ship_controller.fire_tertiary_weapons()
				weapon_type = "tertiary"
		WeaponSystem.ALL_WEAPONS:
			if ship_controller.has_method("fire_all_weapons"):
				success = ship_controller.fire_all_weapons()
				weapon_type = "all"
	
	if success and target:
		weapon_fired.emit(weapon_type, target)
	
	return success

func can_fire_at_target(target: Node3D, weapon_system: WeaponSystem = WeaponSystem.PRIMARY) -> bool:
	if not target or not ship_controller:
		return false
	
	var distance: float = global_position.distance_to(target.global_position)
	var weapon_range: float = get_weapon_range(weapon_system)
	
	return distance <= weapon_range and is_facing_target(target, 0.2)  # 0.2 radian tolerance

func get_weapon_range(weapon_system: WeaponSystem) -> float:
	if not ship_controller:
		return 0.0
	
	match weapon_system:
		WeaponSystem.PRIMARY:
			if ship_controller.has_method("get_primary_weapon_range"):
				return ship_controller.get_primary_weapon_range()
		WeaponSystem.SECONDARY:
			if ship_controller.has_method("get_secondary_weapon_range"):
				return ship_controller.get_secondary_weapon_range()
		WeaponSystem.TERTIARY:
			if ship_controller.has_method("get_tertiary_weapon_range"):
				return ship_controller.get_tertiary_weapon_range()
	
	return 1000.0  # Default range

# Ship State Queries
func get_ship_position() -> Vector3:
	if ship_controller and ship_controller.has_method("get_global_position"):
		return ship_controller.get_global_position()
	return global_position

func get_ship_velocity() -> Vector3:
	if ship_controller and ship_controller.has_method("get_velocity"):
		return ship_controller.get_velocity()
	return Vector3.ZERO

func get_ship_forward_vector() -> Vector3:
	if ship_controller and ship_controller.has_method("get_forward_vector"):
		return ship_controller.get_forward_vector()
	return Vector3.FORWARD

func get_ship_health() -> float:
	if ship_controller and ship_controller.has_method("get_health"):
		return ship_controller.get_health()
	return 100.0

func get_ship_health_percentage() -> float:
	if ship_controller and ship_controller.has_method("get_health_percentage"):
		return ship_controller.get_health_percentage()
	return 1.0

func get_ship_team() -> int:
	if ship_controller and ship_controller.has_method("get_team"):
		return ship_controller.get_team()
	return 0

func get_ship_mass() -> float:
	if ship_controller and ship_controller.has_method("get_mass"):
		return ship_controller.get_mass()
	return 100.0

func is_ship_destroyed() -> bool:
	if ship_controller and ship_controller.has_method("is_destroyed"):
		return ship_controller.is_destroyed()
	return false

# Navigation Utilities
func calculate_intercept_position(target_pos: Vector3, target_vel: Vector3, lead_time: float) -> Vector3:
	var relative_velocity: Vector3 = target_vel - get_ship_velocity()
	var time_to_intercept: float = lead_time
	
	# Simple intercept calculation - could be enhanced with proper ballistics
	return target_pos + target_vel * time_to_intercept

func calculate_evasion_vector(threat_direction: Vector3, pattern: String) -> Vector3:
	var evasion_vector: Vector3
	
	match pattern:
		"barrel_roll":
			evasion_vector = get_ship_forward_vector().cross(Vector3.UP) * 200.0
		"climb":
			evasion_vector = Vector3.UP * 300.0
		"dive":
			evasion_vector = Vector3.DOWN * 300.0
		"random":
			evasion_vector = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			).normalized() * 250.0
		_:
			# Default: perpendicular to threat
			evasion_vector = threat_direction.cross(Vector3.UP).normalized() * 200.0
	
	return evasion_vector

func is_facing_target(target: Node3D, tolerance: float = 0.1) -> bool:
	if not target:
		return false
	
	var direction_to_target: Vector3 = (target.global_position - global_position).normalized()
	var forward_vector: Vector3 = get_ship_forward_vector()
	var angle: float = forward_vector.angle_to(direction_to_target)
	
	return angle <= tolerance

func distance_to_target(target: Node3D) -> float:
	if not target:
		return INF
	return global_position.distance_to(target.global_position)

func is_at_position(position: Vector3, tolerance: float = -1.0) -> bool:
	var actual_tolerance: float = tolerance if tolerance > 0 else movement_precision
	return global_position.distance_to(position) <= actual_tolerance

# AI Control Management
func enable_ai_control() -> void:
	ai_enabled = true
	ai_control_enabled.emit()

func disable_ai_control() -> void:
	ai_enabled = false
	stop_movement()
	ai_control_disabled.emit()

func is_ai_control_enabled() -> bool:
	return ai_enabled

# Debug and Utility
func get_controller_status() -> Dictionary:
	return {
		"ai_enabled": ai_enabled,
		"current_target": current_movement_target,
		"movement_mode": MovementMode.keys()[current_movement_mode],
		"is_executing_maneuver": is_executing_maneuver,
		"ship_position": get_ship_position(),
		"ship_velocity": get_ship_velocity(),
		"ship_health": get_ship_health_percentage(),
		"facing_target": current_facing_target,
		"at_target": is_at_position(current_movement_target)
	}

# Private Methods
func _update_movement_execution(delta: float) -> void:
	if current_movement_mode == MovementMode.FORMATION and ai_agent.formation_leader:
		# Update formation position based on leader
		var leader_pos: Vector3 = ai_agent.formation_leader.global_position
		var formation_offset: Vector3 = _calculate_formation_offset()
		var new_formation_pos: Vector3 = leader_pos + formation_offset
		
		if current_movement_target.distance_to(new_formation_pos) > 50.0:
			set_movement_target(new_formation_pos, MovementMode.FORMATION)
	
	# Check if we've reached our target
	if is_at_position(current_movement_target):
		if current_movement_mode == MovementMode.FORMATION:
			formation_position_reached.emit(current_movement_target)

func _update_facing_execution(delta: float) -> void:
	# Auto-face movement direction if no specific facing target
	if current_facing_target == Vector3.ZERO and current_movement_target != global_position:
		face_movement_direction()

func _calculate_formation_offset() -> Vector3:
	if not ai_agent or ai_agent.formation_position < 0:
		return Vector3.ZERO
	
	# Simple formation offset calculation - would be enhanced with proper formation patterns
	var offset_distance: float = 100.0  # Standard formation spacing
	var angle: float = ai_agent.formation_position * (PI / 2)  # 90 degree increments
	
	return Vector3(
		cos(angle) * offset_distance,
		0,
		sin(angle) * offset_distance
	)

# Signal Handlers
func _on_position_reached(position: Vector3) -> void:
	if is_executing_maneuver:
		is_executing_maneuver = false
		current_movement_mode = MovementMode.DIRECT

func _on_target_hit(target: Node3D, damage: float) -> void:
	# Could be used for AI reaction to successful hits
	pass