class_name SubsystemAnimationController
extends Node

## Subsystem animation controller for complex space objects
## Manages triggered animations for turrets, engines, docking bays, and other subsystems
## Based on WCS triggered_rotation and queued_animation systems

# EPIC-002 Asset Core Integration
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const ModelMetadata = preload("res://addons/wcs_asset_core/resources/object/model_metadata.gd")

# Animation System Signals (AC4)
signal animation_started(subsystem_name: String, animation_type: String)
signal animation_completed(subsystem_name: String, animation_type: String)
signal animation_interrupted(subsystem_name: String, animation_type: String, reason: String)

# WCS Animation Trigger Types (from modelanim.h)
enum TriggerType {
	INITIAL = 0,           # Initial position
	DOCKING = 1,           # Before docking
	DOCKED = 2,            # After docking
	PRIMARY_BANK = 3,      # Primary weapons
	SECONDARY_BANK = 4,    # Secondary weapons
	DOCK_BAY_DOOR = 5,     # Fighter bays
	AFTERBURNER = 6,       # Afterburner
	TURRET_FIRING = 7,     # Turret shooting
	SCRIPTED = 8           # Script-triggered
}

# Animation State Management
enum AnimationState {
	IDLE,
	ACCELERATING,
	CONSTANT_VELOCITY,
	DECELERATING,
	COMPLETED
}

# Animation queue management (MAX_TRIGGERED_ANIMATIONS = 15 from WCS)
const MAX_QUEUED_ANIMATIONS: int = 15

# Active animations registry
var _active_animations: Dictionary = {}  # subsystem_name -> AnimationData
var _animation_queue: Array[QueuedAnimation] = []
var _subsystem_integration: Node = null

# Performance optimization (AC5)
var _update_frequency: float = 60.0  # Hz
var _last_update_time: float = 0.0
var _performance_budget_ms: float = 0.2  # AC5 requirement

## Animation data structure representing active animation
class AnimationData:
	var subsystem: Node3D
	var subsystem_name: String
	var trigger_type: TriggerType
	var animation_state: AnimationState = AnimationState.IDLE
	
	# Three-phase animation system (WCS approach)
	var start_angle: Vector3
	var end_angle: Vector3
	var current_angle: Vector3
	
	var velocity: Vector3
	var acceleration: Vector3
	var max_velocity: Vector3
	
	# Timing control
	var start_time: float
	var acceleration_time: float
	var constant_velocity_time: float
	var deceleration_time: float
	var total_duration: float
	
	# State flags
	var is_absolute: bool = true  # Absolute vs relative positioning
	var can_interrupt: bool = true
	var loops: bool = false
	
	# Audio integration
	var start_sound: AudioStreamPlayer3D = null
	var loop_sound: AudioStreamPlayer3D = null
	var end_sound: AudioStreamPlayer3D = null

## Queued animation structure for animation queue
class QueuedAnimation:
	var subsystem_name: String
	var trigger_type: TriggerType
	var target_angle: Vector3
	var duration: float
	var interrupt_existing: bool = false
	var priority: int = 0

func _ready() -> void:
	name = "SubsystemAnimationController"
	_subsystem_integration = get_parent().find_child("ModelSubsystemIntegration", false, false)
	
	if not _subsystem_integration:
		push_warning("SubsystemAnimationController: ModelSubsystemIntegration not found")

func _process(delta: float) -> void:
	# Performance optimization - limit update frequency (AC5)
	var current_time: float = Time.get_time_dict_from_system()["msec"]
	if current_time - _last_update_time < (1000.0 / _update_frequency):
		return
	
	_last_update_time = current_time
	
	var start_time: int = Time.get_time_dict_from_system()["msec"]
	
	# Process animation queue
	_process_animation_queue()
	
	# Update active animations
	_update_active_animations(delta)
	
	# Check performance budget (AC5)
	var end_time: int = Time.get_time_dict_from_system()["msec"]
	var frame_time_ms: float = end_time - start_time
	
	if frame_time_ms > _performance_budget_ms:
		push_warning("SubsystemAnimationController: Frame time %.2fms exceeds budget %.2fms" % [frame_time_ms, _performance_budget_ms])

