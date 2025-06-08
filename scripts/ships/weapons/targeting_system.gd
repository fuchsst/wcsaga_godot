class_name TargetingSystem
extends Node

## Target acquisition and firing solution calculation system
## Handles lock-on mechanics, lead calculation, and accuracy modeling for weapon systems
## Implementation of SHIP-005: Targeting System component

# EPIC-002 Asset Core Integration
const WeaponData = preload("res://addons/wcs_asset_core/structures/weapon_data.gd")

# Targeting system signals
signal target_acquired(target: Node3D, target_subsystem: Node)
signal target_lost()
signal target_lock_acquired(target: Node3D)
signal target_lock_lost()
signal firing_solution_updated(solution: Dictionary)

# Ship reference
var ship: BaseShip

# Current target state (SHIP-005 AC6)
var current_target: Node3D = null
var current_target_subsystem: Node = null
var target_lock_time: float = 0.0
var target_lock_duration: float = 1.0  # Time required to acquire lock

# Target tracking state
var target_velocity: Vector3 = Vector3.ZERO
var target_acceleration: Vector3 = Vector3.ZERO
var last_target_position: Vector3 = Vector3.ZERO
var last_target_velocity: Vector3 = Vector3.ZERO
var target_tracking_history: Array[Vector3] = []
var max_tracking_history: int = 10

# Lock-on state
var has_lock: bool = false
var lock_strength: float = 0.0
var lock_acquisition_rate: float = 2.0
var lock_degradation_rate: float = 1.0

# Firing solution cache
var cached_firing_solution: Dictionary = {}
var firing_solution_cache_time: float = 0.0
var firing_solution_cache_duration: float = 0.1  # Cache for 100ms

# Targeting constraints
var max_targeting_range: float = 10000.0
var max_targeting_angle: float = 45.0  # degrees
var subsystem_targeting_enabled: bool = true

# Performance tracking
var targeting_update_frequency: float = 60.0  # Hz
var last_targeting_update: float = 0.0

func _ready() -> void:
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	# Update at specified frequency for performance
	var current_time: float = Time.get_ticks_msec()
	var time_since_update: float = current_time - last_targeting_update
	var update_interval: float = 1.0 / targeting_update_frequency
	
	if time_since_update >= update_interval:
		update_targeting(delta)
		last_targeting_update = current_time

## Initialize targeting system with ship reference (SHIP-005 AC6)
func initialize_targeting_system(parent_ship: BaseShip) -> void:
	ship = parent_ship
	
	if not ship:
		push_error("TargetingSystem: Cannot initialize without valid ship reference")
		return

## Update targeting system each frame (SHIP-005 AC6)
func update_targeting(delta: float) -> void:
	if not ship:
		return
	
	# Update target tracking
	_update_target_tracking(delta)
	
	# Update lock-on state
	_update_lock_on_state(delta)
	
	# Update firing solution cache
	_update_firing_solution_cache()

## Set current target (SHIP-005 AC6)
func set_target(target: Node3D, target_subsystem: Node = null) -> void:
	var previous_target: Node3D = current_target
	
	current_target = target
	current_target_subsystem = target_subsystem
	
	if target != previous_target:
		# Reset targeting state for new target
		_reset_targeting_state()
		
		if target:
			target_acquired.emit(target, target_subsystem)
		else:
			target_lost.emit()

## Reset targeting state for new target
func _reset_targeting_state() -> void:
	has_lock = false
	lock_strength = 0.0
	target_lock_time = 0.0
	target_velocity = Vector3.ZERO
	target_acceleration = Vector3.ZERO
	last_target_position = Vector3.ZERO
	last_target_velocity = Vector3.ZERO
	target_tracking_history.clear()
	cached_firing_solution.clear()
	firing_solution_cache_time = 0.0

## Update target tracking and motion prediction
func _update_target_tracking(delta: float) -> void:
	if not current_target or not current_target.is_inside_tree():
		if current_target:
			set_target(null)  # Clear invalid target
		return
	
	# Get current target position
	var current_position: Vector3 = current_target.global_position
	
	# Calculate target velocity
	if last_target_position != Vector3.ZERO:
		var new_velocity: Vector3 = (current_position - last_target_position) / delta
		target_velocity = target_velocity.lerp(new_velocity, 0.5)  # Smooth velocity
		
		# Calculate acceleration
		if last_target_velocity != Vector3.ZERO:
			var new_acceleration: Vector3 = (target_velocity - last_target_velocity) / delta
			target_acceleration = target_acceleration.lerp(new_acceleration, 0.3)  # Smooth acceleration
		
		last_target_velocity = target_velocity
	
	# Update tracking history
	target_tracking_history.append(current_position)
	if target_tracking_history.size() > max_tracking_history:
		target_tracking_history.pop_front()
	
	last_target_position = current_position

