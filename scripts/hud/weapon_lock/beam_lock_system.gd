class_name BeamLockSystem
extends Node

## Continuous beam weapon targeting system for HUD-007
## Handles beam weapon lock-on, power management, and continuous tracking
## Supports various beam types with different targeting requirements

# Beam weapon types
enum BeamType {
	LASER,			# Standard laser beams
	PARTICLE,		# Particle beam weapons
	PLASMA,			# Plasma cannons
	ION,			# Ion cannons
	ANTIMATTER,		# Antimatter beams
	CUTTING,		# Cutting beam (anti-ship)
	POINT_DEFENSE	# Point defense beams
}

# Beam tracking states
enum TrackingState {
	OFFLINE,		# Beam system offline
	CHARGING,		# Charging beam capacitors
	SEEKING,		# Seeking target
	TRACKING,		# Actively tracking target
	FIRING,			# Firing beam
	OVERHEATED,		# System overheated
	CAPACITOR_DRAIN	# Capacitors depleted
}

# Beam quality levels
enum BeamQuality {
	PERFECT,		# Perfect beam coherence
	EXCELLENT,		# Excellent tracking
	GOOD,			# Good beam quality
	FAIR,			# Fair tracking quality
	POOR,			# Poor beam quality
	UNUSABLE		# Beam unusable
}

# Signals for beam system events
signal beam_lock_acquired(beam_type: BeamType, target: Node3D)
signal beam_lock_lost(beam_type: BeamType, target: Node3D, reason: String)
signal beam_tracking_started(target: Node3D)
signal beam_firing_started(target: Node3D, beam_quality: BeamQuality)
signal beam_firing_stopped(reason: String)
signal beam_overheated()
signal capacitor_depleted()

# Beam configuration
@export_group("Beam Configuration")
@export var beam_type: BeamType = BeamType.LASER
@export var max_beam_range: float = 2000.0          # Maximum effective range
@export var optimal_beam_range: float = 1000.0     # Optimal firing range
@export var min_beam_range: float = 50.0           # Minimum safe range
@export var max_tracking_angle: float = 15.0       # Maximum tracking angle (degrees)
@export var beam_convergence_distance: float = 800.0 # Distance where beams converge

# Power management
@export_group("Power Management")
@export var max_capacitor_charge: float = 100.0    # Maximum capacitor charge
@export var capacitor_charge_rate: float = 20.0    # Charge per second
@export var beam_power_drain: float = 50.0         # Power drain per second while firing
@export var tracking_power_drain: float = 5.0      # Power drain per second while tracking
@export var min_firing_charge: float = 30.0        # Minimum charge to fire

# Thermal management
@export_group("Thermal Management")
@export var max_heat_capacity: float = 100.0       # Maximum heat capacity
@export var heat_generation_rate: float = 40.0     # Heat generation per second while firing
@export var heat_dissipation_rate: float = 15.0    # Heat dissipation per second
@export var overheat_threshold: float = 90.0       # Heat level that causes overheat
@export var cooldown_threshold: float = 60.0       # Heat level to resume operation

# Beam precision settings
@export_group("Beam Precision")
@export var tracking_precision: float = 0.5        # Tracking precision in degrees
@export var beam_divergence: float = 0.1           # Beam divergence in degrees
@export var atmospheric_diffraction: float = 0.05  # Atmospheric beam spreading
@export var target_jitter_compensation: bool = true

# Current system state
var current_target: Node3D = null
var tracking_state: TrackingState = TrackingState.OFFLINE
var beam_quality: BeamQuality = BeamQuality.UNUSABLE
var tracking_strength: float = 0.0
var beam_coherence: float = 0.0

# Power and thermal state
var capacitor_charge: float = 0.0
var current_heat_level: float = 0.0
var is_overheated: bool = false
var power_efficiency: float = 1.0

# Target tracking data
var target_position: Vector3 = Vector3.ZERO
var target_velocity: Vector3 = Vector3.ZERO
var target_distance: float = 0.0
var target_angle: float = 0.0
var predicted_position: Vector3 = Vector3.ZERO
var tracking_error: float = 0.0

