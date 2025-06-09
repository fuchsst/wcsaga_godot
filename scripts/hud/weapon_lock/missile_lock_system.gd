class_name MissileLockSystem
extends Node

## Specialized missile lock-on tracking system for HUD-007
## Handles missile-specific lock requirements including seeker head acquisition,
## target painting, and multi-stage lock processes for different missile types

# Missile types with different lock requirements
enum MissileType {
	HEATSEEKER,		# Infrared guided missiles
	RADAR_GUIDED,	# Radar guided missiles
	TARGET_PAINTER,	# Laser guided missiles
	DUMBFIRE,		# Unguided missiles (no lock needed)
	SWARM,			# Multiple small missiles
	TORPEDO,		# Heavy guided torpedoes
	SPECIAL			# Special missile types (EMP, etc.)
}

# Missile lock stages
enum LockStage {
	INACTIVE,		# No lock attempt
	SEEKER_INIT,	# Initializing seeker head
	TARGET_PAINT,	# Painting target (for painter missiles)
	ACQUIRING,		# Acquiring lock
	LOCKED,			# Target locked
	TRACKING,		# Maintaining lock while tracking
	LOST,			# Lock lost during tracking
	LAUNCHED		# Missile launched, no longer tracking
}

# Seeker head status
enum SeekerStatus {
	OFFLINE,		# Seeker not active
	INITIALIZING,	# Seeker starting up
	SEARCHING,		# Searching for targets
	TRACKING,		# Tracking specific target
	LOCKED,			# Locked onto target
	JAMMED,			# Signal jammed
	FAILED			# Seeker failed
}

# Signals for missile lock events
signal missile_lock_acquired(missile_type: MissileType, target: Node3D)
signal missile_lock_lost(missile_type: MissileType, target: Node3D, reason: String)
signal seeker_status_changed(new_status: SeekerStatus)
signal target_painting_started(target: Node3D)
signal target_painting_completed(target: Node3D)
signal launch_window_opened(missile_type: MissileType)
signal launch_window_closed(missile_type: MissileType)

# Missile lock configuration
@export_group("Missile Configuration")
@export var missile_type: MissileType = MissileType.HEATSEEKER
@export var seeker_acquisition_time: float = 1.5    # Time to acquire lock
@export var lock_maintain_time: float = 0.8         # Time to maintain lock
@export var max_lock_angle: float = 25.0            # Maximum lock angle (degrees)
@export var max_lock_range: float = 4000.0          # Maximum lock range (meters)
@export var min_lock_range: float = 100.0           # Minimum lock range (meters)
@export var seeker_cone_angle: float = 15.0         # Seeker cone half-angle (degrees)

# Target painting settings (for painter missiles)
@export_group("Target Painting")
@export var requires_target_painting: bool = false
@export var paint_acquisition_time: float = 2.0
@export var paint_maintain_time: float = 1.0
@export var paint_max_range: float = 3000.0
@export var paint_beam_power: float = 1.0

# Heat signature settings (for heat seekers)
@export_group("Heat Signature")
@export var heat_signature_threshold: float = 0.3   # Minimum heat to lock
@export var background_heat_noise: float = 0.1      # Background heat interference
@export var heat_bloom_range: float = 500.0         # Range where heat blooms interfere

# Radar settings (for radar guided)
@export_group("Radar Guidance")
@export var radar_cross_section_threshold: float = 0.5
@export var radar_jamming_resistance: float = 0.7
@export var radar_doppler_sensitivity: bool = true

# Current lock state
var current_target: Node3D = null
var lock_stage: LockStage = LockStage.INACTIVE
var seeker_status: SeekerStatus = SeekerStatus.OFFLINE
var lock_strength: float = 0.0
var lock_progress: float = 0.0
var stage_start_time: float = 0.0

# Target data
var target_heat_signature: float = 0.0
var target_radar_signature: float = 0.0
var target_distance: float = 0.0
var target_angle: float = 0.0
var target_velocity: Vector3 = Vector3.ZERO
var target_is_painted: bool = false