## Initialize subsystem animations from metadata (AC1, AC2)
func initialize_subsystem_animations(space_object: BaseSpaceObject, metadata: ModelMetadata) -> bool:
	if not space_object or not metadata:
		return false
	
	# Initialize turret animations from weapon banks
	_initialize_turret_animations(space_object, metadata)
	
	# Initialize engine animations from thruster banks
	_initialize_engine_animations(space_object, metadata)
	
	# Initialize docking bay animations
	_initialize_docking_animations(space_object, metadata)
	
	# Initialize generic subsystem animations
	_initialize_generic_animations(space_object, metadata)
	
	return true

## Initialize turret rotation animations (AC2)
func _initialize_turret_animations(space_object: BaseSpaceObject, metadata: ModelMetadata) -> void:
	for i in range(metadata.gun_banks.size()):
		var gun_bank: ModelMetadata.WeaponBank = metadata.gun_banks[i]
		var subsystem_name: String = "WeaponsPrimary_%d" % i
		
		# Configure turret rotation capabilities
		_configure_turret_animation(space_object, subsystem_name, gun_bank)

## Configure individual turret animation capabilities
func _configure_turret_animation(space_object: BaseSpaceObject, subsystem_name: String, weapon_bank: ModelMetadata.WeaponBank) -> void:
	var subsystem: Node3D = _find_subsystem(space_object, subsystem_name)
	if not subsystem:
		return
	
	# Add turret rotation metadata
	subsystem.set_meta("can_rotate", true)
	subsystem.set_meta("rotation_speed", Vector3(90.0, 90.0, 0.0))  # degrees per second
	subsystem.set_meta("rotation_limits", Vector3(360.0, 180.0, 0.0))  # max rotation angles
	subsystem.set_meta("animation_type", "turret")
	
	# Create visual animation player for smooth rotation
	var animation_player: AnimationPlayer = AnimationPlayer.new()
	animation_player.name = "TurretAnimationPlayer"
	subsystem.add_child(animation_player)
	
	# Store original rotation for relative movements
	subsystem.set_meta("initial_rotation", subsystem.rotation)

## Initialize engine glow and thrust animations (AC2)
func _initialize_engine_animations(space_object: BaseSpaceObject, metadata: ModelMetadata) -> void:
	for i in range(metadata.thruster_banks.size()):
		var thruster_bank: ModelMetadata.ThrusterBank = metadata.thruster_banks[i]
		var subsystem_name: String = "Engine_%d" % i
		
		# Configure engine animation capabilities
		_configure_engine_animation(space_object, subsystem_name, thruster_bank)

## Configure engine thrust and glow animations
func _configure_engine_animation(space_object: BaseSpaceObject, subsystem_name: String, thruster_bank: ModelMetadata.ThrusterBank) -> void:
	var subsystem: Node3D = _find_subsystem(space_object, subsystem_name)
	if not subsystem:
		return
	
	# Add engine animation metadata
	subsystem.set_meta("can_animate", true)
	subsystem.set_meta("animation_type", "engine")
	subsystem.set_meta("thrust_intensity", 0.0)
	subsystem.set_meta("glow_intensity", 0.0)
	
	# Create engine glow animation using existing thruster effects
	for child in subsystem.get_children():
		if child.name.begins_with("ThrusterEffect_"):
			var thruster_particles: GPUParticles3D = child as GPUParticles3D
			if thruster_particles:
				# Configure for animation control
				thruster_particles.set_meta("base_amount", thruster_particles.amount)
				thruster_particles.set_meta("base_lifetime", thruster_particles.lifetime)

## Initialize docking bay door animations (AC2)
func _initialize_docking_animations(space_object: BaseSpaceObject, metadata: ModelMetadata) -> void:
	for i in range(metadata.docking_points.size()):
		var dock_point: ModelMetadata.DockPoint = metadata.docking_points[i]
		var subsystem_name: String = "Docking_%s" % dock_point.name
		
		# Configure docking bay animation
		_configure_docking_animation(space_object, subsystem_name, dock_point)