# Beam physics simulation
var beam_convergence_point: Vector3 = Vector3.ZERO
var beam_focal_length: float = 0.0
var beam_spread_at_target: float = 0.0
var atmospheric_absorption: float = 0.0

# Targeting computer
var tracking_filter_alpha: float = 0.3  # Low-pass filter for smooth tracking
var prediction_time: float = 0.1        # Prediction lookahead time
var last_target_position: Vector3 = Vector3.ZERO
var target_acceleration: Vector3 = Vector3.ZERO

# References
var player_ship: Node3D = null
var weapon_manager: Node = null
var beam_emitter: Node3D = null

# Performance optimization
var update_frequency: float = 60.0  # Hz - higher for beam weapons
var last_update_time: float = 0.0

func _ready() -> void:
	set_process(true)
	_initialize_beam_lock_system()

## Initialize beam lock system
func _initialize_beam_lock_system() -> void:
	"""Initialize beam weapon targeting system."""
	# Get player ship reference
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		player_ship = player_nodes[0]
		
		# Get weapon manager
		if player_ship.has_method("get_weapon_manager"):
			weapon_manager = player_ship.get_weapon_manager()
		
		# Initialize beam parameters based on type
		_configure_beam_parameters()
	
	# Set initial state
	tracking_state = TrackingState.OFFLINE
	capacitor_charge = 0.0
	current_heat_level = 0.0

## Configure beam parameters based on type
func _configure_beam_parameters() -> void:
	"""Configure beam parameters based on weapon type."""
	match beam_type:
		BeamType.LASER:
			beam_divergence = 0.05
			heat_generation_rate = 30.0
			beam_power_drain = 40.0
			
		BeamType.PARTICLE:
			beam_divergence = 0.15
			heat_generation_rate = 50.0
			beam_power_drain = 60.0
			
		BeamType.PLASMA:
			beam_divergence = 0.3
			heat_generation_rate = 70.0
			beam_power_drain = 80.0
			
		BeamType.ION:
			beam_divergence = 0.1
			heat_generation_rate = 40.0
			beam_power_drain = 50.0
			
		BeamType.ANTIMATTER:
			beam_divergence = 0.02
			heat_generation_rate = 90.0
			beam_power_drain = 100.0
			
		BeamType.CUTTING:
			beam_divergence = 0.01
			heat_generation_rate = 60.0
			beam_power_drain = 70.0
			max_beam_range = 500.0  # Short range
			
		BeamType.POINT_DEFENSE:
			beam_divergence = 0.2
			heat_generation_rate = 20.0
			beam_power_drain = 30.0
			max_tracking_angle = 45.0  # Wide tracking

## Main process loop
func _process(delta: float) -> void:
	"""Process beam weapon system updates."""
	var current_time: float = Time.get_ticks_msec() / 1000.0
	
	# High-frequency updates for beam weapons
	if current_time - last_update_time < (1.0 / update_frequency):
		return
	
	last_update_time = current_time
	
	# Update power and thermal systems
	_update_power_systems(delta)
	_update_thermal_systems(delta)
	
	# Update beam tracking state machine
	_update_tracking_state_machine(delta)
	
	# Update target tracking if we have a target
	if current_target and is_instance_valid(current_target):
		_update_target_tracking(delta)
		_update_beam_physics(delta)
	
	# Update beam quality assessment
	_update_beam_quality()

## Update power systems
func _update_power_systems(delta: float) -> void:
	"""Update capacitor and power management."""
	var power_drain: float = 0.0
	
	# Calculate power consumption based on state
	match tracking_state:
		TrackingState.CHARGING:
			# Charging capacitors
			if capacitor_charge < max_capacitor_charge:
				var charge_amount: float = capacitor_charge_rate * delta * power_efficiency
				capacitor_charge = minf(capacitor_charge + charge_amount, max_capacitor_charge)
		
		TrackingState.TRACKING:
			power_drain = tracking_power_drain
		
		TrackingState.FIRING:
			power_drain = beam_power_drain
	
	# Apply power drain
	if power_drain > 0.0:
		capacitor_charge = maxf(0.0, capacitor_charge - power_drain * delta)
		
		# Check for capacitor depletion
		if capacitor_charge <= 0.0 and tracking_state == TrackingState.FIRING:
			_stop_beam_firing("Capacitor depleted")
			capacitor_depleted.emit()