# Missile seeker head simulation
var seeker_gimbal_angle: Vector2 = Vector2.ZERO    # Pitch/yaw angles
var seeker_tracking_error: float = 0.0
var seeker_noise_level: float = 0.0
var seeker_fov_current: float = 0.0

# Launch window calculation
var launch_window_open: bool = false
var launch_window_quality: float = 0.0
var optimal_launch_range: float = 0.0

# References
var player_ship: Node3D = null
var weapon_manager: Node = null
var target_painter: Node = null  # For painter missiles

# Performance optimization
var update_frequency: float = 30.0  # Hz
var last_update_time: float = 0.0

func _ready() -> void:
	set_process(true)
	_initialize_missile_lock_system()

## Initialize missile lock system
func _initialize_missile_lock_system() -> void:
	"""Initialize missile lock system."""
	# Get player ship reference
	if GameState.player_ship:
		player_ship = GameState.player_ship
		
		# Get weapon manager
		if player_ship.has_method("get_weapon_manager"):
			weapon_manager = player_ship.get_weapon_manager()
		
		# Initialize seeker based on missile type
		_initialize_seeker_head()
	
	# Set initial state
	lock_stage = LockStage.INACTIVE
	seeker_status = SeekerStatus.OFFLINE

## Initialize seeker head for missile type
func _initialize_seeker_head() -> void:
	"""Initialize seeker head parameters based on missile type."""
	match missile_type:
		MissileType.HEATSEEKER:
			seeker_fov_current = seeker_cone_angle
			requires_target_painting = false
			
		MissileType.RADAR_GUIDED:
			seeker_fov_current = seeker_cone_angle * 0.8  # Narrower FOV
			requires_target_painting = false
			
		MissileType.TARGET_PAINTER:
			seeker_fov_current = seeker_cone_angle * 0.5  # Very narrow FOV
			requires_target_painting = true
			
		MissileType.TORPEDO:
			seeker_fov_current = seeker_cone_angle * 1.5  # Wider FOV
			requires_target_painting = false
			
		MissileType.DUMBFIRE:
			# No seeker head needed
			seeker_status = SeekerStatus.OFFLINE
			return
			
		MissileType.SWARM:
			seeker_fov_current = seeker_cone_angle * 2.0  # Very wide FOV
			requires_target_painting = false

## Main process loop
func _process(delta: float) -> void:
	"""Process missile lock system updates."""
	var current_time: float = Time.get_time_from_start()
	
	# Limit update frequency for performance
	if current_time - last_update_time < (1.0 / update_frequency):
		return
	
	last_update_time = current_time
	
	# Update missile lock state machine
	_update_lock_state_machine(delta)
	
	# Update seeker head simulation
	_update_seeker_head(delta)
	
	# Update target data if we have a target
	if current_target and is_instance_valid(current_target):
		_update_target_data()
	
	# Update launch window calculation
	_update_launch_window()

## Update lock state machine
func _update_lock_state_machine(delta: float) -> void:
	"""Update missile lock state machine."""
	match lock_stage:
		LockStage.INACTIVE:
			_handle_inactive_stage()
		
		LockStage.SEEKER_INIT:
			_handle_seeker_init_stage(delta)
		
		LockStage.TARGET_PAINT:
			_handle_target_paint_stage(delta)
		
		LockStage.ACQUIRING:
			_handle_acquiring_stage(delta)
		
		LockStage.LOCKED:
			_handle_locked_stage(delta)
		
		LockStage.TRACKING:
			_handle_tracking_stage(delta)
		
		LockStage.LOST:
			_handle_lost_stage(delta)

## Handle inactive stage
func _handle_inactive_stage() -> void:
	"""Handle inactive lock stage."""
	# Check if we should start lock acquisition
	if current_target and is_instance_valid(current_target):
		if _is_target_in_seeker_cone():
			_start_lock_sequence()