## Configure docking bay door animation
func _configure_docking_animation(space_object: BaseSpaceObject, subsystem_name: String, dock_point: ModelMetadata.DockPoint) -> void:
	var subsystem: Node3D = _find_subsystem(space_object, subsystem_name)
	if not subsystem:
		return
	
	# Add docking animation metadata
	subsystem.set_meta("can_animate", true)
	subsystem.set_meta("animation_type", "docking")
	subsystem.set_meta("door_state", "closed")  # closed, opening, open, closing
	subsystem.set_meta("door_open_angle", Vector3(0, 90, 0))  # degrees to open
	subsystem.set_meta("door_speed", 30.0)  # degrees per second

## Initialize generic subsystem animations (radar rotation, etc.)
func _initialize_generic_animations(space_object: BaseSpaceObject, metadata: ModelMetadata) -> void:
	# Radar dish rotation animation
	var radar_subsystem: Node3D = _find_subsystem(space_object, "Radar")
	if radar_subsystem:
		radar_subsystem.set_meta("can_animate", true)
		radar_subsystem.set_meta("animation_type", "radar")
		radar_subsystem.set_meta("rotation_speed", Vector3(0, 45, 0))  # Slow Y-axis rotation

## Queue animation for specific subsystem (AC4)
func queue_animation(subsystem_name: String, trigger_type: TriggerType, target_angle: Vector3, duration: float, interrupt_existing: bool = false, priority: int = 0) -> bool:
	# Check queue capacity
	if _animation_queue.size() >= MAX_QUEUED_ANIMATIONS:
		push_warning("SubsystemAnimationController: Animation queue full, dropping animation for %s" % subsystem_name)
		return false
	
	# Create queued animation
	var queued_anim: QueuedAnimation = QueuedAnimation.new()
	queued_anim.subsystem_name = subsystem_name
	queued_anim.trigger_type = trigger_type
	queued_anim.target_angle = target_angle
	queued_anim.duration = duration
	queued_anim.interrupt_existing = interrupt_existing
	queued_anim.priority = priority
	
	# Insert into queue based on priority
	_insert_animation_by_priority(queued_anim)
	
	return true

## Insert animation into queue maintaining priority order
func _insert_animation_by_priority(animation: QueuedAnimation) -> void:
	var insert_index: int = _animation_queue.size()
	
	# Find insertion point based on priority (higher priority first)
	for i in range(_animation_queue.size()):
		if animation.priority > _animation_queue[i].priority:
			insert_index = i
			break
	
	_animation_queue.insert(insert_index, animation)

## Process animation queue and start new animations
func _process_animation_queue() -> void:
	while _animation_queue.size() > 0:
		var queued_anim: QueuedAnimation = _animation_queue[0]
		
		# Check if subsystem is available or can be interrupted
		if _can_start_animation(queued_anim):
			_animation_queue.remove_at(0)
			_start_subsystem_animation(queued_anim)
		else:
			break  # Wait for subsystem to become available

## Check if animation can be started for subsystem
func _can_start_animation(queued_anim: QueuedAnimation) -> bool:
	# Check if subsystem exists and is healthy
	if not _is_subsystem_operational(queued_anim.subsystem_name):
		return false
	
	# Check if there's an active animation for this subsystem
	if queued_anim.subsystem_name in _active_animations:
		var active_anim: AnimationData = _active_animations[queued_anim.subsystem_name]
		
		# Can interrupt if requested and animation allows it
		if queued_anim.interrupt_existing and active_anim.can_interrupt:
			_interrupt_animation(queued_anim.subsystem_name, "higher_priority")
			return true
		
		return false  # Cannot start while animation is active
	
	return true