## Update thermal systems
func _update_thermal_systems(delta: float) -> void:
	"""Update heat generation and dissipation."""
	var heat_generation: float = 0.0
	
	# Calculate heat generation based on state
	match tracking_state:
		TrackingState.FIRING:
			heat_generation = heat_generation_rate
		
		TrackingState.TRACKING:
			heat_generation = heat_generation_rate * 0.1  # Minimal heat while tracking
	
	# Apply heat generation and dissipation
	current_heat_level += heat_generation * delta
	current_heat_level -= heat_dissipation_rate * delta
	current_heat_level = clampf(current_heat_level, 0.0, max_heat_capacity)
	
	# Check for overheat
	if current_heat_level >= overheat_threshold and not is_overheated:
		is_overheated = true
		if tracking_state == TrackingState.FIRING:
			_stop_beam_firing("System overheated")
		beam_overheated.emit()
	
	# Check for cooldown completion
	elif current_heat_level <= cooldown_threshold and is_overheated:
		is_overheated = false

## Update tracking state machine
func _update_tracking_state_machine(delta: float) -> void:
	"""Update beam weapon tracking state machine."""
	match tracking_state:
		TrackingState.OFFLINE:
			_handle_offline_state()
		
		TrackingState.CHARGING:
			_handle_charging_state()
		
		TrackingState.SEEKING:
			_handle_seeking_state()
		
		TrackingState.TRACKING:
			_handle_tracking_state(delta)
		
		TrackingState.FIRING:
			_handle_firing_state(delta)
		
		TrackingState.OVERHEATED:
			_handle_overheated_state()
		
		TrackingState.CAPACITOR_DRAIN:
			_handle_capacitor_drain_state()

## Handle offline state
func _handle_offline_state() -> void:
	"""Handle beam system offline state."""
	# Check if we should start charging
	if current_target and is_instance_valid(current_target):
		_start_beam_charging()

## Handle charging state
func _handle_charging_state() -> void:
	"""Handle capacitor charging state."""
	# Check if we have minimum charge to proceed
	if capacitor_charge >= min_firing_charge and not is_overheated:
		if current_target and is_instance_valid(current_target):
			_start_target_seeking()
		else:
			tracking_state = TrackingState.OFFLINE

## Handle seeking state
func _handle_seeking_state() -> void:
	"""Handle target seeking state."""
	if not current_target or not is_instance_valid(current_target):
		tracking_state = TrackingState.OFFLINE
		return
	
	if not _is_target_trackable():
		tracking_state = TrackingState.OFFLINE
		return
	
	# Start tracking if target is in range
	_start_beam_tracking()

## Handle tracking state
func _handle_tracking_state(delta: float) -> void:
	"""Handle beam tracking state."""
	if not current_target or not is_instance_valid(current_target):
		_lose_beam_lock("Target lost")
		return
	
	if not _is_target_trackable():
		_lose_beam_lock("Target out of parameters")
		return
	
	if is_overheated:
		tracking_state = TrackingState.OVERHEATED
		return
	
	# Update tracking quality
	_update_tracking_performance(delta)
	
	# Check if we can start firing
	if beam_quality >= BeamQuality.FAIR and capacitor_charge >= min_firing_charge:
		# Auto-fire would be controlled by weapon manager
		pass

## Handle firing state
func _handle_firing_state(delta: float) -> void:
	"""Handle beam firing state."""
	if not current_target or not is_instance_valid(current_target):
		_stop_beam_firing("Target lost")
		return
	
	if not _is_target_trackable():
		_stop_beam_firing("Target out of range")
		return
	
	if is_overheated:
		_stop_beam_firing("System overheated")
		tracking_state = TrackingState.OVERHEATED
		return
	
	if capacitor_charge <= 0.0:
		_stop_beam_firing("Capacitor depleted")
		tracking_state = TrackingState.CAPACITOR_DRAIN
		return
	
	# Continue tracking while firing
	_update_tracking_performance(delta)

## Handle overheated state
func _handle_overheated_state() -> void:
	"""Handle system overheated state."""
	if not is_overheated:
		if current_target and is_instance_valid(current_target):
			_start_target_seeking()
		else:
			tracking_state = TrackingState.OFFLINE

