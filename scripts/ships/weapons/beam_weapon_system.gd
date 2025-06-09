class_name BeamWeaponSystem
extends Node

## SHIP-013 AC1: Beam Weapon System with 5 WCS Beam Types
## Implements all WCS beam types (A-E) with authentic behaviors and lifecycle management
## Provides foundation for continuous damage, targeting, and visual effects

# EPIC-002 Asset Core Integration
const WeaponTypes = preload("res://addons/wcs_asset_core/constants/weapon_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Signals
signal beam_weapon_fired(weapon_data: Dictionary)
signal beam_weapon_hit(hit_data: Dictionary)
signal beam_weapon_stopped(weapon_data: Dictionary, reason: String)
signal beam_lifecycle_changed(beam_id: String, old_phase: String, new_phase: String)
signal beam_target_acquired(beam_id: String, target: Node)
signal beam_target_lost(beam_id: String, target: Node)

# WCS Beam Types - matching original definitions
enum BeamType {
	TYPE_A_STANDARD = 0,     # Maintains constant aim at target, no movement once locked
	TYPE_B_SLASH = 1,        # Sweeps across target using octant selection for area coverage
	TYPE_C_TARGETING = 2,    # Fighter-mounted forward beam, lives for single frame
	TYPE_D_CHASING = 3,      # Multiple shots tracking moving targets with dynamic aim adjustment
	TYPE_E_FIXED = 4         # Fires directly from turret orientation without aiming
}

# Beam lifecycle phases
enum BeamPhase {
	INACTIVE = 0,
	WARMUP = 1,
	ACTIVE = 2,
	WARMDOWN = 3
}

# Active beam tracking
var active_beams: Dictionary = {}  # beam_id -> beam_data
var beam_counter: int = 0

# Beam type configurations
var beam_type_configs: Dictionary = {
	BeamType.TYPE_A_STANDARD: {
		"name": "Standard Continuous Beam",
		"warmup_time": 0.5,
		"active_duration": 3.0,
		"warmdown_time": 0.3,
		"damage_per_interval": 25.0,
		"energy_cost_per_second": 15.0,
		"range": 2000.0,
		"width": 2.0,
		"collision_type": "line",
		"can_retarget": false,
		"pierces_shields": true,
		"max_penetration": 3
	},
	BeamType.TYPE_B_SLASH: {
		"name": "Slash Beam",
		"warmup_time": 0.3,
		"active_duration": 2.0,
		"warmdown_time": 0.2,
		"damage_per_interval": 15.0,
		"energy_cost_per_second": 20.0,
		"range": 1500.0,
		"width": 8.0,
		"collision_type": "sphereline",
		"can_retarget": true,
		"pierces_shields": false,
		"sweep_angle": 45.0,
		"sweep_speed": 30.0
	},
	BeamType.TYPE_C_TARGETING: {
		"name": "Targeting Laser",
		"warmup_time": 0.1,
		"active_duration": 0.02,  # Single frame
		"warmdown_time": 0.1,
		"damage_per_interval": 8.0,
		"energy_cost_per_second": 5.0,
		"range": 800.0,
		"width": 1.0,
		"collision_type": "line",
		"can_retarget": false,
		"pierces_shields": false,
		"auto_fire": true
	},
	BeamType.TYPE_D_CHASING: {
		"name": "Chasing Beam",
		"warmup_time": 0.4,
		"active_duration": 4.0,
		"warmdown_time": 0.2,
		"damage_per_interval": 20.0,
		"energy_cost_per_second": 12.0,
		"range": 1800.0,
		"width": 3.0,
		"collision_type": "line",
		"can_retarget": true,
		"pierces_shields": true,
		"tracking_speed": 45.0,
		"max_attempts": 5
	},
	BeamType.TYPE_E_FIXED: {
		"name": "Fixed Beam",
		"warmup_time": 0.2,
		"active_duration": 1.5,
		"warmdown_time": 0.1,
		"damage_per_interval": 30.0,
		"energy_cost_per_second": 25.0,
		"range": 1200.0,
		"width": 4.0,
		"collision_type": "line",
		"can_retarget": false,
		"pierces_shields": true,
		"fixed_direction": true
	}
}

# System references
var continuous_damage_system: ContinuousDamageSystem = null
var beam_collision_detector: BeamCollisionDetector = null
var beam_lifecycle_manager: BeamLifecycleManager = null
var beam_renderer: BeamRenderer = null
var beam_targeting_system: BeamTargetingSystem = null
var beam_penetration_system: BeamPenetrationSystem = null

# Configuration
@export var enable_beam_debugging: bool = false
@export var max_simultaneous_beams: int = 10
@export var beam_update_frequency: float = 0.01  # 100Hz for smooth updates
@export var damage_interval: float = 0.17  # 170ms WCS standard

# Performance tracking
var beam_performance_stats: Dictionary = {
	"total_beams_fired": 0,
	"active_beam_count": 0,
	"damage_applications": 0,
	"collision_checks": 0
}

# Update timer
var beam_update_timer: float = 0.0

func _ready() -> void:
	_setup_beam_weapon_system()
	_initialize_beam_subsystems()

## Initialize beam weapon system with all subsystems
func initialize_beam_weapon_system(weapon_manager: Node = null) -> void:
	# Connect to weapon manager if provided
	if weapon_manager and weapon_manager.has_signal("weapon_triggered"):
		weapon_manager.weapon_triggered.connect(_on_weapon_triggered)
	
	if enable_beam_debugging:
		print("BeamWeaponSystem: Initialized with %d beam type configurations" % beam_type_configs.size())

## Fire beam weapon with specified parameters
func fire_beam_weapon(firing_data: Dictionary) -> String:
	var beam_type = firing_data.get("beam_type", BeamType.TYPE_A_STANDARD)
	var source_position = firing_data.get("source_position", Vector3.ZERO)
	var initial_target = firing_data.get("target", null)
	var firing_ship = firing_data.get("firing_ship", null)
	var turret_node = firing_data.get("turret_node", null)
	
	# Validate beam type
	if not beam_type_configs.has(beam_type):
		push_error("BeamWeaponSystem: Invalid beam type %d" % beam_type)
		return ""
	
	# Check beam limits
	if active_beams.size() >= max_simultaneous_beams:
		if enable_beam_debugging:
			print("BeamWeaponSystem: Maximum beam limit reached (%d)" % max_simultaneous_beams)
		return ""
	
	# Generate unique beam ID
	beam_counter += 1
	var beam_id = "beam_%d_%d" % [beam_type, beam_counter]
	
	# Create beam data structure
	var beam_data = _create_beam_data(beam_id, beam_type, firing_data)
	
	# Initialize beam lifecycle
	if beam_lifecycle_manager:
		beam_lifecycle_manager.start_beam_lifecycle(beam_id, beam_data)
	
	# Set initial target if provided
	if initial_target and beam_targeting_system:
		beam_targeting_system.set_beam_target(beam_id, initial_target)
	
	# Start beam renderer
	if beam_renderer:
		beam_renderer.start_beam_rendering(beam_id, beam_data)
	
	# Register with continuous damage system
	if continuous_damage_system:
		continuous_damage_system.register_beam_weapon(beam_id, beam_data)
	
	# Store active beam
	active_beams[beam_id] = beam_data
	beam_performance_stats["total_beams_fired"] += 1
	beam_performance_stats["active_beam_count"] = active_beams.size()
	
	# Emit signal
	beam_weapon_fired.emit(beam_data)
	
	if enable_beam_debugging:
		print("BeamWeaponSystem: Fired %s beam %s" % [
			beam_type_configs[beam_type]["name"], beam_id
		])
	
	return beam_id

## Stop beam weapon
func stop_beam_weapon(beam_id: String, reason: String = "manual") -> void:
	if not active_beams.has(beam_id):
		return
	
	var beam_data = active_beams[beam_id]
	
	# Start warmdown phase
	if beam_lifecycle_manager:
		beam_lifecycle_manager.start_beam_warmdown(beam_id)
	
	# Stop damage application
	if continuous_damage_system:
		continuous_damage_system.unregister_beam_weapon(beam_id)
	
	# Stop rendering
	if beam_renderer:
		beam_renderer.stop_beam_rendering(beam_id)
	
	# Clear targeting
	if beam_targeting_system:
		beam_targeting_system.clear_beam_target(beam_id)
	
	# Emit signal
	beam_weapon_stopped.emit(beam_data, reason)
	
	if enable_beam_debugging:
		print("BeamWeaponSystem: Stopped beam %s (reason: %s)" % [beam_id, reason])

## Get beam data by ID
func get_beam_data(beam_id: String) -> Dictionary:
	return active_beams.get(beam_id, {})

## Update beam target
func update_beam_target(beam_id: String, new_target: Node) -> bool:
	if not active_beams.has(beam_id):
		return false
	
	var beam_data = active_beams[beam_id]
	var beam_type = beam_data.get("beam_type", BeamType.TYPE_A_STANDARD)
	var config = beam_type_configs[beam_type]
	
	# Check if beam type can retarget
	if not config.get("can_retarget", false):
		if enable_beam_debugging:
			print("BeamWeaponSystem: Beam %s cannot retarget" % beam_id)
		return false
	
	# Update target through targeting system
	if beam_targeting_system:
		return beam_targeting_system.set_beam_target(beam_id, new_target)
	
	return false

## Get beam performance statistics
func get_beam_performance_statistics() -> Dictionary:
	beam_performance_stats["active_beam_count"] = active_beams.size()
	return beam_performance_stats.duplicate()

## Setup beam weapon system
func _setup_beam_weapon_system() -> void:
	active_beams.clear()
	beam_counter = 0
	beam_update_timer = 0.0
	
	# Reset performance stats
	beam_performance_stats = {
		"total_beams_fired": 0,
		"active_beam_count": 0,
		"damage_applications": 0,
		"collision_checks": 0
	}

## Initialize beam subsystems
func _initialize_beam_subsystems() -> void:
	# Create continuous damage system
	continuous_damage_system = ContinuousDamageSystem.new()
	continuous_damage_system.name = "ContinuousDamageSystem"
	add_child(continuous_damage_system)
	continuous_damage_system.initialize_damage_system(damage_interval)
	
	# Create beam collision detector
	beam_collision_detector = BeamCollisionDetector.new()
	beam_collision_detector.name = "BeamCollisionDetector"
	add_child(beam_collision_detector)
	beam_collision_detector.initialize_collision_detector()
	
	# Create beam lifecycle manager
	beam_lifecycle_manager = BeamLifecycleManager.new()
	beam_lifecycle_manager.name = "BeamLifecycleManager"
	add_child(beam_lifecycle_manager)
	beam_lifecycle_manager.initialize_lifecycle_manager()
	
	# Create beam renderer
	beam_renderer = BeamRenderer.new()
	beam_renderer.name = "BeamRenderer"
	add_child(beam_renderer)
	beam_renderer.initialize_beam_renderer()
	
	# Create beam targeting system
	beam_targeting_system = BeamTargetingSystem.new()
	beam_targeting_system.name = "BeamTargetingSystem"
	add_child(beam_targeting_system)
	beam_targeting_system.initialize_targeting_system()
	
	# Create beam penetration system
	beam_penetration_system = BeamPenetrationSystem.new()
	beam_penetration_system.name = "BeamPenetrationSystem"
	add_child(beam_penetration_system)
	beam_penetration_system.initialize_penetration_system()
	
	# Connect subsystem signals
	_connect_subsystem_signals()

## Connect subsystem signals
func _connect_subsystem_signals() -> void:
	# Lifecycle manager signals
	if beam_lifecycle_manager:
		beam_lifecycle_manager.beam_phase_changed.connect(_on_beam_phase_changed)
		beam_lifecycle_manager.beam_expired.connect(_on_beam_expired)
	
	# Continuous damage signals
	if continuous_damage_system:
		continuous_damage_system.damage_applied.connect(_on_beam_damage_applied)
	
	# Collision detector signals
	if beam_collision_detector:
		beam_collision_detector.beam_collision_detected.connect(_on_beam_collision_detected)
	
	# Targeting system signals
	if beam_targeting_system:
		beam_targeting_system.beam_target_acquired.connect(_on_beam_target_acquired)
		beam_targeting_system.beam_target_lost.connect(_on_beam_target_lost)

## Create beam data structure
func _create_beam_data(beam_id: String, beam_type: BeamType, firing_data: Dictionary) -> Dictionary:
	var config = beam_type_configs[beam_type]
	
	return {
		"beam_id": beam_id,
		"beam_type": beam_type,
		"config": config,
		"source_position": firing_data.get("source_position", Vector3.ZERO),
		"current_direction": firing_data.get("initial_direction", Vector3.FORWARD),
		"firing_ship": firing_data.get("firing_ship", null),
		"turret_node": firing_data.get("turret_node", null),
		"current_target": firing_data.get("target", null),
		"phase": BeamPhase.INACTIVE,
		"creation_time": Time.get_ticks_msec() / 1000.0,
		"last_damage_time": 0.0,
		"total_damage_dealt": 0.0,
		"collision_targets": [],
		"penetration_count": 0,
		"energy_consumed": 0.0,
		"active": false,
		"slash_current_angle": 0.0,
		"chase_attempt_count": 0,
		"type_specific_data": _create_type_specific_data(beam_type, firing_data)
	}

## Create type-specific data for beam
func _create_type_specific_data(beam_type: BeamType, firing_data: Dictionary) -> Dictionary:
	match beam_type:
		BeamType.TYPE_A_STANDARD:
			return {
				"locked_target": firing_data.get("target", null),
				"lock_position": Vector3.ZERO
			}
		
		BeamType.TYPE_B_SLASH:
			return {
				"sweep_center": firing_data.get("source_position", Vector3.ZERO),
				"sweep_direction": 1,  # 1 or -1
				"current_sweep_angle": 0.0,
				"octant_targets": []
			}
		
		BeamType.TYPE_C_TARGETING:
			return {
				"auto_target": firing_data.get("auto_target", true),
				"targeting_priority": firing_data.get("targeting_priority", "closest")
			}
		
		BeamType.TYPE_D_CHASING:
			return {
				"chase_targets": firing_data.get("chase_targets", []),
				"current_chase_target": null,
				"attempt_cooldown": 0.0
			}
		
		BeamType.TYPE_E_FIXED:
			return {
				"fixed_direction": firing_data.get("turret_direction", Vector3.FORWARD),
				"fixed_origin": firing_data.get("source_position", Vector3.ZERO)
			}
		
		_:
			return {}

## Update beam weapon behaviors
func _update_beam_behaviors(delta: float) -> void:
	for beam_id in active_beams.keys():
		var beam_data = active_beams[beam_id]
		var beam_type = beam_data.get("beam_type", BeamType.TYPE_A_STANDARD)
		
		# Update type-specific behavior
		match beam_type:
			BeamType.TYPE_A_STANDARD:
				_update_standard_beam_behavior(beam_id, beam_data, delta)
			
			BeamType.TYPE_B_SLASH:
				_update_slash_beam_behavior(beam_id, beam_data, delta)
			
			BeamType.TYPE_C_TARGETING:
				_update_targeting_beam_behavior(beam_id, beam_data, delta)
			
			BeamType.TYPE_D_CHASING:
				_update_chasing_beam_behavior(beam_id, beam_data, delta)
			
			BeamType.TYPE_E_FIXED:
				_update_fixed_beam_behavior(beam_id, beam_data, delta)

## Update standard beam behavior (Type A)
func _update_standard_beam_behavior(beam_id: String, beam_data: Dictionary, delta: float) -> void:
	var type_data = beam_data.get("type_specific_data", {})
	var locked_target = type_data.get("locked_target", null)
	
	# Standard beams maintain constant aim at target without movement
	if locked_target and is_instance_valid(locked_target):
		if type_data.get("lock_position", Vector3.ZERO) == Vector3.ZERO:
			# Lock onto target position
			type_data["lock_position"] = locked_target.global_position
			beam_data["current_direction"] = (type_data["lock_position"] - beam_data["source_position"]).normalized()

## Update slash beam behavior (Type B)
func _update_slash_beam_behavior(beam_id: String, beam_data: Dictionary, delta: float) -> void:
	var config = beam_data.get("config", {})
	var type_data = beam_data.get("type_specific_data", {})
	var sweep_speed = config.get("sweep_speed", 30.0)
	var sweep_angle = config.get("sweep_angle", 45.0)
	
	# Update sweep angle
	var angle_delta = sweep_speed * delta * type_data.get("sweep_direction", 1)
	type_data["current_sweep_angle"] += angle_delta
	
	# Reverse direction if we hit sweep limits
	if abs(type_data["current_sweep_angle"]) > sweep_angle:
		type_data["sweep_direction"] *= -1
		type_data["current_sweep_angle"] = clamp(type_data["current_sweep_angle"], -sweep_angle, sweep_angle)
	
	# Update beam direction based on sweep
	var base_direction = beam_data.get("current_direction", Vector3.FORWARD)
	var sweep_rotation = Quaternion(Vector3.UP, deg_to_rad(type_data["current_sweep_angle"]))
	beam_data["current_direction"] = sweep_rotation * base_direction

## Update targeting beam behavior (Type C)
func _update_targeting_beam_behavior(beam_id: String, beam_data: Dictionary, delta: float) -> void:
	var type_data = beam_data.get("type_specific_data", {})
	
	# Targeting lasers automatically find closest target if auto_target enabled
	if type_data.get("auto_target", true) and beam_targeting_system:
		var closest_target = beam_targeting_system.find_closest_target(beam_data["source_position"], 800.0)
		if closest_target:
			beam_data["current_target"] = closest_target
			beam_data["current_direction"] = (closest_target.global_position - beam_data["source_position"]).normalized()

## Update chasing beam behavior (Type D)
func _update_chasing_beam_behavior(beam_id: String, beam_data: Dictionary, delta: float) -> void:
	var config = beam_data.get("config", {})
	var type_data = beam_data.get("type_specific_data", {})
	var tracking_speed = config.get("tracking_speed", 45.0)
	var max_attempts = config.get("max_attempts", 5)
	
	# Attempt cooldown
	if type_data.has("attempt_cooldown"):
		type_data["attempt_cooldown"] -= delta
	
	# Track current target
	var current_target = type_data.get("current_chase_target", null)
	if current_target and is_instance_valid(current_target):
		# Update beam direction to track target
		var target_direction = (current_target.global_position - beam_data["source_position"]).normalized()
		var current_direction = beam_data.get("current_direction", Vector3.FORWARD)
		
		# Smoothly track towards target
		var tracking_rate = deg_to_rad(tracking_speed) * delta
		beam_data["current_direction"] = current_direction.slerp(target_direction, tracking_rate)
	
	# Switch targets if current target is lost and we haven't exceeded attempts
	elif beam_data.get("chase_attempt_count", 0) < max_attempts:
		if type_data.get("attempt_cooldown", 0.0) <= 0.0:
			_select_new_chase_target(beam_id, beam_data)
			type_data["attempt_cooldown"] = 0.5  # Half second between attempts

## Update fixed beam behavior (Type E)
func _update_fixed_beam_behavior(beam_id: String, beam_data: Dictionary, delta: float) -> void:
	var type_data = beam_data.get("type_specific_data", {})
	
	# Fixed beams maintain their initial direction from turret
	beam_data["current_direction"] = type_data.get("fixed_direction", Vector3.FORWARD)

## Select new chase target for chasing beam
func _select_new_chase_target(beam_id: String, beam_data: Dictionary) -> void:
	if not beam_targeting_system:
		return
	
	var type_data = beam_data.get("type_specific_data", {})
	var chase_targets = type_data.get("chase_targets", [])
	
	# Find next valid target
	for target in chase_targets:
		if target and is_instance_valid(target):
			type_data["current_chase_target"] = target
			beam_data["chase_attempt_count"] += 1
			
			if enable_beam_debugging:
				print("BeamWeaponSystem: Chasing beam %s switching to new target" % beam_id)
			return
	
	# No more targets available
	stop_beam_weapon(beam_id, "no_targets")

## Signal handlers
func _on_weapon_triggered(weapon_data: Dictionary) -> void:
	var weapon_type = weapon_data.get("weapon_type", -1)
	
	# Check if this is a beam weapon
	if weapon_type >= WeaponTypes.Type.BEAM_TYPE_A and weapon_type <= WeaponTypes.Type.BEAM_TYPE_E:
		var beam_type = weapon_type - WeaponTypes.Type.BEAM_TYPE_A
		weapon_data["beam_type"] = beam_type
		fire_beam_weapon(weapon_data)

func _on_beam_phase_changed(beam_id: String, old_phase: BeamPhase, new_phase: BeamPhase) -> void:
	if active_beams.has(beam_id):
		active_beams[beam_id]["phase"] = new_phase
	
	beam_lifecycle_changed.emit(beam_id, str(old_phase), str(new_phase))
	
	if enable_beam_debugging:
		print("BeamWeaponSystem: Beam %s phase changed from %s to %s" % [
			beam_id, str(old_phase), str(new_phase)
		])

func _on_beam_expired(beam_id: String) -> void:
	if active_beams.has(beam_id):
		stop_beam_weapon(beam_id, "expired")
		active_beams.erase(beam_id)
		beam_performance_stats["active_beam_count"] = active_beams.size()

func _on_beam_damage_applied(beam_id: String, target: Node, damage_amount: float) -> void:
	if active_beams.has(beam_id):
		active_beams[beam_id]["total_damage_dealt"] += damage_amount
		active_beams[beam_id]["last_damage_time"] = Time.get_ticks_msec() / 1000.0
	
	beam_performance_stats["damage_applications"] += 1
	
	var hit_data = {
		"beam_id": beam_id,
		"target": target,
		"damage_amount": damage_amount,
		"hit_time": Time.get_ticks_msec() / 1000.0
	}
	beam_weapon_hit.emit(hit_data)

func _on_beam_collision_detected(beam_id: String, collision_data: Dictionary) -> void:
	beam_performance_stats["collision_checks"] += 1
	
	# Handle penetration through penetration system
	if beam_penetration_system:
		beam_penetration_system.process_beam_collision(beam_id, collision_data)

func _on_beam_target_acquired(beam_id: String, target: Node) -> void:
	if active_beams.has(beam_id):
		active_beams[beam_id]["current_target"] = target
	
	beam_target_acquired.emit(beam_id, target)

func _on_beam_target_lost(beam_id: String, target: Node) -> void:
	if active_beams.has(beam_id):
		active_beams[beam_id]["current_target"] = null
	
	beam_target_lost.emit(beam_id, target)

## Process frame updates
func _process(delta: float) -> void:
	beam_update_timer += delta
	
	if beam_update_timer >= beam_update_frequency:
		beam_update_timer = 0.0
		_update_beam_behaviors(beam_update_frequency)