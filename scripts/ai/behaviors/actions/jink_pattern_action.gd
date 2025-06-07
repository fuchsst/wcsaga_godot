class_name JinkPatternAction
extends WCSBTAction

## Rapid directional changes (jinking) to avoid enemy targeting
## Executes unpredictable movement patterns to break enemy weapon locks

enum JinkType {
	RANDOM_WALK,      # Random directional changes
	SERPENTINE,       # S-curve serpentine pattern
	BOX_PATTERN,      # Rectangular box pattern
	FIGURE_EIGHT,     # Figure-8 pattern
	CHAOS_PATTERN,    # Highly unpredictable chaos pattern
	DEFENSIVE_WEAVE   # Defensive weaving pattern
}

@export var jink_type: JinkType = JinkType.RANDOM_WALK
@export var jink_intensity: float = 1.0
@export var change_frequency: float = 0.8  # Seconds between direction changes
@export var max_displacement: float = 300.0
@export var maintain_general_heading: bool = true

var jink_start_time: float = 0.0
var jink_duration: float = 15.0
var current_jink_vector: Vector3 = Vector3.ZERO
var last_direction_change: float = 0.0
var jink_progress: float = 0.0
var direction_change_count: int = 0

var base_heading: Vector3
var threat_position: Vector3
var previous_positions: Array[Vector3] = []
var unpredictability_factor: float = 0.0

signal jink_pattern_started(type: JinkType, intensity: float)
signal jink_pattern_completed(direction_changes: int, unpredictability: float)
signal direction_changed(new_vector: Vector3, change_number: int)

func _setup() -> void:
	super._setup()
	jink_start_time = 0.0
	jink_progress = 0.0
	direction_change_count = 0
	last_direction_change = 0.0
	previous_positions.clear()
	
	# Establish base heading
	if maintain_general_heading:
		base_heading = get_ship_forward_vector()
	else:
		base_heading = Vector3.FORWARD
	
	# Find threat for reference
	if ai_agent and ai_agent.has_method("get_primary_threat"):
		var threat: Node3D = ai_agent.get_primary_threat()
		if threat:
			threat_position = threat.global_position
	
	# Apply skill-based adjustments
	_apply_skill_adjustments()

func execute_wcs_action(delta: float) -> int:
	if jink_start_time <= 0.0:
		_start_jink_pattern()
	
	var elapsed_time: float = Time.get_time_from_start() - jink_start_time
	jink_progress = elapsed_time / jink_duration
	
	if jink_progress >= 1.0:
		return _complete_jink_pattern()
	
	# Check if it's time for a direction change
	if elapsed_time - last_direction_change >= change_frequency:
		_change_direction()
		last_direction_change = elapsed_time
	
	# Execute current jink movement
	_execute_jink_movement(delta)
	
	# Track position for unpredictability analysis
	_track_position()
	
	return 2  # RUNNING

func _apply_skill_adjustments() -> void:
	"""Apply pilot skill-based adjustments to jinking parameters"""
	var skill_level: float = 0.7
	if ai_agent and ai_agent.has_method("get_skill_level"):
		skill_level = ai_agent.get_skill_level()
	
	# Skilled pilots can execute more rapid, precise jinks
	change_frequency = lerp(1.2, 0.5, skill_level)
	jink_intensity = lerp(0.7, 1.3, skill_level)
	
	# Novice pilots have less controlled movements
	if skill_level < 0.4:
		max_displacement *= 0.8  # Smaller movements
		change_frequency += randf_range(-0.2, 0.3)  # Less consistent timing

func _start_jink_pattern() -> void:
	"""Initialize jink pattern execution"""
	jink_start_time = Time.get_time_from_start()
	last_direction_change = 0.0
	
	# Initialize first direction
	_change_direction()
	
	jink_pattern_started.emit(jink_type, jink_intensity)

func _change_direction() -> void:
	"""Change jinking direction based on selected pattern"""
	direction_change_count += 1
	
	match jink_type:
		JinkType.RANDOM_WALK:
			current_jink_vector = _generate_random_direction()
		JinkType.SERPENTINE:
			current_jink_vector = _generate_serpentine_direction()
		JinkType.BOX_PATTERN:
			current_jink_vector = _generate_box_pattern_direction()
		JinkType.FIGURE_EIGHT:
			current_jink_vector = _generate_figure_eight_direction()
		JinkType.CHAOS_PATTERN:
			current_jink_vector = _generate_chaos_direction()
		JinkType.DEFENSIVE_WEAVE:
			current_jink_vector = _generate_defensive_weave_direction()
	
	# Apply intensity scaling
	current_jink_vector *= jink_intensity
	
	# Ensure vector is within max displacement
	if current_jink_vector.length() > max_displacement:
		current_jink_vector = current_jink_vector.normalized() * max_displacement
	
	direction_changed.emit(current_jink_vector, direction_change_count)