## Handle capacitor drain state
func _handle_capacitor_drain_state() -> void:
	"""Handle capacitor drained state."""
	if capacitor_charge >= min_firing_charge:
		if current_target and is_instance_valid(current_target):
			_start_target_seeking()
		else:
			tracking_state = TrackingState.OFFLINE

## Start beam charging
func _start_beam_charging() -> void:
	"""Start beam capacitor charging."""
	tracking_state = TrackingState.CHARGING

## Start target seeking
func _start_target_seeking() -> void:
	"""Start seeking target."""
	tracking_state = TrackingState.SEEKING

## Start beam tracking
func _start_beam_tracking() -> void:
	"""Start active beam tracking."""
	tracking_state = TrackingState.TRACKING
	beam_tracking_started.emit(current_target)

## Start beam firing
func start_beam_firing() -> bool:
	"""Start beam firing if conditions are met."""
	if tracking_state != TrackingState.TRACKING:
		return false
	
	if beam_quality < BeamQuality.FAIR:
		return false
	
	if capacitor_charge < min_firing_charge:
		return false
	
	if is_overheated:
		return false
	
	tracking_state = TrackingState.FIRING
	beam_firing_started.emit(current_target, beam_quality)
	return true

## Stop beam firing
func _stop_beam_firing(reason: String) -> void:
	"""Stop beam firing."""
	if tracking_state == TrackingState.FIRING:
		tracking_state = TrackingState.TRACKING
		beam_firing_stopped.emit(reason)

## Lose beam lock
func _lose_beam_lock(reason: String) -> void:
	"""Lose beam lock on target."""
	var had_lock: bool = tracking_state in [TrackingState.TRACKING, TrackingState.FIRING]
	
	tracking_state = TrackingState.OFFLINE
	tracking_strength = 0.0
	
	if had_lock:
		beam_lock_lost.emit(beam_type, current_target, reason)

## Check if target is trackable
func _is_target_trackable() -> bool:
	"""Check if target meets beam tracking requirements."""
	if not current_target or not player_ship:
		return false
	
	# Check distance requirements
	if target_distance < min_beam_range or target_distance > max_beam_range:
		return false
	
	# Check angle requirements
	if target_angle > deg_to_rad(max_tracking_angle):
		return false
	
	# Check line of sight
	if not _has_clear_line_of_sight():
		return false
	
	# Beam-specific requirements
	match beam_type:
		BeamType.CUTTING:
			# Cutting beams require very close range
			return target_distance <= 500.0
		
		BeamType.POINT_DEFENSE:
			# Point defense can track fast small targets
			return true
		
		BeamType.ANTIMATTER:
			# Antimatter beams require perfect conditions
			return target_angle <= deg_to_rad(5.0) and tracking_error < deg_to_rad(0.5)
	
	return true

## Update target tracking
func _update_target_tracking(delta: float) -> void:
	"""Update target position tracking and prediction."""
	if not current_target or not player_ship:
		return
	
	# Store previous position for velocity calculation
	last_target_position = target_position
	
	# Update current target data
	target_position = current_target.global_position
	var player_position: Vector3 = player_ship.global_position
	target_distance = target_position.distance_to(player_position)
	
	# Calculate angle to target
	var direction_to_target: Vector3 = (target_position - player_position).normalized()
	var beam_forward: Vector3 = -player_ship.global_transform.basis.z
	target_angle = acos(beam_forward.dot(direction_to_target))
	
	# Update target velocity and acceleration
	if target_velocity != Vector3.ZERO:
		var new_velocity: Vector3 = Vector3.ZERO
		if current_target.has_method("get_velocity"):
			new_velocity = current_target.get_velocity()
		else:
			# Estimate velocity from position change
			new_velocity = (target_position - last_target_position) / delta
		
		# Smooth velocity with low-pass filter
		target_velocity = target_velocity.lerp(new_velocity, tracking_filter_alpha)
		
		# Calculate acceleration
		target_acceleration = (new_velocity - target_velocity) / delta
	else:
		if current_target.has_method("get_velocity"):
			target_velocity = current_target.get_velocity()
	
	# Predict future target position
	_calculate_target_prediction()

