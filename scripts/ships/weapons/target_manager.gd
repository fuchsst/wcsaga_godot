class_name TargetManager
extends Node

## Central target management system for ship weapon systems
## Handles target acquisition, cycling, hotkey management, and team-based filtering
## Implementation of SHIP-006 AC1: Target acquisition system

# Constants
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

# Signals for target management events
signal target_acquired(target: Node3D, target_subsystem: Node)
signal target_lost()
signal target_changed(old_target: Node3D, new_target: Node3D)
signal hotkey_target_assigned(hotkey: int, target: Node3D)
signal hotkey_target_recalled(hotkey: int, target: Node3D)

# Core target state
var current_target: Node3D = null
var current_target_subsystem: Node = null
var target_lock_time: float = 0.0
var target_acquired_time: float = 0.0

# Ship reference
var parent_ship: BaseShip
var ship_team: int = 0

# Target cycling state
var available_targets: Array[Node3D] = []
var target_cycle_index: int = -1
var last_target_scan_time: float = 0.0
var target_scan_interval: float = 0.5  # Scan for targets every 0.5 seconds

# Hotkey target management (F1-F12 keys)
var hotkey_targets: Dictionary = {}  # int -> Node3D mapping
var max_hotkey_targets: int = 12

# Target filtering settings
var target_filter_team: TeamTypes.Team = TeamTypes.Team.HOSTILE
var target_filter_range: float = 10000.0  # Maximum targeting range
var ignore_stealth_targets: bool = false
var ignore_cargo_containers: bool = false
var prioritize_fighters: bool = true

# Target validation settings
var min_target_size: float = 5.0  # Minimum target radius for targeting
var require_line_of_sight: bool = true
var max_target_age: float = 30.0  # Maximum time to keep stale targets

func _init() -> void:
	set_process(true)

func _ready() -> void:
	# Initialize hotkey targets dictionary
	for i in range(1, max_hotkey_targets + 1):
		hotkey_targets[i] = null
	
	# Start target scanning
	last_target_scan_time = Time.get_ticks_msec()

func _process(delta: float) -> void:
	if not parent_ship:
		return
	
	# Update target scanning
	var current_time: float = Time.get_ticks_msec()
	if current_time - last_target_scan_time >= (target_scan_interval * 1000.0):
		_scan_for_targets()
		last_target_scan_time = current_time
	
	# Validate current target
	if current_target:
		_validate_current_target()
	
	# Update target lock time
	if current_target:
		target_lock_time += delta

## Initialize target manager with ship reference
func initialize_target_manager(ship: BaseShip) -> bool:
	"""Initialize target manager with parent ship reference.
	
	Args:
		ship: Parent ship reference
		
	Returns:
		true if initialization successful
	"""
	if not ship:
		push_error("TargetManager: Cannot initialize without valid ship")
		return false
	
	parent_ship = ship
	ship_team = ship.team
	
	# Connect to ship signals for team changes
	if ship.has_signal("team_changed"):
		ship.team_changed.connect(_on_ship_team_changed)
	
	return true

## Scan for available targets (SHIP-006 AC1)
func _scan_for_targets() -> void:
	"""Scan for available targets using physics queries."""
	if not parent_ship or not parent_ship.physics_body:
		return
	
	var old_targets: Array[Node3D] = available_targets.duplicate()
	available_targets.clear()
	
	# Get all potential targets in range using physics query
	var space_state := parent_ship.physics_body.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	
	# Create sphere query for range detection
	var sphere := SphereShape3D.new()
	sphere.radius = target_filter_range
	query.shape = sphere
	query.transform = Transform3D(Basis(), parent_ship.global_position)
	query.collision_mask = (1 << CollisionLayers.Layer.SHIPS) | (1 << CollisionLayers.Layer.ASTEROIDS) | (1 << CollisionLayers.Layer.DEBRIS)
	
	var results := space_state.intersect_shape(query)
	
	for result in results:
		var collider := result["collider"] as Node3D
		if not collider:
			continue
		
		var potential_target := _get_target_from_collider(collider)
		if _is_valid_target(potential_target):
			available_targets.append(potential_target)
	
	# Sort targets by priority
	available_targets.sort_custom(_compare_target_priority)
	
	# Update cycle index if targets changed
	if not old_targets.is_empty() and available_targets != old_targets:
		_update_cycle_index()