## Start subsystem animation from queued animation
func _start_subsystem_animation(queued_anim: QueuedAnimation) -> void:
	var space_object: BaseSpaceObject = get_parent() as BaseSpaceObject
	if not space_object:
		return
	
	var subsystem: Node3D = _find_subsystem(space_object, queued_anim.subsystem_name)
	if not subsystem:
		return
	
	# Create animation data
	var anim_data: AnimationData = AnimationData.new()
	anim_data.subsystem = subsystem
	anim_data.subsystem_name = queued_anim.subsystem_name
	anim_data.trigger_type = queued_anim.trigger_type
	anim_data.animation_state = AnimationState.ACCELERATING
	
	# Set up three-phase animation (WCS approach)
	anim_data.start_angle = subsystem.rotation
	anim_data.end_angle = queued_anim.target_angle
	anim_data.current_angle = anim_data.start_angle
	
	# Calculate animation phases
	_calculate_animation_phases(anim_data, queued_anim.duration)
	
	# Store active animation
	_active_animations[queued_anim.subsystem_name] = anim_data
	
	# Emit start signal
	animation_started.emit(queued_anim.subsystem_name, _trigger_type_to_string(queued_anim.trigger_type))

## Calculate three-phase animation timing (acceleration, constant, deceleration)
func _calculate_animation_phases(anim_data: AnimationData, total_duration: float) -> void:
	anim_data.total_duration = total_duration
	
	# Get rotation speed from subsystem metadata
	var rotation_speed: Vector3 = anim_data.subsystem.get_meta("rotation_speed", Vector3(90, 90, 90))
	
	# Calculate maximum velocity based on rotation distance and speed
	var rotation_distance: Vector3 = anim_data.end_angle - anim_data.start_angle
	anim_data.max_velocity = rotation_speed
	
	# Calculate acceleration for smooth motion
	anim_data.acceleration = anim_data.max_velocity * 4.0  # Reach max velocity in 1/4 of time
	
	# Phase timing (30% acceleration, 40% constant, 30% deceleration)
	anim_data.acceleration_time = total_duration * 0.3
	anim_data.constant_velocity_time = total_duration * 0.4
	anim_data.deceleration_time = total_duration * 0.3
	
	anim_data.start_time = Time.get_time_dict_from_system()["msec"] / 1000.0

## Update all active animations
func _update_active_animations(delta: float) -> void:
	var completed_animations: Array[String] = []
	
	for subsystem_name in _active_animations.keys():
		var anim_data: AnimationData = _active_animations[subsystem_name]
		
		if _update_single_animation(anim_data, delta):
			completed_animations.append(subsystem_name)
	
	# Clean up completed animations
	for subsystem_name in completed_animations:
		_complete_animation(subsystem_name)

## Update single animation and return true if completed
func _update_single_animation(anim_data: AnimationData, delta: float) -> bool:
	var current_time: float = Time.get_time_dict_from_system()["msec"] / 1000.0
	var elapsed_time: float = current_time - anim_data.start_time
	
	# Determine current animation phase
	if elapsed_time <= anim_data.acceleration_time:
		anim_data.animation_state = AnimationState.ACCELERATING
		_update_acceleration_phase(anim_data, elapsed_time)
	elif elapsed_time <= anim_data.acceleration_time + anim_data.constant_velocity_time:
		anim_data.animation_state = AnimationState.CONSTANT_VELOCITY
		_update_constant_velocity_phase(anim_data, elapsed_time)
	elif elapsed_time <= anim_data.total_duration:
		anim_data.animation_state = AnimationState.DECELERATING
		_update_deceleration_phase(anim_data, elapsed_time)
	else:
		anim_data.animation_state = AnimationState.COMPLETED
		return true  # Animation completed
	
	# Apply rotation to subsystem
	anim_data.subsystem.rotation = anim_data.current_angle
	
	return false  # Animation continues

## Update acceleration phase of animation
func _update_acceleration_phase(anim_data: AnimationData, elapsed_time: float) -> void:
	var phase_progress: float = elapsed_time / anim_data.acceleration_time
	var progress_curve: float = 0.5 * phase_progress * phase_progress  # Quadratic acceleration
	
	# Calculate current velocity
	anim_data.velocity = anim_data.acceleration * elapsed_time
	anim_data.velocity = anim_data.velocity.clamp(Vector3.ZERO, anim_data.max_velocity)
	
	# Update current angle
	var total_progress: float = progress_curve * 0.3  # 30% of total rotation in acceleration phase
	anim_data.current_angle = anim_data.start_angle.lerp(anim_data.end_angle, total_progress)