## Update lock-on state and strength
func _update_lock_on_state(delta: float) -> void:
	if not current_target:
		# Lose lock if no target
		if has_lock:
			has_lock = false
			lock_strength = 0.0
			target_lock_lost.emit()
		return
	
	# Check if target is within lock-on constraints
	var can_lock: bool = _can_acquire_lock()
	
	if can_lock:
		# Acquire or strengthen lock
		lock_strength += lock_acquisition_rate * delta
		lock_strength = min(lock_strength, 1.0)
		
		# Check if lock is acquired
		if not has_lock and lock_strength >= 1.0:
			has_lock = true
			target_lock_acquired.emit(current_target)
	else:
		# Lose or weaken lock
		lock_strength -= lock_degradation_rate * delta
		lock_strength = max(lock_strength, 0.0)
		
		# Check if lock is lost
		if has_lock and lock_strength <= 0.0:
			has_lock = false
			target_lock_lost.emit()

## Check if lock can be acquired on current target
func _can_acquire_lock() -> bool:
	if not current_target or not ship:
		return false
	
	# Check range constraint
	var distance: float = ship.global_position.distance_to(current_target.global_position)
	if distance > max_targeting_range:
		return false
	
	# Check angle constraint
	var ship_forward: Vector3 = -ship.global_transform.basis.z
	var target_direction: Vector3 = (current_target.global_position - ship.global_position).normalized()
	var angle: float = rad_to_deg(ship_forward.angle_to(target_direction))
	
	if angle > max_targeting_angle:
		return false
	
	# Check line of sight (basic check)
	if not _has_line_of_sight():
		return false
	
	return true

## Check if there's a clear line of sight to target
func _has_line_of_sight() -> bool:
	if not current_target or not ship:
		return false
	
	# Simple line of sight check using raycast
	var space_state: PhysicsDirectSpaceState3D = ship.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ship.global_position,
		current_target.global_position
	)
	
	# Exclude ship and target from raycast
	query.exclude = [ship.get_rid()]
	if current_target.has_method("get_rid"):
		query.exclude.append(current_target.get_rid())
	
	var result: Dictionary = space_state.intersect_ray(query)
	
	# If no intersection, line of sight is clear
	return result.is_empty()

## Update firing solution cache
func _update_firing_solution_cache() -> void:
	var current_time: float = Time.get_ticks_msec()
	
	# Check if cache needs refresh
	if current_time - firing_solution_cache_time > firing_solution_cache_duration:
		if current_target:
			cached_firing_solution = _calculate_firing_solution()
			firing_solution_cache_time = current_time
			firing_solution_updated.emit(cached_firing_solution)

## Calculate firing solution for current target (SHIP-005 AC6)
func _calculate_firing_solution() -> Dictionary:
	var solution: Dictionary = {}
	
	if not current_target or not ship:
		return solution
	
	# Basic targeting information
	solution["target_position"] = current_target.global_position
	solution["target_velocity"] = target_velocity
	solution["target_acceleration"] = target_acceleration
	solution["distance"] = ship.global_position.distance_to(current_target.global_position)
	solution["has_lock"] = has_lock
	solution["lock_strength"] = lock_strength
	
	# Calculate lead vector for moving targets
	solution["lead_vector"] = _calculate_lead_vector()
	
	# Calculate accuracy modifier based on various factors
	solution["accuracy_modifier"] = _calculate_accuracy_modifier()
	
	# Calculate time to target
	solution["time_to_target"] = _calculate_time_to_target()
	
	# Target subsystem information
	if current_target_subsystem:
		solution["target_subsystem"] = current_target_subsystem
		solution["subsystem_position"] = current_target_subsystem.global_position if current_target_subsystem.has_method("global_position") else current_target.global_position
	
	return solution

## Calculate lead vector for target interception
func _calculate_lead_vector() -> Vector3:
	if target_velocity.length() < 1.0:  # Target is essentially stationary
		return Vector3.ZERO
	
	# Basic lead calculation
	var time_to_target: float = _calculate_time_to_target()
	var predicted_target_position: Vector3 = current_target.global_position + target_velocity * time_to_target
	
	# Add acceleration prediction
	if target_acceleration.length() > 0.1:
		predicted_target_position += 0.5 * target_acceleration * time_to_target * time_to_target
	
	# Calculate lead vector
	var current_target_direction: Vector3 = (current_target.global_position - ship.global_position).normalized()
	var lead_target_direction: Vector3 = (predicted_target_position - ship.global_position).normalized()
	
	return lead_target_direction - current_target_direction