## Handle seeker initialization stage
func _handle_seeker_init_stage(delta: float) -> void:
	"""Handle seeker head initialization."""
	var current_time: float = Time.get_time_from_start()
	var elapsed_time: float = current_time - stage_start_time
	
	# Seeker initialization takes time
	var init_time: float = 0.5  # 500ms initialization
	lock_progress = clampf(elapsed_time / init_time, 0.0, 1.0)
	
	if elapsed_time >= init_time:
		seeker_status = SeekerStatus.SEARCHING
		
		# Check if we need target painting
		if requires_target_painting:
			_transition_to_target_paint()
		else:
			_transition_to_acquiring()

## Handle target painting stage
func _handle_target_paint_stage(delta: float) -> void:
	"""Handle target painting for painter missiles."""
	if not current_target or not is_instance_valid(current_target):
		_fail_lock_sequence("Target lost during painting")
		return
	
	var current_time: float = Time.get_time_from_start()
	var elapsed_time: float = current_time - stage_start_time
	
	# Check if target is still in paint range
	if target_distance > paint_max_range:
		_fail_lock_sequence("Target out of paint range")
		return
	
	# Update paint progress
	lock_progress = clampf(elapsed_time / paint_acquisition_time, 0.0, 1.0)
	
	# Simulate target painting with laser
	_update_target_painting(delta)
	
	if elapsed_time >= paint_acquisition_time:
		target_is_painted = true
		target_painting_completed.emit(current_target)
		_transition_to_acquiring()

## Handle acquiring stage
func _handle_acquiring_stage(delta: float) -> void:
	"""Handle lock acquisition stage."""
	if not current_target or not is_instance_valid(current_target):
		_fail_lock_sequence("Target lost during acquisition")
		return
	
	if not _is_target_lockable():
		_fail_lock_sequence("Target not lockable")
		return
	
	var current_time: float = Time.get_time_from_start()
	var elapsed_time: float = current_time - stage_start_time
	
	# Update lock progress based on target quality
	var lock_quality: float = _calculate_lock_quality()
	var effective_acquisition_time: float = seeker_acquisition_time / lock_quality
	
	lock_progress = clampf(elapsed_time / effective_acquisition_time, 0.0, 1.0)
	
	if lock_progress >= 1.0:
		_complete_lock_acquisition()

## Handle locked stage
func _handle_locked_stage(delta: float) -> void:
	"""Handle locked stage."""
	if not current_target or not is_instance_valid(current_target):
		_lose_lock("Target destroyed")
		return
	
	if not _is_target_lockable():
		_lose_lock("Target moved out of parameters")
		return
	
	# Update lock strength based on tracking quality
	lock_strength = _calculate_lock_quality()
	
	# Check if lock is strong enough to maintain
	if lock_strength < 0.3:
		_lose_lock("Lock strength too weak")
		return
	
	# Transition to tracking for active guidance
	if missile_type in [MissileType.RADAR_GUIDED, MissileType.TARGET_PAINTER]:
		_transition_to_tracking()

## Handle tracking stage
func _handle_tracking_stage(delta: float) -> void:
	"""Handle active tracking stage."""
	if not current_target or not is_instance_valid(current_target):
		_lose_lock("Target lost during tracking")
		return
	
	# Update tracking parameters
	_update_seeker_tracking(delta)
	
	# Check tracking quality
	var tracking_quality: float = _calculate_tracking_quality()
	lock_strength = tracking_quality
	
	if tracking_quality < 0.2:
		_lose_lock("Tracking quality degraded")

## Handle lost stage
func _handle_lost_stage(delta: float) -> void:
	"""Handle lock lost stage."""
	var current_time: float = Time.get_time_from_start()
	var time_since_lost: float = current_time - stage_start_time
	
	# Try to reacquire for a limited time
	if time_since_lost > lock_maintain_time:
		_fail_lock_sequence("Reacquisition timeout")
		return
	
	# Check if we can reacquire the target
	if current_target and is_instance_valid(current_target) and _is_target_lockable():
		_start_lock_sequence()

## Start lock sequence
func _start_lock_sequence() -> void:
	"""Start the missile lock sequence."""
	lock_stage = LockStage.SEEKER_INIT
	seeker_status = SeekerStatus.INITIALIZING
	stage_start_time = Time.get_time_from_start()
	lock_progress = 0.0
	lock_strength = 0.0

