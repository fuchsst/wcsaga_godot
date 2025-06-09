class_name BeamTargetingSystem
extends Node

## SHIP-013 AC6: Beam Targeting System
## Type-specific aiming algorithms with octant selection and target tracking
## Provides intelligent targeting for all WCS beam weapon types

# EPIC-002 Asset Core Integration
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")

# Signals
signal beam_target_acquired(beam_id: String, target: Node)
signal beam_target_lost(beam_id: String, target: Node)
signal targeting_solution_found(beam_id: String, target_data: Dictionary)
signal octant_selection_changed(beam_id: String, old_octant: int, new_octant: int)
signal target_tracking_updated(beam_id: String, tracking_data: Dictionary)

# Targeting algorithms for different beam types
enum TargetingAlgorithm {
	FIXED_AIM = 0,           # Type A: Lock onto target position
	OCTANT_SWEEP = 1,        # Type B: Octant-based area coverage
	AUTO_CLOSEST = 2,        # Type C: Automatic closest target
	PREDICTIVE_CHASE = 3,    # Type D: Predictive tracking
	TURRET_DIRECT = 4        # Type E: Direct turret orientation
}

# Octant definitions for sweep targeting
enum Octant {
	FRONT_TOP_LEFT = 0,
	FRONT_TOP_RIGHT = 1,
	FRONT_BOTTOM_LEFT = 2,
	FRONT_BOTTOM_RIGHT = 3,
	REAR_TOP_LEFT = 4,
	REAR_TOP_RIGHT = 5,
	REAR_BOTTOM_LEFT = 6,
	REAR_BOTTOM_RIGHT = 7
}

# Active beam targeting
var beam_targeting_data: Dictionary = {}  # beam_id -> targeting_data
var target_tracking_cache: Dictionary = {}  # target -> tracking_info
var octant_target_lists: Dictionary = {}   # octant -> Array[targets]

# Targeting configuration
var targeting_configs: Dictionary = {
	TargetingAlgorithm.FIXED_AIM: {
		"name": "Fixed Aim",
		"requires_los": true,
		"updates_per_second": 1.0,
		"max_deviation": 5.0,
		"lock_time": 0.5
	},
	TargetingAlgorithm.OCTANT_SWEEP: {
		"name": "Octant Sweep",
		"requires_los": false,
		"updates_per_second": 10.0,
		"sweep_speed": 30.0,
		"octant_dwell_time": 0.3
	},
	TargetingAlgorithm.AUTO_CLOSEST: {
		"name": "Auto Closest",
		"requires_los": true,
		"updates_per_second": 30.0,
		"max_range": 800.0,
		"target_switch_threshold": 50.0
	},
	TargetingAlgorithm.PREDICTIVE_CHASE: {
		"name": "Predictive Chase",
		"requires_los": true,
		"updates_per_second": 20.0,
		"prediction_time": 0.5,
		"tracking_smoothing": 0.8
	},
	TargetingAlgorithm.TURRET_DIRECT: {
		"name": "Turret Direct",
		"requires_los": false,
		"updates_per_second": 5.0,
		"turret_tolerance": 2.0,
		"fixed_direction": true
	}
}

# Target selection criteria
var target_selection_criteria: Dictionary = {
	"priority_order": ["closest", "most_dangerous", "largest", "weakest"],
	"team_filtering": true,
	"subsystem_targeting": true,
	"damage_threshold": 0.1,
	"range_multiplier": 1.0
}

# Performance settings
@export var max_simultaneous_targets: int = 50
@export var targeting_update_frequency: float = 0.05  # 20Hz
@export var los_check_frequency: float = 0.1  # 10Hz for LOS checks
@export var octant_update_frequency: float = 0.2  # 5Hz for octant organization
@export var enable_targeting_debugging: bool = false

# Targeting state
var targeting_update_timer: float = 0.0
var los_check_timer: float = 0.0
var octant_update_timer: float = 0.0