## Calculate accuracy modifier based on targeting conditions
func _calculate_accuracy_modifier() -> float:
	var accuracy: float = 1.0
	
	# Range accuracy falloff
	var distance: float = ship.global_position.distance_to(current_target.global_position)
	var range_factor: float = clamp(1.0 - (distance / max_targeting_range), 0.1, 1.0)
	accuracy *= range_factor
	
	# Lock strength affects accuracy
	accuracy *= lock_strength
	
	# Ship movement affects accuracy
	var ship_velocity: Vector3 = ship.get_linear_velocity() if ship.has_method("get_linear_velocity") else Vector3.ZERO
	var movement_factor: float = clamp(1.0 - (ship_velocity.length() / 100.0), 0.5, 1.0)
	accuracy *= movement_factor
	
	# Target movement affects accuracy
	var target_speed: float = target_velocity.length()
	var target_movement_factor: float = clamp(1.0 - (target_speed / 200.0), 0.3, 1.0)
	accuracy *= target_movement_factor
	
	# Angle to target affects accuracy
	var ship_forward: Vector3 = -ship.global_transform.basis.z
	var target_direction: Vector3 = (current_target.global_position - ship.global_position).normalized()
	var angle: float = rad_to_deg(ship_forward.angle_to(target_direction))
	var angle_factor: float = clamp(1.0 - (angle / max_targeting_angle), 0.2, 1.0)
	accuracy *= angle_factor
	
	return clamp(accuracy, 0.1, 1.0)

## Calculate time for projectile to reach target
func _calculate_time_to_target(projectile_speed: float = 300.0) -> float:
	if not current_target:
		return 0.0
	
	var distance: float = ship.global_position.distance_to(current_target.global_position)
	
	# Basic time calculation
	var basic_time: float = distance / projectile_speed
	
	# Account for target movement (iterative solution for moving targets)
	if target_velocity.length() > 1.0:
		var estimated_time: float = basic_time
		for i in range(3):  # 3 iterations for convergence
			var predicted_position: Vector3 = current_target.global_position + target_velocity * estimated_time
			var new_distance: float = ship.global_position.distance_to(predicted_position)
			estimated_time = new_distance / projectile_speed
		return estimated_time
	
	return basic_time

## Get firing solution for specific target (SHIP-005 AC6)
func get_firing_solution(target: Node3D = null) -> Dictionary:
	if target and target != current_target:
		# Calculate solution for different target
		var temp_target: Node3D = current_target
		current_target = target
		var solution: Dictionary = _calculate_firing_solution()
		current_target = temp_target
		return solution
	else:
		# Return cached solution for current target
		return cached_firing_solution.duplicate()

## Check if target lock is active
func has_target_lock() -> bool:
	return has_lock

## Get lock strength (0.0 to 1.0)
func get_lock_strength() -> float:
	return lock_strength

## Get current target
func get_current_target() -> Node3D:
	return current_target

## Get current target subsystem
func get_current_target_subsystem() -> Node:
	return current_target_subsystem

## Set targeting constraints
func set_targeting_constraints(max_range: float, max_angle: float) -> void:
	max_targeting_range = max_range
	max_targeting_angle = max_angle

## Enable/disable subsystem targeting
func set_subsystem_targeting_enabled(enabled: bool) -> void:
	subsystem_targeting_enabled = enabled
	
	# Clear subsystem target if disabled
	if not enabled and current_target_subsystem:
		current_target_subsystem = null

## Set targeting update frequency for performance control
func set_targeting_update_frequency(frequency: float) -> void:
	targeting_update_frequency = clamp(frequency, 10.0, 120.0)

## Clear current target
func clear_target() -> void:
	set_target(null)

## Get targeting status information
func get_targeting_status() -> Dictionary:
	var status: Dictionary = {}
	
	status["has_target"] = current_target != null
	status["target_name"] = current_target.name if current_target else ""
	status["has_lock"] = has_lock
	status["lock_strength"] = lock_strength
	status["target_distance"] = ship.global_position.distance_to(current_target.global_position) if current_target and ship else 0.0
	status["target_velocity"] = target_velocity
	status["target_acceleration"] = target_acceleration
	status["has_subsystem_target"] = current_target_subsystem != null
	status["subsystem_name"] = current_target_subsystem.name if current_target_subsystem else ""
	status["line_of_sight"] = _has_line_of_sight() if current_target else false
	
	return status

## Debug information
func get_debug_info() -> String:
	var info: String = "TargetingSystem Debug Info:\n"
	info += "  Target: %s\n" % (current_target.name if current_target else "None")
	info += "  Lock: %s (Strength: %.2f)\n" % [has_lock, lock_strength]
	info += "  Distance: %.1f / %.1f\n" % [ship.global_position.distance_to(current_target.global_position) if current_target and ship else 0.0, max_targeting_range]
	info += "  Target Velocity: %s\n" % target_velocity
	info += "  Accuracy: %.2f\n" % _calculate_accuracy_modifier()
	info += "  Line of Sight: %s\n" % _has_line_of_sight()
	return info