## Transition to target painting
func _transition_to_target_paint() -> void:
	"""Transition to target painting stage."""
	lock_stage = LockStage.TARGET_PAINT
	stage_start_time = Time.get_time_from_start()
	lock_progress = 0.0
	target_painting_started.emit(current_target)

## Transition to acquiring
func _transition_to_acquiring() -> void:
	"""Transition to lock acquiring stage."""
	lock_stage = LockStage.ACQUIRING
	seeker_status = SeekerStatus.TRACKING
	stage_start_time = Time.get_time_from_start()
	lock_progress = 0.0

## Transition to tracking
func _transition_to_tracking() -> void:
	"""Transition to active tracking stage."""
	lock_stage = LockStage.TRACKING
	seeker_status = SeekerStatus.LOCKED

## Complete lock acquisition
func _complete_lock_acquisition() -> void:
	"""Complete the lock acquisition process."""
	lock_stage = LockStage.LOCKED
	seeker_status = SeekerStatus.LOCKED
	lock_progress = 1.0
	lock_strength = 1.0
	
	missile_lock_acquired.emit(missile_type, current_target)

## Lose lock
func _lose_lock(reason: String) -> void:
	"""Lose the current missile lock."""
	var previous_stage: LockStage = lock_stage
	
	lock_stage = LockStage.LOST
	stage_start_time = Time.get_time_from_start()
	
	# Only emit lock lost if we had a complete lock
	if previous_stage in [LockStage.LOCKED, LockStage.TRACKING]:
		missile_lock_lost.emit(missile_type, current_target, reason)

## Fail lock sequence
func _fail_lock_sequence(reason: String) -> void:
	"""Fail the lock sequence."""
	lock_stage = LockStage.INACTIVE
	seeker_status = SeekerStatus.FAILED
	current_target = null
	lock_progress = 0.0
	lock_strength = 0.0
	target_is_painted = false

## Check if target is in seeker cone
func _is_target_in_seeker_cone() -> bool:
	"""Check if target is within seeker cone."""
	if not current_target or not player_ship:
		return false
	
	# Calculate angle to target
	var direction_to_target: Vector3 = (current_target.global_position - player_ship.global_position).normalized()
	var missile_forward: Vector3 = -player_ship.global_transform.basis.z
	var angle_to_target: float = acos(missile_forward.dot(direction_to_target))
	
	return angle_to_target <= deg_to_rad(seeker_cone_angle)

## Check if target is lockable
func _is_target_lockable() -> bool:
	"""Check if target meets lock requirements."""
	if not current_target or not player_ship:
		return false
	
	# Check basic distance and angle requirements
	if target_distance < min_lock_range or target_distance > max_lock_range:
		return false
	
	if target_angle > deg_to_rad(max_lock_angle):
		return false
	
	# Check missile-specific requirements
	match missile_type:
		MissileType.HEATSEEKER:
			return _check_heat_signature_requirements()
		MissileType.RADAR_GUIDED:
			return _check_radar_signature_requirements()
		MissileType.TARGET_PAINTER:
			return target_is_painted and _check_paint_requirements()
		MissileType.TORPEDO:
			return _check_torpedo_requirements()
		MissileType.SWARM:
			return _check_swarm_requirements()
		MissileType.DUMBFIRE:
			return true  # No lock needed
	
	return true

## Check heat signature requirements
func _check_heat_signature_requirements() -> bool:
	"""Check heat seeker requirements."""
	# Target must have sufficient heat signature
	if target_heat_signature < heat_signature_threshold:
		return false
	
	# Check for heat bloom interference at close range
	if target_distance < heat_bloom_range:
		var bloom_interference: float = (heat_bloom_range - target_distance) / heat_bloom_range
		if bloom_interference > 0.5:
			return false
	
	# Check background heat noise
	var signal_to_noise: float = target_heat_signature / (background_heat_noise + 0.01)
	return signal_to_noise > 3.0