# System references
var space_state: PhysicsDirectSpaceState3D = null

func _ready() -> void:
	_setup_targeting_system()
	_initialize_octant_system()

## Initialize targeting system
func initialize_targeting_system() -> void:
	space_state = get_viewport().get_world_3d().direct_space_state
	
	if enable_targeting_debugging:
		print("BeamTargetingSystem: Initialized with %d targeting algorithms" % targeting_configs.size())

## Set beam target
func set_beam_target(beam_id: String, target: Node) -> bool:
	if not target or not is_instance_valid(target):
		return false
	
	# Create or update targeting data
	if not beam_targeting_data.has(beam_id):
		beam_targeting_data[beam_id] = _create_targeting_data(beam_id)
	
	var targeting_data = beam_targeting_data[beam_id]
	var old_target = targeting_data.get("current_target", null)
	
	# Update target
	targeting_data["current_target"] = target
	targeting_data["target_lock_time"] = Time.get_ticks_msec() / 1000.0
	targeting_data["has_valid_target"] = true
	
	# Initialize target tracking
	_initialize_target_tracking(beam_id, target)
	
	# Emit signals
	if old_target != target:
		if old_target:
			beam_target_lost.emit(beam_id, old_target)
		beam_target_acquired.emit(beam_id, target)
	
	if enable_targeting_debugging:
		print("BeamTargetingSystem: Set target for beam %s: %s" % [
			beam_id, target.name if target.has_method("get") else "target"
		])
	
	return true

## Clear beam target
func clear_beam_target(beam_id: String) -> void:
	if not beam_targeting_data.has(beam_id):
		return
	
	var targeting_data = beam_targeting_data[beam_id]
	var old_target = targeting_data.get("current_target", null)
	
	targeting_data["current_target"] = null
	targeting_data["has_valid_target"] = false
	targeting_data["target_lock_time"] = 0.0
	
	if old_target:
		beam_target_lost.emit(beam_id, old_target)
	
	if enable_targeting_debugging:
		print("BeamTargetingSystem: Cleared target for beam %s" % beam_id)

## Update beam targeting
func update_beam_targeting(beam_id: String, beam_data: Dictionary) -> Dictionary:
	if not beam_targeting_data.has(beam_id):
		beam_targeting_data[beam_id] = _create_targeting_data(beam_id)
	
	var targeting_data = beam_targeting_data[beam_id]
	var beam_type = beam_data.get("beam_type", 0)
	var algorithm = _get_targeting_algorithm(beam_type)
	
	# Update targeting based on algorithm
	var targeting_result = {}
	
	match algorithm:
		TargetingAlgorithm.FIXED_AIM:
			targeting_result = _update_fixed_aim_targeting(beam_id, beam_data, targeting_data)
		
		TargetingAlgorithm.OCTANT_SWEEP:
			targeting_result = _update_octant_sweep_targeting(beam_id, beam_data, targeting_data)
		
		TargetingAlgorithm.AUTO_CLOSEST:
			targeting_result = _update_auto_closest_targeting(beam_id, beam_data, targeting_data)
		
		TargetingAlgorithm.PREDICTIVE_CHASE:
			targeting_result = _update_predictive_chase_targeting(beam_id, beam_data, targeting_data)
		
		TargetingAlgorithm.TURRET_DIRECT:
			targeting_result = _update_turret_direct_targeting(beam_id, beam_data, targeting_data)
	
	# Update targeting data
	targeting_data["last_update_time"] = Time.get_ticks_msec() / 1000.0
	targeting_data["targeting_result"] = targeting_result
	
	return targeting_result

## Find closest target within range
func find_closest_target(source_position: Vector3, max_range: float) -> Node:
	var closest_target: Node = null
	var closest_distance: float = max_range
	
	# Get all potential targets
	var potential_targets = _get_potential_targets()
	
	for target in potential_targets:
		if target and is_instance_valid(target):
			var target_position = _get_target_position(target)
			var distance = source_position.distance_to(target_position)
			
			if distance < closest_distance:
				closest_target = target
				closest_distance = distance
	
	return closest_target