## Get target node from physics collider
func _get_target_from_collider(collider: Node3D) -> Node3D:
	"""Extract target node from physics collider."""
	# Check if collider is part of a ship
	var current_node: Node = collider
	while current_node:
		if current_node is BaseShip:
			return current_node as Node3D
		current_node = current_node.get_parent()
	
	# Check for other valid target types (asteroids, stations, etc.)
	if collider.has_method("get_target_info"):
		return collider
	
	return null

## Validate if target is suitable for targeting (SHIP-006 AC1)
func _is_valid_target(target: Node3D) -> bool:
	"""Check if target meets all filtering criteria."""
	if not target or not is_instance_valid(target):
		return false
	
	# Don't target self
	if target == parent_ship:
		return false
	
	# Team filtering
	if target is BaseShip:
		var target_ship := target as BaseShip
		
		# Team-based filtering
		match target_filter_team:
			TeamTypes.Team.HOSTILE:
				if target_ship.team == ship_team:
					return false
			TeamTypes.Team.FRIENDLY:
				if target_ship.team != ship_team:
					return false
			TeamTypes.Team.ALL:
				pass  # All teams valid
		
		# Stealth filtering
		if ignore_stealth_targets and target_ship.has_method("is_stealthed"):
			if target_ship.is_stealthed():
				return false
		
		# Cargo container filtering
		if ignore_cargo_containers and target_ship.ship_class:
			if target_ship.ship_class.ship_type == ShipTypes.Type.TRANSPORT:
				return false
	
	# Size filtering
	if target.has_method("get_target_radius"):
		if target.get_target_radius() < min_target_size:
			return false
	
	# Range filtering
	var distance: float = parent_ship.global_position.distance_to(target.global_position)
	if distance > target_filter_range:
		return false
	
	# Line of sight filtering
	if require_line_of_sight and not _has_line_of_sight(target):
		return false
	
	return true

## Check line of sight to target
func _has_line_of_sight(target: Node3D) -> bool:
	"""Check if there's an unobstructed line of sight to target."""
	if not target or not parent_ship:
		return false
	
	var space_state := parent_ship.physics_body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		parent_ship.global_position,
		target.global_position,
		(1 << CollisionLayers.Layer.ASTEROIDS) | (1 << CollisionLayers.Layer.INSTALLATIONS)  # Only check for obstructions
	)
	
	var result := space_state.intersect_ray(query)
	return result.is_empty()  # No obstruction = clear line of sight

## Set current target (SHIP-006 AC1)
func set_target(target: Node3D, subsystem: Node = null) -> bool:
	"""Set current target with validation.
	
	Args:
		target: Target to set (null to clear)
		subsystem: Optional subsystem to target
		
	Returns:
		true if target was set successfully
	"""
	# Validate target
	if target and not _is_valid_target(target):
		return false
	
	var old_target: Node3D = current_target
	
	# Clear current target
	if not target:
		current_target = null
		current_target_subsystem = null
		target_lock_time = 0.0
		target_acquired_time = 0.0
		target_lost.emit()
		return true
	
	# Set new target
	current_target = target
	current_target_subsystem = subsystem
	target_lock_time = 0.0
	target_acquired_time = Time.get_ticks_msec()
	
	# Update cycle index to match new target
	if target in available_targets:
		target_cycle_index = available_targets.find(target)
	
	# Emit signals
	if old_target != target:
		if old_target:
			target_changed.emit(old_target, target)
		else:
			target_acquired.emit(target, subsystem)
	
	return true

## Cycle to next target (SHIP-006 AC1)
func cycle_target_next() -> bool:
	"""Cycle to next available target.
	
	Returns:
		true if target cycling successful
	"""
	if available_targets.is_empty():
		return false
	
	target_cycle_index = (target_cycle_index + 1) % available_targets.size()
	var next_target: Node3D = available_targets[target_cycle_index]
	
	return set_target(next_target)

