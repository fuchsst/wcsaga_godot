class_name LockOnManager
extends Node

## Lock-on acquisition and tracking manager for HUD-007
## Manages the process of acquiring and maintaining weapon locks on targets
## Handles different lock types and timing requirements

# Lock types for different weapon systems
enum LockType {
	NONE,			# No lock required
	ASPECT,			# Aspect lock (angle-based)
	MISSILE,		# Missile lock (distance and angle)
	BEAM,			# Beam weapon lock (continuous)
	TORPEDO,		# Torpedo lock (heavy missile)
	SPECIAL			# Special weapon lock
}

# Lock acquisition states
enum AcquisitionState {
	INACTIVE,		# Not attempting lock
	INITIALIZING,	# Starting lock sequence
	ACQUIRING,		# Acquiring lock
	MAINTAINING,	# Maintaining existing lock
	LOST,			# Lock lost, attempting reacquisition
	FAILED			# Lock acquisition failed
}

# Signals for lock state changes
signal lock_state_changed(new_state: int)
signal lock_progress_updated(progress: float)
signal lock_acquired(target: Node3D, lock_type: LockType)
signal lock_lost(target: Node3D, reason: String)
signal lock_strength_changed(strength: float)

# Lock configuration
@export_group("Lock Configuration")
@export var lock_type: LockType = LockType.ASPECT
@export var lock_acquisition_time: float = 2.0  # Time to acquire lock
@export var lock_maintain_time: float = 0.5     # Time to maintain after target loss
@export var max_lock_angle: float = 30.0        # Maximum angle for lock (degrees)
@export var max_lock_distance: float = 5000.0   # Maximum distance for lock (meters)
@export var min_lock_distance: float = 50.0     # Minimum distance for lock (meters)

# Lock state
var current_target: Node3D = null
var acquisition_state: AcquisitionState = AcquisitionState.INACTIVE
var lock_progress: float = 0.0
var lock_strength: float = 0.0
var lock_start_time: float = 0.0
var lock_lost_time: float = 0.0

# Lock validation
var target_angle: float = 0.0
var target_distance: float = 0.0
var target_velocity: Vector3 = Vector3.ZERO
var relative_velocity: Vector3 = Vector3.ZERO

# Ship reference
var player_ship: Node3D = null
var weapon_manager: Node = null

# Performance optimization
var update_frequency: float = 30.0  # Hz
var last_update_time: float = 0.0

func _ready() -> void:
	set_process(true)
	_initialize_lock_manager()

## Initialize lock-on manager
func initialize_lock_on_manager() -> bool:
	"""Initialize lock-on manager with ship reference."""
	# Get player ship reference
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		player_ship = player_nodes[0]
		
		# Get weapon manager
		if player_ship.has_method("get_weapon_manager"):
			weapon_manager = player_ship.get_weapon_manager()
		else:
			weapon_manager = player_ship.get_node_or_null("WeaponManager")
		
		return true
	
	push_error("LockOnManager: Cannot initialize without player ship")
	return false

## Initialize internal state
func _initialize_lock_manager() -> void:
	"""Initialize internal lock manager state."""
	acquisition_state = AcquisitionState.INACTIVE
	lock_progress = 0.0
	lock_strength = 0.0
	current_target = null

## Main process loop
func _process(delta: float) -> void:
	"""Process lock acquisition and maintenance."""
	var current_time: float = Time.get_ticks_msec() / 1000.0
	
	# Limit update frequency for performance
	if current_time - last_update_time < (1.0 / update_frequency):
		return
	
	last_update_time = current_time
	
	# Update lock state machine
	_update_lock_state_machine(delta)
	
	# Update lock validation if we have a target
	if current_target and is_instance_valid(current_target):
		_update_lock_validation()
	
	# Update lock progress and strength
	_update_lock_metrics(delta)

## Update lock state machine
func _update_lock_state_machine(delta: float) -> void:
	"""Update the lock acquisition state machine."""
	match acquisition_state:
		AcquisitionState.INACTIVE:
			_handle_inactive_state()
		
		AcquisitionState.INITIALIZING:
			_handle_initializing_state(delta)
		
		AcquisitionState.ACQUIRING:
			_handle_acquiring_state(delta)
		
		AcquisitionState.MAINTAINING:
			_handle_maintaining_state(delta)
		
		AcquisitionState.LOST:
			_handle_lost_state(delta)
		
		AcquisitionState.FAILED:
			_handle_failed_state(delta)