## Update constant velocity phase of animation
func _update_constant_velocity_phase(anim_data: AnimationData, elapsed_time: float) -> void:
	var phase_start: float = anim_data.acceleration_time
	var phase_elapsed: float = elapsed_time - phase_start
	var phase_progress: float = phase_elapsed / anim_data.constant_velocity_time
	
	# Maintain maximum velocity
	anim_data.velocity = anim_data.max_velocity
	
	# Update current angle (30% to 70% of total rotation)
	var base_progress: float = 0.3
	var phase_contribution: float = phase_progress * 0.4  # 40% of total rotation
	var total_progress: float = base_progress + phase_contribution
	
	anim_data.current_angle = anim_data.start_angle.lerp(anim_data.end_angle, total_progress)

## Update deceleration phase of animation
func _update_deceleration_phase(anim_data: AnimationData, elapsed_time: float) -> void:
	var phase_start: float = anim_data.acceleration_time + anim_data.constant_velocity_time
	var phase_elapsed: float = elapsed_time - phase_start
	var phase_progress: float = phase_elapsed / anim_data.deceleration_time
	
	# Calculate deceleration curve
	var decel_curve: float = 1.0 - (0.5 * (1.0 - phase_progress) * (1.0 - phase_progress))
	
	# Update velocity (decreasing)
	var decel_factor: float = 1.0 - phase_progress
	anim_data.velocity = anim_data.max_velocity * decel_factor
	
	# Update current angle (70% to 100% of total rotation)
	var base_progress: float = 0.7
	var phase_contribution: float = decel_curve * 0.3  # Final 30% of total rotation
	var total_progress: float = base_progress + phase_contribution
	
	anim_data.current_angle = anim_data.start_angle.lerp(anim_data.end_angle, total_progress)

## Complete animation and clean up
func _complete_animation(subsystem_name: String) -> void:
	if subsystem_name not in _active_animations:
		return
	
	var anim_data: AnimationData = _active_animations[subsystem_name]
	
	# Ensure final position is exactly at target
	anim_data.subsystem.rotation = anim_data.end_angle
	
	# Clean up animation data
	_active_animations.erase(subsystem_name)
	
	# Emit completion signal
	animation_completed.emit(subsystem_name, _trigger_type_to_string(anim_data.trigger_type))

## Interrupt active animation
func _interrupt_animation(subsystem_name: String, reason: String) -> void:
	if subsystem_name not in _active_animations:
		return
	
	var anim_data: AnimationData = _active_animations[subsystem_name]
	_active_animations.erase(subsystem_name)
	
	animation_interrupted.emit(subsystem_name, _trigger_type_to_string(anim_data.trigger_type), reason)

## Trigger specific animation types (AC2)
func trigger_turret_rotation(space_object: BaseSpaceObject, turret_name: String, target_direction: Vector3, duration: float = 2.0) -> bool:
	# Calculate target angle from direction vector
	var target_angle: Vector3 = Vector3.ZERO
	target_angle.y = atan2(target_direction.x, target_direction.z)  # Horizontal rotation
	target_angle.x = atan2(-target_direction.y, Vector2(target_direction.x, target_direction.z).length())  # Vertical rotation
	
	return queue_animation(turret_name, TriggerType.TURRET_FIRING, target_angle, duration, true, 5)

## Trigger engine thrust animation (AC2)
func trigger_engine_thrust(space_object: BaseSpaceObject, engine_name: String, thrust_intensity: float, duration: float = 1.0) -> bool:
	var subsystem: Node3D = _find_subsystem(space_object, engine_name)
	if not subsystem:
		return false
	
	# Update thrust intensity metadata
	subsystem.set_meta("thrust_intensity", thrust_intensity)
	
	# Animate thruster particles
	_animate_engine_effects(subsystem, thrust_intensity)
	
	return true

