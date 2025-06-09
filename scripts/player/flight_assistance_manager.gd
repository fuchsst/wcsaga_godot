class_name FlightAssistanceManager
extends Node

## Flight assistance system providing autopilot features, collision avoidance, and velocity matching.
## Offers optional assistance that enhances accessibility without compromising skill ceiling.

signal assistance_mode_changed(mode: AssistanceMode, enabled: bool)
signal collision_warning(threat_object: Node3D, distance: float, severity: float)
signal velocity_match_complete(target_velocity: Vector3)
signal autopilot_waypoint_reached(waypoint: Vector3)
signal assistance_override_activated(reason: String)

enum AssistanceMode {
	AUTO_LEVEL,
	COLLISION_AVOIDANCE,
	VELOCITY_MATCHING,
	GLIDE_MODE,
	FORMATION_ASSIST,
	APPROACH_ASSIST,
	LANDING_ASSIST
}

# Assistance configuration
@export var auto_level_strength: float = 0.3
@export var collision_avoidance_range: float = 500.0
@export var collision_response_strength: float = 0.8
@export var velocity_match_tolerance: float = 5.0
@export var assistance_override_threshold: float = 0.7

# Active assistance modes
var active_modes: Dictionary = {}
var assistance_priorities: Array[AssistanceMode] = [
	AssistanceMode.COLLISION_AVOIDANCE,
	AssistanceMode.LANDING_ASSIST,
	AssistanceMode.APPROACH_ASSIST,
	AssistanceMode.FORMATION_ASSIST,
	AssistanceMode.VELOCITY_MATCHING,
	AssistanceMode.AUTO_LEVEL,
	AssistanceMode.GLIDE_MODE
]

# Component references
var flight_dynamics: FlightDynamicsController
var physics_body: RigidBody3D
var ship_controller: ShipBase

# Collision avoidance
var collision_detector: Area3D
var threat_objects: Array[Node3D] = []
var collision_override_active: bool = false

# Velocity matching
var velocity_match_target: Node3D
var target_velocity: Vector3 = Vector3.ZERO
var velocity_match_active: bool = false

# Auto-level system
var reference_up_vector: Vector3 = Vector3.UP
var auto_level_active: bool = false

# Glide mode
var glide_velocity: Vector3 = Vector3.ZERO
var glide_mode_active: bool = false

# Formation assistance
var formation_leader: Node3D
var formation_offset: Vector3 = Vector3.ZERO
var formation_assist_active: bool = false

# Approach assistance
var approach_target: Node3D
var approach_distance: float = 100.0
var approach_assist_active: bool = false

# Landing assistance
var landing_target: Node3D
var landing_approach_vector: Vector3 = Vector3.ZERO
var landing_assist_active: bool = false

# Performance tracking
var assistance_computations_per_frame: int = 0
var max_computations_per_frame: int = 10
var last_assistance_update: float = 0.0

func _ready() -> void:
	_initialize_flight_assistance()
	_setup_collision_detection()
	_initialize_assistance_modes()