func _generate_random_direction() -> Vector3:
	"""Generate random direction for unpredictable movement"""
	var random_vector: Vector3 = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-0.5, 0.5),  # Less vertical movement
		randf_range(-1.0, 1.0)
	).normalized()
	
	return random_vector * randf_range(150.0, max_displacement)

func _generate_serpentine_direction() -> Vector3:
	"""Generate serpentine S-curve direction"""
	var serpentine_time: float = direction_change_count * 0.5
	var lateral_direction: Vector3 = base_heading.cross(Vector3.UP).normalized()
	
	# Alternate left and right with smooth curves
	var side_factor: float = sin(serpentine_time) * (1.0 if direction_change_count % 2 == 0 else -1.0)
	var forward_component: Vector3 = base_heading * 100.0
	var lateral_component: Vector3 = lateral_direction * side_factor * 200.0
	
	return forward_component + lateral_component

func _generate_box_pattern_direction() -> Vector3:
	"""Generate rectangular box pattern direction"""
	var pattern_phase: int = direction_change_count % 4
	var displacement: float = max_displacement * 0.8
	
	match pattern_phase:
		0:  # Right
			return base_heading.cross(Vector3.UP).normalized() * displacement
		1:  # Forward
			return base_heading * displacement
		2:  # Left
			return -base_heading.cross(Vector3.UP).normalized() * displacement
		3:  # Back
			return -base_heading * displacement * 0.5
		_:
			return Vector3.ZERO

func _generate_figure_eight_direction() -> Vector3:
	"""Generate figure-8 pattern direction"""
	var eight_time: float = direction_change_count * 0.3
	var radius: float = max_displacement * 0.6
	
	# Create figure-8 using parametric equations
	var x: float = radius * sin(eight_time)
	var z: float = radius * sin(eight_time * 2.0) * 0.5
	var y: float = 0.0
	
	# Transform to ship's coordinate system
	var right_vector: Vector3 = base_heading.cross(Vector3.UP).normalized()
	var up_vector: Vector3 = base_heading.cross(right_vector).normalized()
	
	return right_vector * x + base_heading * z + up_vector * y

func _generate_chaos_direction() -> Vector3:
	"""Generate highly unpredictable chaos pattern"""
	var chaos_vector: Vector3 = Vector3.ZERO
	
	# Multiple frequency components for chaos
	var time_factor: float = direction_change_count * 0.1
	var chaos_x: float = sin(time_factor * 7.3) + cos(time_factor * 3.7) * 0.5
	var chaos_y: float = sin(time_factor * 5.1) * 0.3
	var chaos_z: float = cos(time_factor * 11.2) + sin(time_factor * 2.9) * 0.7
	
	chaos_vector = Vector3(chaos_x, chaos_y, chaos_z).normalized()
	
	# Add random component
	var random_component: Vector3 = Vector3(
		randf_range(-0.5, 0.5),
		randf_range(-0.3, 0.3),
		randf_range(-0.5, 0.5)
	)
	
	chaos_vector += random_component
	
	return chaos_vector.normalized() * randf_range(100.0, max_displacement)

func _generate_defensive_weave_direction() -> Vector3:
	"""Generate defensive weaving pattern"""
	var weave_amplitude: float = max_displacement * 0.7
	var weave_frequency: float = direction_change_count * 0.4
	
	# Create weaving motion perpendicular to threat direction
	var to_threat: Vector3 = Vector3.ZERO
	if threat_position != Vector3.ZERO:
		to_threat = (threat_position - get_ship_position()).normalized()
	else:
		to_threat = -base_heading
	
	# Perpendicular weaving direction
	var weave_axis: Vector3 = to_threat.cross(Vector3.UP).normalized()
	if weave_axis.length() < 0.1:
		weave_axis = to_threat.cross(Vector3.RIGHT).normalized()
	
	# Add vertical component for 3D weaving
	var vertical_axis: Vector3 = to_threat.cross(weave_axis).normalized()
	
	var horizontal_weave: float = sin(weave_frequency) * weave_amplitude
	var vertical_weave: float = cos(weave_frequency * 1.3) * weave_amplitude * 0.4
	
	return weave_axis * horizontal_weave + vertical_axis * vertical_weave