## Handle inactive state
func _handle_inactive_state() -> void:
	"""Handle inactive lock state."""
	# Check if we should start lock acquisition
	if current_target and is_instance_valid(current_target):
		if _is_target_lockable():
			_start_lock_acquisition()

## Handle initializing state
func _handle_initializing_state(delta: float) -> void:
	"""Handle lock initialization state."""
	# Check if target is still valid
	if not current_target or not is_instance_valid(current_target):
		_fail_lock_acquisition("Target lost during initialization")
		return
	
	# Check if target is still lockable
	if not _is_target_lockable():
		_fail_lock_acquisition("Target no longer lockable")
		return
	
	# Transition to acquiring
	_transition_to_acquiring()

## Handle acquiring state
func _handle_acquiring_state(delta: float) -> void:
	"""Handle lock acquisition state."""
	# Check if target is still valid and lockable
	if not current_target or not is_instance_valid(current_target):
		_lose_lock("Target lost during acquisition")
		return
	
	if not _is_target_lockable():
		_lose_lock("Target moved out of lock parameters")
		return
	
	# Update lock progress
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var elapsed_time: float = current_time - lock_start_time
	
	lock_progress = clampf(elapsed_time / lock_acquisition_time, 0.0, 1.0)
	lock_progress_updated.emit(lock_progress)
	
	# Check if lock is acquired
	if lock_progress >= 1.0:
		_complete_lock_acquisition()

## Handle maintaining state
func _handle_maintaining_state(delta: float) -> void:
	"""Handle lock maintenance state."""
	# Check if target is still valid
	if not current_target or not is_instance_valid(current_target):
		_lose_lock("Target destroyed")
		return
	
	# Check if target is still in lock parameters
	if not _is_target_lockable():
		_lose_lock("Target moved out of lock range")
		return
	
	# Update lock strength based on target tracking quality
	_update_lock_strength()

## Handle lost state
func _handle_lost_state(delta: float) -> void:
	"""Handle lock lost state - attempt reacquisition."""
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var time_since_lost: float = current_time - lock_lost_time
	
	# Check if we should give up reacquisition
	if time_since_lost > lock_maintain_time:
		_fail_lock_acquisition("Reacquisition timeout")
		return
	
	# Check if target is back in lock parameters
	if current_target and is_instance_valid(current_target) and _is_target_lockable():
		_start_lock_acquisition()

## Handle failed state
func _handle_failed_state(delta: float) -> void:
	"""Handle lock failure state."""
	# Reset to inactive after brief delay
	lock_progress = 0.0
	lock_strength = 0.0
	_transition_to_inactive()

## Start lock acquisition process
func _start_lock_acquisition() -> void:
	"""Start the lock acquisition process."""
	acquisition_state = AcquisitionState.INITIALIZING
	lock_start_time = Time.get_ticks_msec() / 1000.0
	lock_progress = 0.0
	lock_strength = 0.0
	
	lock_state_changed.emit(acquisition_state)

## Transition to acquiring state
func _transition_to_acquiring() -> void:
	"""Transition to acquiring state."""
	acquisition_state = AcquisitionState.ACQUIRING
	lock_start_time = Time.get_ticks_msec() / 1000.0
	
	lock_state_changed.emit(acquisition_state)

## Complete lock acquisition
func _complete_lock_acquisition() -> void:
	"""Complete the lock acquisition process."""
	acquisition_state = AcquisitionState.MAINTAINING
	lock_progress = 1.0
	lock_strength = 1.0
	
	lock_state_changed.emit(acquisition_state)
	lock_acquired.emit(current_target, lock_type)

## Lose lock
func _lose_lock(reason: String) -> void:
	"""Lose the current lock."""
	var previous_state: AcquisitionState = acquisition_state
	
	acquisition_state = AcquisitionState.LOST
	lock_lost_time = Time.get_ticks_msec() / 1000.0
	
	# Only emit lock lost if we had a complete lock
	if previous_state == AcquisitionState.MAINTAINING:
		lock_lost.emit(current_target, reason)
	
	lock_state_changed.emit(acquisition_state)

## Fail lock acquisition
func _fail_lock_acquisition(reason: String) -> void:
	"""Fail the lock acquisition process."""
	acquisition_state = AcquisitionState.FAILED
	lock_progress = 0.0
	lock_strength = 0.0
	
	lock_state_changed.emit(acquisition_state)