func _initialize_flight_assistance() -> void:
	\"\"\"Initialize flight assistance system with component references.\"\"\"
	
	# Find required components
	flight_dynamics = get_node(\"../FlightDynamicsController\") as FlightDynamicsController
	physics_body = get_parent() as RigidBody3D
	ship_controller = get_parent() as ShipBase
	
	if not flight_dynamics:
		push_warning(\"FlightAssistanceManager: FlightDynamicsController not found\")
	
	if not physics_body:
		push_warning(\"FlightAssistanceManager: RigidBody3D not found\")
	
	if not ship_controller:
		push_warning(\"FlightAssistanceManager: ShipBase not found\")
	
	print(\"FlightAssistanceManager: Initialized with %d assistance modes\" % AssistanceMode.size())

func _setup_collision_detection() -> void:
	\"\"\"Setup collision detection system for avoidance assistance.\"\"\"
	
	collision_detector = Area3D.new()
	collision_detector.name = \"CollisionDetector\"
	add_child(collision_detector)
	
	# Create detection sphere
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = collision_avoidance_range
	
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.shape = sphere_shape
	collision_detector.add_child(collision_shape)
	
	# Configure collision layers
	collision_detector.collision_layer = 0  # Don't collide with anything
	collision_detector.collision_mask = 0b0000_0001  # Detect objects on layer 1
	
	# Connect signals
	collision_detector.body_entered.connect(_on_collision_threat_detected)
	collision_detector.body_exited.connect(_on_collision_threat_cleared)

func _initialize_assistance_modes() -> void:
	\"\"\"Initialize all assistance mode states.\"\"\"
	
	for mode in AssistanceMode.values():
		active_modes[mode] = false

func _process(delta: float) -> void:
	if not flight_dynamics or not physics_body:
		return
	
	assistance_computations_per_frame = 0
	
	# Process active assistance modes in priority order
	for mode in assistance_priorities:
		if active_modes.get(mode, false) and assistance_computations_per_frame < max_computations_per_frame:
			_process_assistance_mode(mode, delta)
			assistance_computations_per_frame += 1
	
	last_assistance_update = Time.get_ticks_usec() / 1000000.0

func _process_assistance_mode(mode: AssistanceMode, delta: float) -> void:
	\"\"\"Process individual assistance mode.\"\"\"
	
	match mode:
		AssistanceMode.AUTO_LEVEL:
			_process_auto_level(delta)
		AssistanceMode.COLLISION_AVOIDANCE:
			_process_collision_avoidance(delta)
		AssistanceMode.VELOCITY_MATCHING:
			_process_velocity_matching(delta)
		AssistanceMode.GLIDE_MODE:
			_process_glide_mode(delta)
		AssistanceMode.FORMATION_ASSIST:
			_process_formation_assist(delta)
		AssistanceMode.APPROACH_ASSIST:
			_process_approach_assist(delta)
		AssistanceMode.LANDING_ASSIST:
			_process_landing_assist(delta)

func _process_auto_level(delta: float) -> void:
	\"\"\"Process auto-leveling assistance.\"\"\"
	
	if not auto_level_active:
		return
	
	# Get current ship orientation
	var ship_transform: Transform3D = physics_body.global_transform
	var current_up: Vector3 = ship_transform.basis.y
	
	# Calculate roll correction needed
	var roll_error: Vector3 = reference_up_vector.cross(current_up)
	var roll_magnitude: float = roll_error.length()
	
	if roll_magnitude > 0.01:
		# Apply gentle roll correction
		var correction_strength: float = auto_level_strength * roll_magnitude
		var roll_axis: Vector3 = ship_transform.basis.z  # Ship's forward vector
		var roll_correction: float = roll_error.dot(roll_axis) * correction_strength
		
		# Apply correction through flight dynamics
		flight_dynamics.set_roll_input(flight_dynamics.roll_input + roll_correction)

func _process_collision_avoidance(delta: float) -> void:
	\"\"\"Process collision avoidance assistance.\"\"\"
	
	if threat_objects.is_empty():
		collision_override_active = false
		return
	
	var avoidance_vector: Vector3 = Vector3.ZERO
	var max_threat_severity: float = 0.0
	
	# Calculate avoidance vector from all threats
	for threat in threat_objects:
		if not is_instance_valid(threat):
			continue
		
		var threat_position: Vector3 = threat.global_position
		var ship_position: Vector3 = physics_body.global_position
		var threat_vector: Vector3 = threat_position - ship_position
		var threat_distance: float = threat_vector.length()
		
		if threat_distance > collision_avoidance_range:
			continue
		
		# Calculate threat severity (closer = more severe)
		var threat_severity: float = 1.0 - (threat_distance / collision_avoidance_range)
		max_threat_severity = maxf(max_threat_severity, threat_severity)
		
		# Calculate avoidance direction (away from threat)
		var avoidance_direction: Vector3 = -threat_vector.normalized()
		avoidance_vector += avoidance_direction * threat_severity
		
		# Emit collision warning
		collision_warning.emit(threat, threat_distance, threat_severity)
	
	# Apply avoidance input if significant threat detected
	if avoidance_vector.length() > 0.1:
		var ship_transform: Transform3D = physics_body.global_transform
		var local_avoidance: Vector3 = ship_transform.basis.inverse() * avoidance_vector
		
		# Apply avoidance through flight dynamics
		var avoidance_strength: float = collision_response_strength * max_threat_severity
		
		# Override player input if threat is severe
		if max_threat_severity > assistance_override_threshold:
			if not collision_override_active:
				collision_override_active = true
				assistance_override_activated.emit(\"Collision threat detected\")
			
			flight_dynamics.set_pitch_input(local_avoidance.x * avoidance_strength)
			flight_dynamics.set_yaw_input(local_avoidance.y * avoidance_strength)
		else:
			# Gentle assistance
			flight_dynamics.set_pitch_input(flight_dynamics.pitch_input + local_avoidance.x * avoidance_strength * 0.3)
			flight_dynamics.set_yaw_input(flight_dynamics.yaw_input + local_avoidance.y * avoidance_strength * 0.3)

func _process_velocity_matching(delta: float) -> void:
	\"\"\"Process velocity matching assistance.\"\"\"
	
	if not velocity_match_active or not velocity_match_target:
		return
	
	# Get target velocity
	var current_target_velocity: Vector3
	if velocity_match_target.has_method(\"get_velocity\"):
		current_target_velocity = velocity_match_target.get_velocity()
	elif velocity_match_target is RigidBody3D:
		current_target_velocity = (velocity_match_target as RigidBody3D).linear_velocity
	else:
		current_target_velocity = target_velocity
	
	# Calculate velocity difference
	var current_velocity: Vector3 = physics_body.linear_velocity
	var velocity_diff: Vector3 = current_target_velocity - current_velocity
	var velocity_error: float = velocity_diff.length()
	
	# Check if velocity matching is complete
	if velocity_error < velocity_match_tolerance:
		velocity_match_complete.emit(current_target_velocity)
		return
	
	# Convert velocity difference to thrust commands
	var ship_transform: Transform3D = physics_body.global_transform
	var local_velocity_diff: Vector3 = ship_transform.basis.inverse() * velocity_diff
	
	# Apply velocity matching thrust
	var match_strength: float = minf(velocity_error / 50.0, 1.0)  # Scale by velocity error
	flight_dynamics.set_throttle_input(local_velocity_diff.z * match_strength)
	flight_dynamics.set_strafe_input(Vector3(local_velocity_diff.x, local_velocity_diff.y, 0.0) * match_strength)

func _process_glide_mode(delta: float) -> void:
	\"\"\"Process glide mode assistance (maintain velocity vector).\"\"\"
	
	if not glide_mode_active:
		return
	
	# Maintain current velocity direction but allow orientation changes
	var current_velocity: Vector3 = physics_body.linear_velocity
	
	if current_velocity.length() > 1.0:
		# Store current velocity as glide velocity if not set
		if glide_velocity.length() < 1.0:
			glide_velocity = current_velocity
		
		# Calculate thrust needed to maintain glide velocity
		var velocity_diff: Vector3 = glide_velocity - current_velocity
		var ship_transform: Transform3D = physics_body.global_transform
		var local_velocity_diff: Vector3 = ship_transform.basis.inverse() * velocity_diff
		
		# Apply gentle corrections to maintain glide
		var glide_strength: float = 0.3
		flight_dynamics.set_throttle_input(flight_dynamics.throttle_input + local_velocity_diff.z * glide_strength)

func _process_formation_assist(delta: float) -> void:
	\"\"\"Process formation flying assistance.\"\"\"
	
	if not formation_assist_active or not formation_leader:
		return
	
	# Calculate desired position relative to formation leader
	var leader_transform: Transform3D = formation_leader.global_transform
	var desired_position: Vector3 = leader_transform.origin + formation_offset
	var current_position: Vector3 = physics_body.global_position
	
	# Calculate position error
	var position_error: Vector3 = desired_position - current_position
	var error_magnitude: float = position_error.length()
	
	if error_magnitude > 1.0:
		# Convert position error to thrust commands
		var ship_transform: Transform3D = physics_body.global_transform
		var local_error: Vector3 = ship_transform.basis.inverse() * position_error
		
		# Apply formation keeping thrust
		var formation_strength: float = minf(error_magnitude / 100.0, 0.5)
		flight_dynamics.set_throttle_input(flight_dynamics.throttle_input + local_error.z * formation_strength)
		flight_dynamics.set_strafe_input(flight_dynamics.strafe_input + Vector3(local_error.x, local_error.y, 0.0) * formation_strength)

func _process_approach_assist(delta: float) -> void:
	\"\"\"Process approach assistance for docking/landing.\"\"\"
	
	if not approach_assist_active or not approach_target:
		return
	
	var target_position: Vector3 = approach_target.global_position
	var current_position: Vector3 = physics_body.global_position
	var approach_vector: Vector3 = target_position - current_position
	var distance_to_target: float = approach_vector.length()
	
	# Calculate desired approach speed based on distance
	var desired_speed: float = minf(distance_to_target / 10.0, 20.0)  # Slower as we get closer
	
	if distance_to_target > approach_distance:
		# Calculate approach direction and speed
		var approach_direction: Vector3 = approach_vector.normalized()
		var desired_velocity: Vector3 = approach_direction * desired_speed
		
		# Apply approach assistance
		var ship_transform: Transform3D = physics_body.global_transform
		var local_desired_velocity: Vector3 = ship_transform.basis.inverse() * desired_velocity
		
		flight_dynamics.set_throttle_input(local_desired_velocity.z)
		flight_dynamics.set_strafe_input(Vector3(local_desired_velocity.x, local_desired_velocity.y, 0.0))

func _process_landing_assist(delta: float) -> void:
	\"\"\"Process landing assistance for final approach.\"\"\"
	
	if not landing_assist_active or not landing_target:
		return
	
	# Implement precise landing assistance
	# This would include final approach alignment and speed control
	pass

# Public API - Assistance Mode Control

func enable_assistance_mode(mode: AssistanceMode) -> void:
	\"\"\"Enable specified assistance mode.\"\"\"
	
	if not active_modes.get(mode, false):
		active_modes[mode] = true
		_activate_assistance_mode(mode)
		assistance_mode_changed.emit(mode, true)
		print(\"FlightAssistanceManager: Enabled %s\" % AssistanceMode.keys()[mode])

func disable_assistance_mode(mode: AssistanceMode) -> void:
	\"\"\"Disable specified assistance mode.\"\"\"
	
	if active_modes.get(mode, false):
		active_modes[mode] = false
		_deactivate_assistance_mode(mode)
		assistance_mode_changed.emit(mode, false)
		print(\"FlightAssistanceManager: Disabled %s\" % AssistanceMode.keys()[mode])

func toggle_assistance_mode(mode: AssistanceMode) -> void:
	\"\"\"Toggle specified assistance mode.\"\"\"
	
	if is_assistance_mode_active(mode):
		disable_assistance_mode(mode)
	else:
		enable_assistance_mode(mode)

func is_assistance_mode_active(mode: AssistanceMode) -> bool:
	\"\"\"Check if specified assistance mode is active.\"\"\"
	return active_modes.get(mode, false)

func _activate_assistance_mode(mode: AssistanceMode) -> void:
	\"\"\"Activate specific assistance mode.\"\"\"
	
	match mode:
		AssistanceMode.AUTO_LEVEL:
			auto_level_active = true
		AssistanceMode.COLLISION_AVOIDANCE:
			if collision_detector:
				collision_detector.monitoring = true
		AssistanceMode.VELOCITY_MATCHING:
			velocity_match_active = false  # Needs target
		AssistanceMode.GLIDE_MODE:
			glide_mode_active = true
			glide_velocity = physics_body.linear_velocity
		AssistanceMode.FORMATION_ASSIST:
			formation_assist_active = false  # Needs leader
		AssistanceMode.APPROACH_ASSIST:
			approach_assist_active = false  # Needs target
		AssistanceMode.LANDING_ASSIST:
			landing_assist_active = false  # Needs target

func _deactivate_assistance_mode(mode: AssistanceMode) -> void:
	\"\"\"Deactivate specific assistance mode.\"\"\"
	
	match mode:
		AssistanceMode.AUTO_LEVEL:
			auto_level_active = false
		AssistanceMode.COLLISION_AVOIDANCE:
			if collision_detector:
				collision_detector.monitoring = false
			threat_objects.clear()
			collision_override_active = false
		AssistanceMode.VELOCITY_MATCHING:
			velocity_match_active = false
			velocity_match_target = null
		AssistanceMode.GLIDE_MODE:
			glide_mode_active = false
			glide_velocity = Vector3.ZERO
		AssistanceMode.FORMATION_ASSIST:
			formation_assist_active = false
			formation_leader = null
		AssistanceMode.APPROACH_ASSIST:
			approach_assist_active = false
			approach_target = null
		AssistanceMode.LANDING_ASSIST:
			landing_assist_active = false
			landing_target = null

# Public API - Target Setting

func set_velocity_match_target(target: Node3D) -> void:
	\"\"\"Set target for velocity matching assistance.\"\"\"
	velocity_match_target = target
	velocity_match_active = (target != null) and is_assistance_mode_active(AssistanceMode.VELOCITY_MATCHING)

func set_formation_leader(leader: Node3D, offset: Vector3) -> void:
	\"\"\"Set formation leader and offset for formation assistance.\"\"\"
	formation_leader = leader
	formation_offset = offset
	formation_assist_active = (leader != null) and is_assistance_mode_active(AssistanceMode.FORMATION_ASSIST)

func set_approach_target(target: Node3D, distance: float = 100.0) -> void:
	\"\"\"Set target for approach assistance.\"\"\"
	approach_target = target
	approach_distance = distance
	approach_assist_active = (target != null) and is_assistance_mode_active(AssistanceMode.APPROACH_ASSIST)

func set_landing_target(target: Node3D) -> void:
	\"\"\"Set target for landing assistance.\"\"\"
	landing_target = target
	landing_assist_active = (target != null) and is_assistance_mode_active(AssistanceMode.LANDING_ASSIST)

# Public API - Configuration

func set_auto_level_strength(strength: float) -> void:
	\"\"\"Set auto-level assistance strength.\"\"\"
	auto_level_strength = clampf(strength, 0.0, 1.0)

func set_collision_avoidance_range(range: float) -> void:
	\"\"\"Set collision avoidance detection range.\"\"\"
	collision_avoidance_range = maxf(10.0, range)
	if collision_detector:
		var shape: SphereShape3D = collision_detector.get_child(0).shape as SphereShape3D
		if shape:
			shape.radius = collision_avoidance_range

func set_reference_up_vector(up_vector: Vector3) -> void:
	\"\"\"Set reference up vector for auto-leveling.\"\"\"
	reference_up_vector = up_vector.normalized()

# Signal handlers

func _on_collision_threat_detected(body: Node3D) -> void:
	\"\"\"Handle collision threat detection.\"\"\"
	if not threat_objects.has(body):
		threat_objects.append(body)

func _on_collision_threat_cleared(body: Node3D) -> void:
	\"\"\"Handle collision threat clearing.\"\"\"
	threat_objects.erase(body)

# Public API - State Queries

func get_active_assistance_modes() -> Array[AssistanceMode]:
	\"\"\"Get list of currently active assistance modes.\"\"\"
	var active: Array[AssistanceMode] = []
	for mode in AssistanceMode.values():
		if active_modes.get(mode, false):
			active.append(mode)
	return active

func get_collision_threats() -> Array[Node3D]:
	\"\"\"Get list of current collision threats.\"\"\"
	return threat_objects.duplicate()

func is_collision_override_active() -> bool:
	\"\"\"Check if collision avoidance has overridden player input.\"\"\"
	return collision_override_active

func get_performance_stats() -> Dictionary:
	\"\"\"Get flight assistance performance statistics.\"\"\"
	
	return {
		\"active_modes\": get_active_assistance_modes().size(),
		\"collision_threats\": threat_objects.size(),
		\"collision_override_active\": collision_override_active,
		\"velocity_match_active\": velocity_match_active,
		\"formation_assist_active\": formation_assist_active,
		\"approach_assist_active\": approach_assist_active,
		\"landing_assist_active\": landing_assist_active,
		\"computations_per_frame\": assistance_computations_per_frame,
		\"last_update_time\": last_assistance_update
	}