## Calculate target prediction
func _calculate_target_prediction() -> void:
	"""Calculate predicted target position for beam convergence."""
	# Basic linear prediction
	predicted_position = target_position + target_velocity * prediction_time
	
	# Add acceleration compensation for better prediction
	if target_acceleration.length() > 1.0:  # Only if significant acceleration
		predicted_position += 0.5 * target_acceleration * prediction_time * prediction_time
	
	# Adjust prediction based on beam travel time
	var beam_travel_time: float = target_distance / 299792458.0  # Speed of light approximation
	if beam_travel_time > 0.001:  # More than 1ms travel time
		predicted_position += target_velocity * beam_travel_time

## Update tracking performance
func _update_tracking_performance(delta: float) -> void:
	"""Update beam tracking performance metrics."""
	if not current_target:
		tracking_strength = 0.0
		tracking_error = deg_to_rad(10.0)
		return
	
	# Calculate tracking strength based on various factors
	var base_strength: float = 1.0
	
	# Distance factor
	var optimal_range: float = optimal_beam_range
	var distance_factor: float = 1.0 - abs(target_distance - optimal_range) / optimal_range
	base_strength *= clampf(distance_factor, 0.2, 1.0)
	
	# Angle factor
	var angle_factor: float = 1.0 - (target_angle / deg_to_rad(max_tracking_angle))
	base_strength *= clampf(angle_factor, 0.0, 1.0)
	
	# Velocity factor (harder to track fast targets)
	var velocity_factor: float = 1.0 - clampf(target_velocity.length() / 200.0, 0.0, 0.5)
	base_strength *= velocity_factor
	
	# Heat factor (performance degrades with heat)
	var heat_factor: float = 1.0 - (current_heat_level / max_heat_capacity) * 0.3
	base_strength *= heat_factor
	
	# Power factor (performance degrades with low power)
	var power_factor: float = clampf(capacitor_charge / max_capacitor_charge, 0.3, 1.0)
	base_strength *= power_factor
	
	tracking_strength = clampf(base_strength, 0.0, 1.0)
	
	# Calculate tracking error
	var base_error: float = tracking_precision
	base_error *= (1.0 - tracking_strength)  # Better tracking = less error
	base_error += randf_range(-0.1, 0.1)     # Random jitter
	
	# Jitter compensation
	if target_jitter_compensation:
		base_error *= 0.7
	
	tracking_error = clampf(base_error, 0.0, deg_to_rad(5.0))

## Update beam physics
func _update_beam_physics(delta: float) -> void:
	"""Update beam physics calculations."""
	# Calculate beam convergence point
	beam_convergence_point = player_ship.global_position + \
		(-player_ship.global_transform.basis.z * beam_convergence_distance)
	
	# Calculate beam focal length based on target distance
	beam_focal_length = target_distance
	
	# Calculate beam spread at target
	var base_divergence: float = deg_to_rad(beam_divergence)
	beam_spread_at_target = target_distance * tan(base_divergence)
	
	# Add atmospheric effects
	atmospheric_absorption = target_distance * atmospheric_diffraction * 0.001
	beam_spread_at_target += atmospheric_absorption
	
	# Calculate beam coherence
	var coherence_factor: float = 1.0
	coherence_factor *= clampf(1.0 - (current_heat_level / max_heat_capacity) * 0.2, 0.5, 1.0)
	coherence_factor *= clampf(capacitor_charge / max_capacitor_charge, 0.3, 1.0)
	coherence_factor *= clampf(1.0 - tracking_error / deg_to_rad(1.0), 0.0, 1.0)
	
	beam_coherence = clampf(coherence_factor, 0.0, 1.0)