func _execute_jink_movement(delta: float) -> void:
	"""Execute the current jink movement"""
	if not ship_controller:
		return
	
	var ship_pos: Vector3 = get_ship_position()
	var target_position: Vector3 = ship_pos + current_jink_vector
	
	# Apply general heading maintenance if enabled
	if maintain_general_heading:
		var heading_component: Vector3 = base_heading * 50.0
		target_position += heading_component
	
	# Add some smoothing between direction changes
	var time_since_change: float = (Time.get_time_from_start() - jink_start_time) - last_direction_change
	var smoothing_factor: float = clamp(time_since_change / (change_frequency * 0.3), 0.0, 1.0)
	
	# Smooth transition to new direction
	if smoothing_factor < 1.0:
		var smooth_vector: Vector3 = current_jink_vector * smoothing_factor
		target_position = ship_pos + smooth_vector
	
	set_ship_target_position(target_position)
	
	# Adjust throttle for jinking effectiveness
	var throttle: float = _calculate_jink_throttle()
	_set_ship_throttle(throttle)

func _calculate_jink_throttle() -> float:
	"""Calculate appropriate throttle for jink pattern"""
	var base_throttle: float = 1.0
	
	match jink_type:
		JinkType.RANDOM_WALK, JinkType.CHAOS_PATTERN:
			base_throttle = 0.9  # Slightly reduced for control
		JinkType.SERPENTINE, JinkType.DEFENSIVE_WEAVE:
			base_throttle = 1.1  # Faster for effectiveness
		JinkType.BOX_PATTERN:
			base_throttle = 0.8  # Slower for precise corners
		JinkType.FIGURE_EIGHT:
			base_throttle = 1.0  # Standard speed
	
	# Adjust for jink intensity
	base_throttle *= (0.8 + jink_intensity * 0.3)
	
	return clamp(base_throttle, 0.6, 1.3)

func _track_position() -> void:
	"""Track position history for unpredictability analysis"""
	var current_pos: Vector3 = get_ship_position()
	previous_positions.append(current_pos)
	
	# Keep only recent positions
	if previous_positions.size() > 10:
		previous_positions.pop_front()
	
	# Update unpredictability factor
	_calculate_unpredictability()

func _calculate_unpredictability() -> void:
	"""Calculate how unpredictable the movement pattern is"""
	if previous_positions.size() < 3:
		return
	
	var direction_changes: int = 0
	var total_distance: float = 0.0
	
	for i in range(1, previous_positions.size()):
		var current_direction: Vector3 = (previous_positions[i] - previous_positions[i-1]).normalized()
		
		if i > 1:
			var previous_direction: Vector3 = (previous_positions[i-1] - previous_positions[i-2]).normalized()
			var angle_change: float = current_direction.angle_to(previous_direction)
			
			if angle_change > 0.5:  # Significant direction change
				direction_changes += 1
		
		total_distance += previous_positions[i].distance_to(previous_positions[i-1])
	
	# Calculate unpredictability based on direction changes and pattern complexity
	var change_rate: float = float(direction_changes) / float(previous_positions.size() - 1)
	unpredictability_factor = clamp(change_rate + (total_distance / 1000.0) * 0.1, 0.0, 1.0)

func _complete_jink_pattern() -> int:
	"""Complete jink pattern execution"""
	jink_pattern_completed.emit(direction_change_count, unpredictability_factor)
	
	# Success if we made a reasonable number of direction changes
	return 1 if direction_change_count >= 3 else 0

func get_jink_effectiveness() -> float:
	"""Get current jinking effectiveness rating"""
	var effectiveness: float = 0.5
	
	# Base effectiveness on unpredictability
	effectiveness += unpredictability_factor * 0.3
	
	# Bonus for direction changes
	var change_bonus: float = clamp(float(direction_change_count) / 10.0, 0.0, 0.3)
	effectiveness += change_bonus
	
	# Pattern-specific bonuses
	match jink_type:
		JinkType.CHAOS_PATTERN:
			effectiveness += 0.15  # Chaos is inherently effective
		JinkType.DEFENSIVE_WEAVE:
			effectiveness += 0.1   # Defensive weaving is tactical
		JinkType.RANDOM_WALK:
			effectiveness += 0.05  # Random movement is somewhat effective
	
	return clamp(effectiveness, 0.0, 1.0)

func get_pattern_status() -> Dictionary:
	"""Get current pattern status information"""
	return {
		"jink_type": JinkType.keys()[jink_type],
		"progress": jink_progress,
		"direction_changes": direction_change_count,
		"unpredictability": unpredictability_factor,
		"effectiveness": get_jink_effectiveness(),
		"current_vector": current_jink_vector,
		"intensity": jink_intensity
	}