## Get targeting algorithm for beam type
func _get_targeting_algorithm(beam_type: int) -> TargetingAlgorithm:
	match beam_type:
		0: return TargetingAlgorithm.FIXED_AIM        # TYPE_A_STANDARD
		1: return TargetingAlgorithm.OCTANT_SWEEP     # TYPE_B_SLASH
		2: return TargetingAlgorithm.AUTO_CLOSEST     # TYPE_C_TARGETING
		3: return TargetingAlgorithm.PREDICTIVE_CHASE # TYPE_D_CHASING
		4: return TargetingAlgorithm.TURRET_DIRECT    # TYPE_E_FIXED
		_: return TargetingAlgorithm.FIXED_AIM

## Setup targeting system
func _setup_targeting_system() -> void:
	beam_targeting_data.clear()
	target_tracking_cache.clear()
	octant_target_lists.clear()
	
	targeting_update_timer = 0.0
	los_check_timer = 0.0
	octant_update_timer = 0.0

## Initialize octant system
func _initialize_octant_system() -> void:
	# Initialize octant target lists
	for octant in Octant.values():
		octant_target_lists[octant] = []

## Create targeting data structure
func _create_targeting_data(beam_id: String) -> Dictionary:
	return {
		"beam_id": beam_id,
		"current_target": null,
		"has_valid_target": false,
		"target_lock_time": 0.0,
		"last_update_time": 0.0,
		"targeting_result": {},
		"current_octant": Octant.FRONT_TOP_LEFT,
		"octant_dwell_timer": 0.0,
		"prediction_data": {},
		"los_valid": false,
		"last_los_check": 0.0
	}

## Update fixed aim targeting (Type A)
func _update_fixed_aim_targeting(beam_id: String, beam_data: Dictionary, targeting_data: Dictionary) -> Dictionary:
	var current_target = targeting_data.get("current_target", null)
	
	if not current_target or not is_instance_valid(current_target):
		return {"has_solution": false, "reason": "no_target"}
	
	var source_position = beam_data.get("source_position", Vector3.ZERO)
	var target_position = _get_target_position(current_target)
	var distance = source_position.distance_to(target_position)
	var config = beam_data.get("config", {})
	var max_range = config.get("range", 1000.0)
	
	# Check range
	if distance > max_range:
		return {"has_solution": false, "reason": "out_of_range", "distance": distance}
	
	# Check line of sight if required
	var algorithm_config = targeting_configs[TargetingAlgorithm.FIXED_AIM]
	if algorithm_config.get("requires_los", true):
		if not _check_line_of_sight(source_position, target_position):
			return {"has_solution": false, "reason": "no_los"}
	
	# Calculate aim direction
	var aim_direction = (target_position - source_position).normalized()
	
	return {
		"has_solution": true,
		"aim_direction": aim_direction,
		"target_position": target_position,
		"target_distance": distance,
		"lock_strength": 1.0
	}