## Check radar signature requirements
func _check_radar_signature_requirements() -> bool:
	"""Check radar guided requirements."""
	# Target must have sufficient radar cross section
	if target_radar_signature < radar_cross_section_threshold:
		return false
	
	# Check for radar jamming
	var jamming_level: float = _get_radar_jamming_level()
	var effective_resistance: float = radar_jamming_resistance - jamming_level
	
	return effective_resistance > 0.2

## Check paint requirements
func _check_paint_requirements() -> bool:
	"""Check target painter requirements."""
	# Must have painted target recently
	if not target_is_painted:
		return false
	
	# Check paint beam continuity
	return _has_clear_line_of_sight() and target_distance <= paint_max_range

## Check torpedo requirements
func _check_torpedo_requirements() -> bool:
	"""Check torpedo lock requirements."""
	# Torpedoes require larger targets
	if current_target.has_method("get_ship_size"):
		var ship_size = current_target.get_ship_size()
		return ship_size >= ShipSizes.Size.CORVETTE
	
	return true

## Check swarm missile requirements
func _check_swarm_requirements() -> bool:
	"""Check swarm missile requirements."""
	# Swarm missiles are less picky about targets
	return _has_clear_line_of_sight()

## Calculate lock quality
func _calculate_lock_quality() -> float:
	"""Calculate current lock quality (0.0 to 1.0)."""
	var quality: float = 1.0
	
	# Factor in angle deviation
	var angle_factor: float = 1.0 - (target_angle / deg_to_rad(max_lock_angle))
	quality *= clampf(angle_factor, 0.0, 1.0)
	
	# Factor in distance
	var optimal_distance: float = max_lock_range * 0.6
	var distance_factor: float = 1.0 - abs(target_distance - optimal_distance) / optimal_distance
	quality *= clampf(distance_factor, 0.0, 1.0)
	
	# Factor in signature strength
	match missile_type:
		MissileType.HEATSEEKER:
			var heat_factor: float = (target_heat_signature - heat_signature_threshold) / (1.0 - heat_signature_threshold)
			quality *= clampf(heat_factor, 0.0, 1.0)
		
		MissileType.RADAR_GUIDED:
			var radar_factor: float = (target_radar_signature - radar_cross_section_threshold) / (1.0 - radar_cross_section_threshold)
			quality *= clampf(radar_factor, 0.0, 1.0)
	
	return clampf(quality, 0.0, 1.0)

## Calculate tracking quality
func _calculate_tracking_quality() -> float:
	"""Calculate tracking quality for active guidance."""
	var quality: float = _calculate_lock_quality()
	
	# Factor in seeker tracking error
	var tracking_factor: float = 1.0 - (seeker_tracking_error / deg_to_rad(5.0))  # 5 degree max error
	quality *= clampf(tracking_factor, 0.0, 1.0)
	
	# Factor in target velocity
	var velocity_factor: float = 1.0 - clampf(target_velocity.length() / 300.0, 0.0, 0.5)
	quality *= velocity_factor
	
	return clampf(quality, 0.0, 1.0)

## Update seeker head simulation
func _update_seeker_head(delta: float) -> void:
	"""Update seeker head simulation."""
	if seeker_status == SeekerStatus.OFFLINE:
		return
	
	# Update seeker gimbal tracking
	if current_target and lock_stage in [LockStage.TRACKING, LockStage.LOCKED]:
		_update_seeker_gimbal_tracking(delta)
	
	# Update seeker noise
	seeker_noise_level = randf_range(0.0, 0.1)
	
	# Update tracking error based on various factors
	_update_seeker_tracking_error(delta)

## Update seeker gimbal tracking
func _update_seeker_gimbal_tracking(delta: float) -> void:
	"""Update seeker head gimbal tracking."""
	if not current_target:
		return
	
	# Calculate required gimbal angles to track target
	var target_relative_pos: Vector3 = current_target.global_position - player_ship.global_position
	var missile_basis: Basis = player_ship.global_transform.basis
	var target_local: Vector3 = missile_basis * target_relative_pos
	
	# Calculate pitch and yaw angles
	var target_pitch: float = atan2(target_local.y, target_local.z)
	var target_yaw: float = atan2(target_local.x, target_local.z)
	
	# Smooth gimbal movement
	var gimbal_speed: float = 2.0  # rad/s
	seeker_gimbal_angle.x = move_toward(seeker_gimbal_angle.x, target_pitch, gimbal_speed * delta)
	seeker_gimbal_angle.y = move_toward(seeker_gimbal_angle.y, target_yaw, gimbal_speed * delta)