## Transition to inactive state
func _transition_to_inactive() -> void:
	"""Transition to inactive state."""
	acquisition_state = AcquisitionState.INACTIVE
	current_target = null
	lock_progress = 0.0
	lock_strength = 0.0
	
	lock_state_changed.emit(acquisition_state)

## Check if target is lockable
func _is_target_lockable() -> bool:
	"""Check if current target meets lock requirements."""
	if not current_target or not player_ship:
		return false
	
	# Check distance requirements
	if target_distance < min_lock_distance or target_distance > max_lock_distance:
		return false
	
	# Check angle requirements
	if target_angle > deg_to_rad(max_lock_angle):
		return false
	
	# Check weapon-specific requirements
	match lock_type:
		LockType.ASPECT:
			return _check_aspect_lock_requirements()
		LockType.MISSILE:
			return _check_missile_lock_requirements()
		LockType.BEAM:
			return _check_beam_lock_requirements()
		LockType.TORPEDO:
			return _check_torpedo_lock_requirements()
		LockType.SPECIAL:
			return _check_special_lock_requirements()
	
	return true

## Check aspect lock requirements
func _check_aspect_lock_requirements() -> bool:
	"""Check aspect lock specific requirements."""
	# Aspect locks require target to be in front arc
	return target_angle < deg_to_rad(45.0)

## Check missile lock requirements
func _check_missile_lock_requirements() -> bool:
	"""Check missile lock specific requirements."""
	# Missiles need clear line of sight and reasonable closure rate
	if not _has_clear_line_of_sight():
		return false
	
	# Check closure rate (not flying away too fast)
	var closure_rate: float = -relative_velocity.dot(
		(current_target.global_position - player_ship.global_position).normalized()
	)
	
	return closure_rate > -100.0  # Not flying away faster than 100 m/s

## Check beam lock requirements
func _check_beam_lock_requirements() -> bool:
	"""Check beam weapon lock requirements."""
	# Beam weapons need very precise angle and stable target
	if target_angle > deg_to_rad(15.0):
		return false
	
	# Check target velocity stability
	return target_velocity.length() < 200.0

## Check torpedo lock requirements
func _check_torpedo_lock_requirements() -> bool:
	"""Check torpedo lock requirements."""
	# Torpedoes need longer range and larger targets
	if target_distance < 500.0 or target_distance > 8000.0:
		return false
	
	# Check if target is large enough (ships, capital ships)
	if current_target.has_method("get_ship_size"):
		var ship_size = current_target.get_ship_size()
		return ship_size >= ShipSizes.Size.CORVETTE
	
	return true

## Check special weapon lock requirements
func _check_special_lock_requirements() -> bool:
	"""Check special weapon lock requirements."""
	# Special weapons have unique requirements
	return true

## Check clear line of sight
func _has_clear_line_of_sight() -> bool:
	"""Check if there's a clear line of sight to target."""
	if not player_ship or not current_target:
		return false
	
	var space_state := player_ship.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		player_ship.global_position,
		current_target.global_position,
		(1 << CollisionLayers.Layer.ASTEROIDS) | (1 << CollisionLayers.Layer.DEBRIS)
	)
	
	var result := space_state.intersect_ray(query)
	return result.is_empty()

## Update lock validation parameters
func _update_lock_validation() -> void:
	"""Update lock validation parameters."""
	if not player_ship or not current_target:
		return
	
	# Calculate distance
	var target_position: Vector3 = current_target.global_position
	var player_position: Vector3 = player_ship.global_position
	target_distance = target_position.distance_to(player_position)
	
	# Calculate angle
	var direction_to_target: Vector3 = (target_position - player_position).normalized()
	var player_forward: Vector3 = -player_ship.global_transform.basis.z
	target_angle = acos(player_forward.dot(direction_to_target))
	
	# Calculate velocities
	if current_target.has_method("get_velocity"):
		target_velocity = current_target.get_velocity()
	
	if player_ship.has_method("get_velocity"):
		var player_velocity: Vector3 = player_ship.get_velocity()
		relative_velocity = target_velocity - player_velocity

## Update lock metrics
func _update_lock_metrics(delta: float) -> void:
	"""Update lock progress and strength metrics."""
	# Lock strength depends on how well we're tracking the target
	if acquisition_state == AcquisitionState.MAINTAINING:
		_update_lock_strength()
	elif acquisition_state in [AcquisitionState.LOST, AcquisitionState.FAILED]:
		lock_strength = maxf(0.0, lock_strength - delta * 2.0)  # Decay strength
	
	# Emit strength changes
	lock_strength_changed.emit(lock_strength)