## Update octant sweep targeting (Type B)
func _update_octant_sweep_targeting(beam_id: String, beam_data: Dictionary, targeting_data: Dictionary) -> Dictionary:
	var source_position = beam_data.get("source_position", Vector3.ZERO)
	var current_direction = beam_data.get("current_direction", Vector3.FORWARD)
	var current_octant = targeting_data.get("current_octant", Octant.FRONT_TOP_LEFT)
	
	# Update octant dwell timer
	var octant_dwell_timer = targeting_data.get("octant_dwell_timer", 0.0)
	octant_dwell_timer += targeting_update_frequency
	
	var algorithm_config = targeting_configs[TargetingAlgorithm.OCTANT_SWEEP]
	var dwell_time = algorithm_config.get("octant_dwell_time", 0.3)
	
	# Check if it's time to switch octants
	if octant_dwell_timer >= dwell_time:
		var new_octant = _get_next_octant(current_octant)
		if new_octant != current_octant:
			octant_selection_changed.emit(beam_id, current_octant, new_octant)
			targeting_data["current_octant"] = new_octant
			current_octant = new_octant
		targeting_data["octant_dwell_timer"] = 0.0
	else:
		targeting_data["octant_dwell_timer"] = octant_dwell_timer
	
	# Get targets in current octant
	var octant_targets = _get_targets_in_octant(source_position, current_octant)
	var best_target = _select_best_octant_target(octant_targets, source_position)
	
	if best_target:
		var target_position = _get_target_position(best_target)
		var aim_direction = (target_position - source_position).normalized()
		
		return {
			"has_solution": true,
			"aim_direction": aim_direction,
			"target_position": target_position,
			"current_octant": current_octant,
			"targets_in_octant": octant_targets.size(),
			"sweep_target": best_target
		}
	else:
		# Aim at octant center if no targets
		var octant_direction = _get_octant_direction(current_octant)
		return {
			"has_solution": true,
			"aim_direction": octant_direction,
			"current_octant": current_octant,
			"targets_in_octant": 0,
			"sweep_mode": "area_coverage"
		}

## Update auto closest targeting (Type C)
func _update_auto_closest_targeting(beam_id: String, beam_data: Dictionary, targeting_data: Dictionary) -> Dictionary:
	var source_position = beam_data.get("source_position", Vector3.ZERO)
	var config = beam_data.get("config", {})
	var max_range = config.get("range", 800.0)
	
	# Find closest valid target
	var closest_target = find_closest_target(source_position, max_range)
	
	if closest_target:
		# Update target if different from current
		var current_target = targeting_data.get("current_target", null)
		if current_target != closest_target:
			set_beam_target(beam_id, closest_target)
		
		var target_position = _get_target_position(closest_target)
		var distance = source_position.distance_to(target_position)
		var aim_direction = (target_position - source_position).normalized()
		
		return {
			"has_solution": true,
			"aim_direction": aim_direction,
			"target_position": target_position,
			"target_distance": distance,
			"auto_target": closest_target,
			"target_priority": "closest"
		}
	else:
		return {"has_solution": false, "reason": "no_targets_in_range"}

## Update predictive chase targeting (Type D)
func _update_predictive_chase_targeting(beam_id: String, beam_data: Dictionary, targeting_data: Dictionary) -> Dictionary:
	var current_target = targeting_data.get("current_target", null)
	
	if not current_target or not is_instance_valid(current_target):
		# Try to find a new target
		var source_position = beam_data.get("source_position", Vector3.ZERO)
		var config = beam_data.get("config", {})
		var max_range = config.get("range", 1800.0)
		current_target = find_closest_target(source_position, max_range)
		
		if current_target:
			set_beam_target(beam_id, current_target)
		else:
			return {"has_solution": false, "reason": "no_targets_available"}
	
	var source_position = beam_data.get("source_position", Vector3.ZERO)
	var target_position = _get_target_position(current_target)
	var target_velocity = _get_target_velocity(current_target)
	
	# Predictive aiming
	var algorithm_config = targeting_configs[TargetingAlgorithm.PREDICTIVE_CHASE]
	var prediction_time = algorithm_config.get("prediction_time", 0.5)
	var predicted_position = target_position + (target_velocity * prediction_time)
	
	var aim_direction = (predicted_position - source_position).normalized()
	var distance = source_position.distance_to(target_position)
	
	# Update prediction data
	targeting_data["prediction_data"] = {
		"target_velocity": target_velocity,
		"predicted_position": predicted_position,
		"prediction_time": prediction_time,
		"velocity_magnitude": target_velocity.length()
	}
	
	return {
		"has_solution": true,
		"aim_direction": aim_direction,
		"target_position": predicted_position,
		"actual_target_position": target_position,
		"target_distance": distance,
		"prediction_offset": predicted_position - target_position,
		"chase_target": current_target
	}