## Cycle to previous target (SHIP-006 AC1)
func cycle_target_previous() -> bool:
	"""Cycle to previous available target.
	
	Returns:
		true if target cycling successful
	"""
	if available_targets.is_empty():
		return false
	
	target_cycle_index = (target_cycle_index - 1) % available_targets.size()
	if target_cycle_index < 0:
		target_cycle_index = available_targets.size() - 1
	
	var prev_target: Node3D = available_targets[target_cycle_index]
	return set_target(prev_target)

## Cycle targets filtered by team (SHIP-006 AC1)
func cycle_target_by_team(team: TeamTypes.Team, forward: bool = true) -> bool:
	"""Cycle targets filtered by specific team.
	
	Args:
		team: Team to filter by
		forward: true for next, false for previous
		
	Returns:
		true if cycling successful
	"""
	var team_targets: Array[Node3D] = []
	
	for target in available_targets:
		if target is BaseShip:
			var target_ship := target as BaseShip
			if target_ship.team == team:
				team_targets.append(target)
	
	if team_targets.is_empty():
		return false
	
	# Find current target in team list
	var current_index: int = -1
	if current_target in team_targets:
		current_index = team_targets.find(current_target)
	
	# Cycle to next/previous team target
	if forward:
		current_index = (current_index + 1) % team_targets.size()
	else:
		current_index = (current_index - 1) % team_targets.size()
		if current_index < 0:
			current_index = team_targets.size() - 1
	
	return set_target(team_targets[current_index])

## Assign target to hotkey (SHIP-006 AC1)
func assign_hotkey_target(hotkey: int, target: Node3D = null) -> bool:
	"""Assign target to hotkey slot.
	
	Args:
		hotkey: Hotkey number (1-12)
		target: Target to assign (null to clear, current target if not specified)
		
	Returns:
		true if assignment successful
	"""
	if hotkey < 1 or hotkey > max_hotkey_targets:
		return false
	
	# Use current target if none specified
	if target == null:
		target = current_target
	
	# Validate target
	if target and not _is_valid_target(target):
		return false
	
	hotkey_targets[hotkey] = target
	
	if target:
		hotkey_target_assigned.emit(hotkey, target)
	
	return true

## Recall target from hotkey (SHIP-006 AC1)
func recall_hotkey_target(hotkey: int) -> bool:
	"""Recall target from hotkey slot.
	
	Args:
		hotkey: Hotkey number (1-12)
		
	Returns:
		true if recall successful
	"""
	if hotkey < 1 or hotkey > max_hotkey_targets:
		return false
	
	var hotkey_target: Node3D = hotkey_targets.get(hotkey)
	if not hotkey_target or not _is_valid_target(hotkey_target):
		# Clear invalid hotkey
		hotkey_targets[hotkey] = null
		return false
	
	hotkey_target_recalled.emit(hotkey, hotkey_target)
	return set_target(hotkey_target)