## Update seeker tracking error
func _update_seeker_tracking_error(delta: float) -> void:
	"""Update seeker head tracking error."""
	var base_error: float = 0.0
	
	# Add noise-based error
	base_error += seeker_noise_level * 0.5
	
	# Add distance-based error
	if target_distance > 0.0:
		base_error += (target_distance / max_lock_range) * 0.3
	
	# Add velocity-based error
	if target_velocity.length() > 0.0:
		base_error += clampf(target_velocity.length() / 200.0, 0.0, 0.4)
	
	# Add jamming-based error
	if missile_type == MissileType.RADAR_GUIDED:
		var jamming_level: float = _get_radar_jamming_level()
		base_error += jamming_level * 0.6
	
	seeker_tracking_error = clampf(base_error, 0.0, deg_to_rad(10.0))

## Update target data
func _update_target_data() -> void:
	"""Update target signature and position data."""
	if not current_target or not player_ship:
		return
	
	# Update basic position data
	var target_position: Vector3 = current_target.global_position
	var player_position: Vector3 = player_ship.global_position
	target_distance = target_position.distance_to(player_position)
	
	# Calculate angle
	var direction_to_target: Vector3 = (target_position - player_position).normalized()
	var player_forward: Vector3 = -player_ship.global_transform.basis.z
	target_angle = acos(player_forward.dot(direction_to_target))
	
	# Update velocity
	if current_target.has_method("get_velocity"):
		target_velocity = current_target.get_velocity()
	
	# Update signatures based on target
	_update_target_signatures()

## Update target signatures
func _update_target_signatures() -> void:
	"""Update target heat and radar signatures."""
	if not current_target:
		return
	
	# Heat signature calculation
	target_heat_signature = 0.5  # Base heat signature
	
	# Increase heat if target is accelerating
	if target_velocity.length() > 100.0:
		target_heat_signature += clampf(target_velocity.length() / 500.0, 0.0, 0.4)
	
	# Ships with engines running are hotter
	if current_target.has_method("get_engine_heat"):
		var engine_heat: float = current_target.get_engine_heat()
		target_heat_signature += engine_heat * 0.3
	
	# Add random heat variation
	target_heat_signature += randf_range(-0.1, 0.1)
	target_heat_signature = clampf(target_heat_signature, 0.0, 1.0)
	
	# Radar signature calculation
	target_radar_signature = 0.7  # Base radar signature
	
	# Larger ships have bigger radar signatures
	if current_target.has_method("get_ship_size"):
		var ship_size = current_target.get_ship_size()
		target_radar_signature *= (1.0 + ship_size * 0.2)
	
	# Stealth reduces radar signature
	if current_target.has_method("get_stealth_factor"):
		var stealth_factor: float = current_target.get_stealth_factor()
		target_radar_signature *= (1.0 - stealth_factor)
	
	target_radar_signature = clampf(target_radar_signature, 0.0, 1.0)

## Update target painting
func _update_target_painting(delta: float) -> void:
	"""Update target painting simulation."""
	if not requires_target_painting or not current_target:
		return
	
	# Simulate painting beam hitting target
	# This would integrate with visual effects system
	
	# Check if paint beam is interrupted
	if not _has_clear_line_of_sight():
		_fail_lock_sequence("Paint beam interrupted")