## Update turret direct targeting (Type E)
func _update_turret_direct_targeting(beam_id: String, beam_data: Dictionary, targeting_data: Dictionary) -> Dictionary:
	# Fixed beams fire directly from turret orientation
	var turret_node = beam_data.get("turret_node", null)
	var fixed_direction = Vector3.FORWARD
	
	if turret_node and is_instance_valid(turret_node):
		# Use turret's forward direction
		fixed_direction = -turret_node.transform.basis.z
	else:
		# Use beam's initial direction
		fixed_direction = beam_data.get("current_direction", Vector3.FORWARD)
	
	return {
		"has_solution": true,
		"aim_direction": fixed_direction,
		"fixed_direction": true,
		"turret_orientation": turret_node.transform.basis if turret_node else Basis.IDENTITY
	}

## Initialize target tracking
func _initialize_target_tracking(beam_id: String, target: Node) -> void:
	var target_id = _get_target_id(target)
	
	if not target_tracking_cache.has(target_id):
		target_tracking_cache[target_id] = {
			"target": target,
			"last_position": _get_target_position(target),
			"last_velocity": Vector3.ZERO,
			"position_history": [],
			"tracking_beams": [],
			"last_update": Time.get_ticks_msec() / 1000.0
		}
	
	var tracking_info = target_tracking_cache[target_id]
	if beam_id not in tracking_info["tracking_beams"]:
		tracking_info["tracking_beams"].append(beam_id)

## Get potential targets
func _get_potential_targets() -> Array[Node]:
	var targets: Array[Node] = []
	
	# Get all ships in the scene
	var all_ships = get_tree().get_nodes_in_group("ships")
	for ship in all_ships:
		if ship and is_instance_valid(ship) and _is_valid_target(ship):
			targets.append(ship)
	
	return targets

## Check if node is valid target
func _is_valid_target(target: Node) -> bool:
	# Check if target has required properties
	if not target.has_method("get_team") and not target.has_property("team"):
		return false
	
	# Check if target is alive/active
	if target.has_method("is_alive") and not target.is_alive():
		return false
	
	# Additional target validation can be added here
	return true

## Get target position
func _get_target_position(target: Node) -> Vector3:
	if target.has_method("get_global_position"):
		return target.get_global_position()
	elif target.has_property("global_position"):
		return target.global_position
	elif target.has_property("position"):
		return target.position
	else:
		return Vector3.ZERO

## Get target velocity
func _get_target_velocity(target: Node) -> Vector3:
	if target.has_property("linear_velocity"):
		return target.linear_velocity
	elif target.has_property("velocity"):
		return target.velocity
	else:
		return Vector3.ZERO

## Get target identifier
func _get_target_id(target: Node) -> String:
	if target.has_method("get_instance_id"):
		return str(target.get_instance_id())
	else:
		return target.name

## Check line of sight
func _check_line_of_sight(from_position: Vector3, to_position: Vector3) -> bool:
	if not space_state:
		return true  # Assume clear LOS if no physics state
	
	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.from = from_position
	ray_query.to = to_position
	ray_query.collision_mask = 1  # Basic collision mask
	
	var result = space_state.intersect_ray(ray_query)
	return result.is_empty()  # Clear LOS if no collision

## Octant management
func _get_next_octant(current_octant: Octant) -> Octant:
	# Cycle through octants in order
	var next_value = (current_octant + 1) % 8
	return next_value as Octant