## Get closest target by distance
func get_closest_target() -> Node3D:
	"""Get closest valid target to ship."""
	if available_targets.is_empty() or not parent_ship:
		return null
	
	var closest_target: Node3D = null
	var closest_distance: float = INF
	
	for target in available_targets:
		var distance: float = parent_ship.global_position.distance_to(target.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = target
	
	return closest_target

## Get target by priority (fighters, bombers, etc.)
func get_priority_target() -> Node3D:
	"""Get highest priority target based on threat assessment."""
	if available_targets.is_empty():
		return null
	
	# Available targets are already sorted by priority
	return available_targets[0]

## Validate current target is still valid
func _validate_current_target() -> void:
	"""Validate current target and clear if invalid."""
	if not current_target or not _is_valid_target(current_target):
		set_target(null)

## Update cycle index after target list changes
func _update_cycle_index() -> void:
	"""Update target cycle index after available targets change."""
	if current_target and current_target in available_targets:
		target_cycle_index = available_targets.find(current_target)
	else:
		target_cycle_index = -1

## Compare targets for priority sorting
func _compare_target_priority(a: Node3D, b: Node3D) -> bool:
	"""Compare two targets for priority sorting."""
	if not parent_ship:
		return false
	
	var score_a: float = _calculate_target_priority_score(a)
	var score_b: float = _calculate_target_priority_score(b)
	
	return score_a > score_b  # Higher score = higher priority

## Calculate target priority score
func _calculate_target_priority_score(target: Node3D) -> float:
	"""Calculate priority score for target selection."""
	var score: float = 0.0
	
	if not target or not parent_ship:
		return score
	
	var distance: float = parent_ship.global_position.distance_to(target.global_position)
	
	# Distance factor (closer = higher priority)
	score += (target_filter_range - distance) / target_filter_range * 30.0
	
	# Ship type priority
	if target is BaseShip:
		var target_ship := target as BaseShip
		if target_ship.ship_class:
			match target_ship.ship_class.ship_type:
				ShipTypes.Type.FIGHTER:
					score += 25.0
				ShipTypes.Type.BOMBER:
					score += 35.0  # Highest priority
				ShipTypes.Type.TRANSPORT:
					score += 10.0
				ShipTypes.Type.CRUISER:
					score += 20.0
				ShipTypes.Type.CAPITAL:
					score += 15.0
				_:
					score += 5.0
		
		# Health-based priority (damaged targets preferred)
		var health_percent: float = (target_ship.current_hull_strength / target_ship.max_hull_strength) * 100.0
		score += (100.0 - health_percent) * 0.1
		
		# Threat assessment (ships targeting us get higher priority)
		if target_ship.has_method("get_current_target"):
			var their_target: Node3D = target_ship.get_current_target()
			if their_target == parent_ship:
				score += 20.0  # High priority for ships targeting us
	
	return score

## Set target filtering options
func set_target_filter(team: TeamTypes.Team, range: float = 10000.0) -> void:
	"""Configure target filtering parameters."""
	target_filter_team = team
	target_filter_range = range

## Get current target information
func get_target_info() -> Dictionary:
	"""Get comprehensive target information."""
	var info: Dictionary = {
		"has_target": current_target != null,
		"target_name": current_target.name if current_target else "",
		"target_distance": parent_ship.global_position.distance_to(current_target.global_position) if current_target and parent_ship else 0.0,
		"target_lock_time": target_lock_time,
		"available_targets_count": available_targets.size(),
		"hotkey_targets": _get_hotkey_target_info()
	}
	
	if current_target and current_target is BaseShip:
		var target_ship := current_target as BaseShip
		info["target_team"] = target_ship.team
		info["target_health_percent"] = (target_ship.current_hull_strength / target_ship.max_hull_strength) * 100.0
		info["target_shield_percent"] = (target_ship.current_shield_strength / target_ship.max_shield_strength) * 100.0
	
	return info

## Get hotkey target information
func _get_hotkey_target_info() -> Dictionary:
	"""Get information about assigned hotkey targets."""
	var hotkey_info: Dictionary = {}
	
	for hotkey in hotkey_targets:
		var target: Node3D = hotkey_targets[hotkey]
		if target and _is_valid_target(target):
			hotkey_info[hotkey] = target.name
		else:
			hotkey_info[hotkey] = ""
	
	return hotkey_info

## Signal handlers
func _on_ship_team_changed(new_team: int) -> void:
	"""Handle ship team changes."""
	ship_team = new_team
	# Re-scan targets with new team affiliation
	_scan_for_targets()

## Debug information
func debug_info() -> String:
	"""Get debug information string."""
	var info: String = "TargetManager: "
	info += "Target:%s " % (current_target.name if current_target else "None")
	info += "Available:%d " % available_targets.size()
	info += "Hotkeys:%d " % _count_assigned_hotkeys()
	return info

func _count_assigned_hotkeys() -> int:
	"""Count number of assigned hotkey targets."""
	var count: int = 0
	for target in hotkey_targets.values():
		if target != null:
			count += 1
	return count