## Update launch window
func _update_launch_window() -> void:
	"""Update missile launch window calculation."""
	if lock_stage not in [LockStage.LOCKED, LockStage.TRACKING]:
		launch_window_open = false
		launch_window_quality = 0.0
		return
	
	# Calculate optimal launch range
	optimal_launch_range = max_lock_range * 0.7
	
	# Check if we're in launch envelope
	var in_range: bool = target_distance >= min_lock_range and target_distance <= max_lock_range
	var good_angle: bool = target_angle <= deg_to_rad(max_lock_angle)
	var good_lock: bool = lock_strength >= 0.7
	
	var was_open: bool = launch_window_open
	launch_window_open = in_range and good_angle and good_lock
	
	# Calculate launch quality
	if launch_window_open:
		var range_quality: float = 1.0 - abs(target_distance - optimal_launch_range) / optimal_launch_range
		var angle_quality: float = 1.0 - (target_angle / deg_to_rad(max_lock_angle))
		launch_window_quality = (range_quality + angle_quality + lock_strength) / 3.0
	else:
		launch_window_quality = 0.0
	
	# Emit signals for launch window changes
	if launch_window_open and not was_open:
		launch_window_opened.emit(missile_type)
	elif not launch_window_open and was_open:
		launch_window_closed.emit(missile_type)

## Get radar jamming level
func _get_radar_jamming_level() -> float:
	"""Get current radar jamming level."""
	# This would integrate with ECM/ECCM systems
	return 0.0

## Check clear line of sight
func _has_clear_line_of_sight() -> bool:
	"""Check if there's clear line of sight to target."""
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

## Public interface

## Set target for missile lock
func set_target(target: Node3D) -> bool:
	"""Set target for missile lock."""
	if target == current_target:
		return true
	
	# Clear current lock if changing targets
	if current_target:
		_fail_lock_sequence("Target changed")
	
	current_target = target
	target_is_painted = false
	
	if target and is_instance_valid(target):
		if _is_target_in_seeker_cone():
			_start_lock_sequence()
			return true
		else:
			return false
	else:
		_fail_lock_sequence("No target")
		return true

## Set missile type
func set_missile_type(type: MissileType) -> void:
	"""Set missile type and reconfigure system."""
	if missile_type != type:
		missile_type = type
		_initialize_seeker_head()
		
		# Restart lock sequence if active
		if lock_stage != LockStage.INACTIVE and current_target:
			_start_lock_sequence()

## Configure missile parameters
func configure_missile_parameters(
	acquisition_time: float,
	maintain_time: float,
	max_angle: float,
	max_range: float,
	cone_angle: float
) -> void:
	"""Configure missile lock parameters."""
	seeker_acquisition_time = acquisition_time
	lock_maintain_time = maintain_time
	max_lock_angle = max_angle
	max_lock_range = max_range
	seeker_cone_angle = cone_angle

## Launch missile
func launch_missile() -> bool:
	"""Launch missile if lock conditions are met."""
	if not launch_window_open:
		return false
	
	lock_stage = LockStage.LAUNCHED
	seeker_status = SeekerStatus.OFFLINE
	
	# Clear target tracking
	current_target = null
	lock_progress = 0.0
	lock_strength = 0.0
	
	return true

## Get missile lock status
func get_missile_lock_status() -> Dictionary:
	"""Get current missile lock status."""
	return {
		"missile_type": missile_type,
		"lock_stage": lock_stage,
		"seeker_status": seeker_status,
		"lock_progress": lock_progress,
		"lock_strength": lock_strength,
		"target": current_target,
		"target_distance": target_distance,
		"target_angle": rad_to_deg(target_angle),
		"launch_window_open": launch_window_open,
		"launch_window_quality": launch_window_quality,
		"target_heat_signature": target_heat_signature,
		"target_radar_signature": target_radar_signature,
		"seeker_tracking_error": rad_to_deg(seeker_tracking_error)
	}

## Check if missile has lock
func has_missile_lock() -> bool:
	"""Check if missile has active lock."""
	return lock_stage in [LockStage.LOCKED, LockStage.TRACKING]

## Check if ready to launch
func is_ready_to_launch() -> bool:
	"""Check if missile is ready to launch."""
	return launch_window_open and lock_strength >= 0.7

## Get launch window quality
func get_launch_window_quality() -> float:
	"""Get current launch window quality (0.0 to 1.0)."""
	return launch_window_quality