func _get_octant_direction(octant: Octant) -> Vector3:
	# Return unit vector for octant center direction
	match octant:
		Octant.FRONT_TOP_LEFT:
			return Vector3(-0.5, 0.5, 1.0).normalized()
		Octant.FRONT_TOP_RIGHT:
			return Vector3(0.5, 0.5, 1.0).normalized()
		Octant.FRONT_BOTTOM_LEFT:
			return Vector3(-0.5, -0.5, 1.0).normalized()
		Octant.FRONT_BOTTOM_RIGHT:
			return Vector3(0.5, -0.5, 1.0).normalized()
		Octant.REAR_TOP_LEFT:
			return Vector3(-0.5, 0.5, -1.0).normalized()
		Octant.REAR_TOP_RIGHT:
			return Vector3(0.5, 0.5, -1.0).normalized()
		Octant.REAR_BOTTOM_LEFT:
			return Vector3(-0.5, -0.5, -1.0).normalized()
		Octant.REAR_BOTTOM_RIGHT:
			return Vector3(0.5, -0.5, -1.0).normalized()
		_:
			return Vector3.FORWARD

func _get_targets_in_octant(source_position: Vector3, octant: Octant) -> Array[Node]:
	var octant_targets: Array[Node] = []
	var octant_direction = _get_octant_direction(octant)
	
	var potential_targets = _get_potential_targets()
	for target in potential_targets:
		var target_position = _get_target_position(target)
		var to_target = (target_position - source_position).normalized()
		
		# Check if target is in the octant cone
		var dot_product = to_target.dot(octant_direction)
		if dot_product > 0.5:  # ~60 degree cone
			octant_targets.append(target)
	
	return octant_targets

func _select_best_octant_target(targets: Array[Node], source_position: Vector3) -> Node:
	if targets.is_empty():
		return null
	
	# Select closest target in octant
	var best_target: Node = null
	var closest_distance: float = INF
	
	for target in targets:
		var distance = source_position.distance_to(_get_target_position(target))
		if distance < closest_distance:
			best_target = target
			closest_distance = distance
	
	return best_target

## Get targeting statistics
func get_targeting_statistics() -> Dictionary:
	return {
		"active_beams": beam_targeting_data.size(),
		"tracked_targets": target_tracking_cache.size(),
		"octant_targets": octant_target_lists.values().size(),
		"update_frequency": 1.0 / targeting_update_frequency
	}

## Process frame updates
func _process(delta: float) -> void:
	targeting_update_timer += delta
	los_check_timer += delta
	octant_update_timer += delta
	
	# Update targeting data
	if targeting_update_timer >= targeting_update_frequency:
		targeting_update_timer = 0.0
		_update_all_beam_targeting()
	
	# Update octant organization
	if octant_update_timer >= octant_update_frequency:
		octant_update_timer = 0.0
		_update_octant_organization()

## Update all beam targeting
func _update_all_beam_targeting() -> void:
	for beam_id in beam_targeting_data.keys():
		# This would be called by BeamWeaponSystem with beam_data
		pass

## Update octant organization
func _update_octant_organization() -> void:
	# Reorganize targets into octants
	for octant in Octant.values():
		octant_target_lists[octant].clear()
	
	var all_targets = _get_potential_targets()
	for target in all_targets:
		var target_position = _get_target_position(target)
		var octant = _position_to_octant(target_position)
		octant_target_lists[octant].append(target)

## Convert position to octant
func _position_to_octant(position: Vector3) -> Octant:
	var x_positive = position.x >= 0
	var y_positive = position.y >= 0
	var z_positive = position.z >= 0
	
	if z_positive:  # Front octants
		if y_positive:
			return Octant.FRONT_TOP_RIGHT if x_positive else Octant.FRONT_TOP_LEFT
		else:
			return Octant.FRONT_BOTTOM_RIGHT if x_positive else Octant.FRONT_BOTTOM_LEFT
	else:  # Rear octants
		if y_positive:
			return Octant.REAR_TOP_RIGHT if x_positive else Octant.REAR_TOP_LEFT
		else:
			return Octant.REAR_BOTTOM_RIGHT if x_positive else Octant.REAR_BOTTOM_LEFT