## Animate engine thrust effects
func _animate_engine_effects(engine_subsystem: Node3D, thrust_intensity: float) -> void:
	for child in engine_subsystem.get_children():
		if child.name.begins_with("ThrusterEffect_"):
			var thruster_particles: GPUParticles3D = child as GPUParticles3D
			if thruster_particles:
				var base_amount: int = thruster_particles.get_meta("base_amount", 100)
				var base_lifetime: float = thruster_particles.get_meta("base_lifetime", 2.0)
				
				# Adjust particle system based on thrust intensity
				thruster_particles.amount = int(base_amount * thrust_intensity)
				thruster_particles.lifetime = base_lifetime * (0.5 + thrust_intensity * 0.5)
				thruster_particles.emitting = thrust_intensity > 0.1

## Trigger docking bay door animation (AC2)
func trigger_docking_door(space_object: BaseSpaceObject, dock_name: String, open: bool, duration: float = 3.0) -> bool:
	var subsystem: Node3D = _find_subsystem(space_object, dock_name)
	if not subsystem:
		return false
	
	var current_state: String = subsystem.get_meta("door_state", "closed")
	var target_angle: Vector3 = Vector3.ZERO
	
	if open and current_state == "closed":
		target_angle = subsystem.get_meta("door_open_angle", Vector3(0, 90, 0))
		subsystem.set_meta("door_state", "opening")
	elif not open and current_state == "open":
		target_angle = Vector3.ZERO
		subsystem.set_meta("door_state", "closing")
	else:
		return false  # Invalid state transition
	
	return queue_animation(dock_name, TriggerType.DOCK_BAY_DOOR, target_angle, duration, true, 3)

## Check if subsystem is operational for animation (AC3)
func _is_subsystem_operational(subsystem_name: String) -> bool:
	if not _subsystem_integration:
		return true  # Assume operational if no integration
	
	var space_object: BaseSpaceObject = get_parent() as BaseSpaceObject
	if not space_object:
		return false
	
	# Check subsystem health
	var health: float = _subsystem_integration.get_subsystem_health(space_object, subsystem_name)
	
	# WCS rule: animations only function when subsystem has health > 0
	return health > 0.0

## Find subsystem by name in space object
func _find_subsystem(space_object: BaseSpaceObject, subsystem_name: String) -> Node3D:
	var subsystems_container: Node = space_object.find_child("Subsystems", false, false)
	if not subsystems_container:
		return null
	
	return subsystems_container.find_child(subsystem_name, false, false) as Node3D

## Convert trigger type enum to string
func _trigger_type_to_string(trigger_type: TriggerType) -> String:
	match trigger_type:
		TriggerType.INITIAL: return "initial"
		TriggerType.DOCKING: return "docking"
		TriggerType.DOCKED: return "docked"
		TriggerType.PRIMARY_BANK: return "primary_bank"
		TriggerType.SECONDARY_BANK: return "secondary_bank"
		TriggerType.DOCK_BAY_DOOR: return "dock_bay_door"
		TriggerType.AFTERBURNER: return "afterburner"
		TriggerType.TURRET_FIRING: return "turret_firing"
		TriggerType.SCRIPTED: return "scripted"
		_: return "unknown"

## Stop all animations for specific subsystem
func stop_subsystem_animations(subsystem_name: String) -> void:
	# Remove from active animations
	if subsystem_name in _active_animations:
		_interrupt_animation(subsystem_name, "stopped")
	
	# Remove from queue
	_animation_queue = _animation_queue.filter(func(anim): return anim.subsystem_name != subsystem_name)

## Stop all animations (for cleanup)
func stop_all_animations() -> void:
	# Clear active animations
	for subsystem_name in _active_animations.keys():
		_interrupt_animation(subsystem_name, "all_stopped")
	
	# Clear queue
	_animation_queue.clear()

## Get animation performance statistics (AC5)
func get_animation_performance_stats() -> Dictionary:
	return {
		"active_animations": _active_animations.size(),
		"queued_animations": _animation_queue.size(),
		"update_frequency": _update_frequency,
		"performance_budget_ms": _performance_budget_ms,
		"max_queue_size": MAX_QUEUED_ANIMATIONS
	}

## Configure performance settings (AC5)
func configure_performance(update_frequency: float, budget_ms: float) -> void:
	_update_frequency = clamp(update_frequency, 10.0, 120.0)  # 10-120 Hz
	_performance_budget_ms = clamp(budget_ms, 0.1, 1.0)  # 0.1-1.0 ms