## Update lock strength
func _update_lock_strength() -> void:
	"""Update lock strength based on tracking quality."""
	var base_strength: float = 1.0
	
	# Reduce strength based on angle deviation
	var angle_factor: float = 1.0 - (target_angle / deg_to_rad(max_lock_angle))
	base_strength *= clampf(angle_factor, 0.0, 1.0)
	
	# Reduce strength based on distance
	var optimal_distance: float = max_lock_distance * 0.5
	var distance_factor: float = 1.0 - abs(target_distance - optimal_distance) / optimal_distance
	base_strength *= clampf(distance_factor, 0.0, 1.0)
	
	# Reduce strength based on relative velocity
	var velocity_factor: float = 1.0 - clampf(relative_velocity.length() / 500.0, 0.0, 0.5)
	base_strength *= velocity_factor
	
	lock_strength = clampf(base_strength, 0.0, 1.0)

## Public interface methods

## Set target for lock acquisition
func set_target(target: Node3D) -> bool:
	"""Set target for lock acquisition."""
	if target == current_target:
		return true
	
	# Clear current lock if changing targets
	if current_target:
		_transition_to_inactive()
	
	current_target = target
	
	if target and is_instance_valid(target):
		# Start lock acquisition process
		if _is_target_lockable():
			_start_lock_acquisition()
			return true
		else:
			return false
	else:
		_transition_to_inactive()
		return true

## Clear current target
func clear_target() -> void:
	"""Clear current target and stop lock acquisition."""
	_transition_to_inactive()

## Set lock type
func set_lock_type(type: LockType) -> void:
	"""Set the type of lock to acquire."""
	if lock_type != type:
		lock_type = type
		
		# Restart lock acquisition if active
		if acquisition_state != AcquisitionState.INACTIVE and current_target:
			_start_lock_acquisition()

## Configure lock parameters
func configure_lock_parameters(
	acquisition_time: float,
	maintain_time: float,
	max_angle: float,
	max_distance: float,
	min_distance: float = 50.0
) -> void:
	"""Configure lock acquisition parameters."""
	lock_acquisition_time = acquisition_time
	lock_maintain_time = maintain_time
	max_lock_angle = max_angle
	max_lock_distance = max_distance
	min_lock_distance = min_distance

## Update lock status with external data
func update_lock_status(lock_data: Dictionary) -> void:
	"""Update lock status with external weapon system data."""
	if lock_data.has("target"):
		set_target(lock_data["target"])
	
	if lock_data.has("lock_type"):
		set_lock_type(lock_data["lock_type"])
	
	if lock_data.has("acquisition_time"):
		lock_acquisition_time = lock_data["acquisition_time"]

## Get current lock status
func get_lock_status() -> Dictionary:
	"""Get current lock status information."""
	return {
		"acquisition_state": acquisition_state,
		"lock_type": lock_type,
		"lock_progress": lock_progress,
		"lock_strength": lock_strength,
		"target": current_target,
		"target_distance": target_distance,
		"target_angle": rad_to_deg(target_angle),
		"has_line_of_sight": _has_clear_line_of_sight() if current_target else false
	}

## Get lock progress (0.0 to 1.0)
func get_lock_progress() -> float:
	"""Get current lock acquisition progress."""
	return lock_progress

## Get lock strength (0.0 to 1.0)
func get_lock_strength() -> float:
	"""Get current lock strength."""
	return lock_strength

## Check if lock is active
func has_lock() -> bool:
	"""Check if we currently have an active lock."""
	return acquisition_state == AcquisitionState.MAINTAINING

## Check if acquiring lock
func is_acquiring_lock() -> bool:
	"""Check if currently acquiring lock."""
	return acquisition_state in [AcquisitionState.INITIALIZING, AcquisitionState.ACQUIRING]

## Check if lock is lost
func is_lock_lost() -> bool:
	"""Check if lock was lost and attempting reacquisition."""
	return acquisition_state == AcquisitionState.LOST

## Get debug information
func get_debug_info() -> String:
	"""Get debug information string."""
	var info: String = "LockOnManager: "
	info += "State: %s " % AcquisitionState.keys()[acquisition_state]
	info += "Type: %s " % LockType.keys()[lock_type]
	info += "Progress: %.2f " % lock_progress
	info += "Strength: %.2f " % lock_strength
	if current_target:
		info += "Target: %s " % current_target.name
		info += "Distance: %.0fm " % target_distance
		info += "Angle: %.1f° " % rad_to_deg(target_angle)
	return info