## Update beam quality assessment
func _update_beam_quality() -> void:
	"""Update overall beam quality rating."""
	var quality_score: float = 0.0
	
	# Factor in tracking strength
	quality_score += tracking_strength * 0.4
	
	# Factor in beam coherence
	quality_score += beam_coherence * 0.3
	
	# Factor in system status
	if not is_overheated and capacitor_charge > min_firing_charge:
		quality_score += 0.3
	
	# Determine quality level
	if quality_score >= 0.9:
		beam_quality = BeamQuality.PERFECT
	elif quality_score >= 0.75:
		beam_quality = BeamQuality.EXCELLENT
	elif quality_score >= 0.6:
		beam_quality = BeamQuality.GOOD
	elif quality_score >= 0.4:
		beam_quality = BeamQuality.FAIR
	elif quality_score >= 0.2:
		beam_quality = BeamQuality.POOR
	else:
		beam_quality = BeamQuality.UNUSABLE

## Check clear line of sight
func _has_clear_line_of_sight() -> bool:
	"""Check if there's clear line of sight to target."""
	if not player_ship or not current_target:
		return false
	
	var space_state := player_ship.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		player_ship.global_position,
		predicted_position,  # Check to predicted position
		(1 << CollisionLayers.Layer.ASTEROIDS) | (1 << CollisionLayers.Layer.DEBRIS)
	)
	
	var result := space_state.intersect_ray(query)
	return result.is_empty()

## Public interface

## Set target for beam tracking
func set_target(target: Node3D) -> bool:
	"""Set target for beam tracking."""
	if target == current_target:
		return true
	
	# Clear current tracking if changing targets
	if current_target:
		_lose_beam_lock("Target changed")
	
	current_target = target
	
	if target and is_instance_valid(target):
		if _is_target_trackable():
			_start_beam_charging()
			return true
		else:
			return false
	else:
		tracking_state = TrackingState.OFFLINE
		return true

## Set beam type
func set_beam_type(type: BeamType) -> void:
	"""Set beam weapon type and reconfigure system."""
	if beam_type != type:
		beam_type = type
		_configure_beam_parameters()

## Configure beam parameters
func configure_beam_parameters(
	max_range: float,
	optimal_range: float,
	tracking_angle: float,
	convergence_dist: float
) -> void:
	"""Configure beam weapon parameters."""
	max_beam_range = max_range
	optimal_beam_range = optimal_range
	max_tracking_angle = tracking_angle
	beam_convergence_distance = convergence_dist

## Force stop firing
func stop_firing() -> void:
	"""Force stop beam firing."""
	if tracking_state == TrackingState.FIRING:
		_stop_beam_firing("Manual stop")

## Get beam lock status
func get_beam_lock_status() -> Dictionary:
	"""Get current beam lock status."""
	return {
		"beam_type": beam_type,
		"tracking_state": tracking_state,
		"beam_quality": beam_quality,
		"tracking_strength": tracking_strength,
		"beam_coherence": beam_coherence,
		"target": current_target,
		"target_distance": target_distance,
		"target_angle": rad_to_deg(target_angle),
		"capacitor_charge": capacitor_charge,
		"heat_level": current_heat_level,
		"is_overheated": is_overheated,
		"tracking_error": rad_to_deg(tracking_error),
		"beam_spread_at_target": beam_spread_at_target,
		"is_firing": tracking_state == TrackingState.FIRING
	}

## Check if beam has lock
func has_beam_lock() -> bool:
	"""Check if beam has active lock."""
	return tracking_state in [TrackingState.TRACKING, TrackingState.FIRING]

## Check if beam is firing
func is_beam_firing() -> bool:
	"""Check if beam is currently firing."""
	return tracking_state == TrackingState.FIRING

## Check if ready to fire
func is_ready_to_fire() -> bool:
	"""Check if beam is ready to fire."""
	return (tracking_state == TrackingState.TRACKING and 
		   beam_quality >= BeamQuality.FAIR and 
		   capacitor_charge >= min_firing_charge and 
		   not is_overheated)

## Get beam firing efficiency
func get_firing_efficiency() -> float:
	"""Get current firing efficiency (0.0 to 1.0)."""
	if not has_beam_lock():
		return 0.0
	
	var efficiency: float = tracking_strength * beam_coherence
	
	# Factor in heat effects
	efficiency *= clampf(1.0 - (current_heat_level / max_heat_capacity) * 0.3, 0.3, 1.0)
	
	# Factor in power level
	efficiency *= clampf(capacitor_charge / max_capacitor_charge, 0.3, 1.0)
	
	return clampf(efficiency, 0.0, 1.0)