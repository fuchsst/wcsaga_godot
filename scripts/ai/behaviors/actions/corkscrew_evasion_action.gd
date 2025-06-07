class_name CorkscrewEvasionAction
extends WCSBTAction

## Corkscrew evasive maneuver for evading sustained enemy fire
## Executes a complex helical flight pattern to avoid weapon tracking

enum CorkscrewPattern {
	STANDARD,         # Standard corkscrew pattern
	TIGHT_SPIRAL,     # Tight spiral for close-range evasion
	WIDE_HELIX,       # Wide helix for long-range evasion
	IRREGULAR,        # Irregular pattern to break predictability
	COMBAT_ROLL       # Combat roll variation
}

@export var corkscrew_pattern: CorkscrewPattern = CorkscrewPattern.STANDARD
@export var auto_pattern_selection: bool = true
@export var duration: float = 12.0
@export var spiral_radius: float = 200.0
@export var forward_speed: float = 150.0

var threat_source: Node3D
var pattern_start_time: float = 0.0
var pattern_progress: float = 0.0
var spiral_direction: int = 1  # 1 for clockwise, -1 for counter-clockwise
var pattern_frequency: float = 2.0
var evasion_effectiveness: float = 0.0

var base_position: Vector3
var corkscrew_axis: Vector3
var perpendicular_axis_1: Vector3
var perpendicular_axis_2: Vector3

signal corkscrew_started(pattern: CorkscrewPattern, duration: float)
signal corkscrew_completed(effectiveness: float)
signal pattern_adjusted(new_pattern: CorkscrewPattern, reason: String)

func _setup() -> void:
	super._setup()
	pattern_start_time = 0.0
	pattern_progress = 0.0
	spiral_direction = 1 if randf() > 0.5 else -1
	
	# Find primary threat source
	if ai_agent and ai_agent.has_method("get_primary_threat"):
		threat_source = ai_agent.get_primary_threat()
	elif ai_agent and ai_agent.has_method("get_current_target"):
		threat_source = ai_agent.get_current_target()
	
	if auto_pattern_selection and threat_source:
		corkscrew_pattern = _select_optimal_pattern()
	
	_initialize_corkscrew_axes()

func execute_wcs_action(delta: float) -> int:
	if pattern_start_time <= 0.0:
		_start_corkscrew_pattern()
	
	var elapsed_time: float = Time.get_time_from_start() - pattern_start_time
	pattern_progress = elapsed_time / duration
	
	if pattern_progress >= 1.0:
		return _complete_corkscrew()
	
	# Execute corkscrew maneuver
	_execute_corkscrew_movement(delta)
	
	# Adjust pattern if needed
	_check_pattern_adjustment()
	
	# Update effectiveness rating
	_update_evasion_effectiveness()
	
	return 2  # RUNNING

func _select_optimal_pattern() -> CorkscrewPattern:
	"""Select optimal corkscrew pattern based on threat and situation"""
	if not threat_source:
		return CorkscrewPattern.STANDARD
	
	var threat_distance: float = distance_to_node(threat_source)
	var ship_damage: float = 0.0
	
	if ai_agent and ai_agent.has_method("get_damage_level"):
		ship_damage = ai_agent.get_damage_level()
	
	# Close-range threats require tight maneuvers
	if threat_distance < 400.0:
		return CorkscrewPattern.TIGHT_SPIRAL
	
	# Long-range threats allow wider patterns
	if threat_distance > 1200.0:
		return CorkscrewPattern.WIDE_HELIX
	
	# Damaged ships use less aggressive patterns
	if ship_damage > 0.5:
		return CorkscrewPattern.COMBAT_ROLL
	
	# High threat situations require unpredictable patterns
	if _assess_threat_level() > 7.0:
		return CorkscrewPattern.IRREGULAR
	
	return CorkscrewPattern.STANDARD

func _initialize_corkscrew_axes() -> void:
	"""Initialize the coordinate system for corkscrew maneuver"""
	base_position = get_ship_position()
	
	if threat_source:
		# Orient corkscrew axis away from threat
		var threat_direction: Vector3 = (threat_source.global_position - base_position).normalized()
		corkscrew_axis = -threat_direction
	else:
		# Default forward direction
		corkscrew_axis = get_ship_forward_vector()
	
	# Create perpendicular axes for spiral motion
	perpendicular_axis_1 = corkscrew_axis.cross(Vector3.UP).normalized()
	if perpendicular_axis_1.length() < 0.1:
		perpendicular_axis_1 = corkscrew_axis.cross(Vector3.RIGHT).normalized()
	
	perpendicular_axis_2 = corkscrew_axis.cross(perpendicular_axis_1).normalized()
	
	# Adjust parameters based on pattern type
	_configure_pattern_parameters()

func _configure_pattern_parameters() -> void:
	"""Configure parameters based on selected pattern"""
	match corkscrew_pattern:
		CorkscrewPattern.STANDARD:
			spiral_radius = 200.0
			pattern_frequency = 2.0
			forward_speed = 150.0
			duration = 12.0
		
		CorkscrewPattern.TIGHT_SPIRAL:
			spiral_radius = 120.0
			pattern_frequency = 3.5
			forward_speed = 100.0
			duration = 8.0
		
		CorkscrewPattern.WIDE_HELIX:
			spiral_radius = 350.0
			pattern_frequency = 1.2
			forward_speed = 200.0
			duration = 15.0
		
		CorkscrewPattern.IRREGULAR:
			spiral_radius = 180.0 + randf_range(-50.0, 80.0)
			pattern_frequency = 1.8 + randf_range(-0.5, 1.2)
			forward_speed = 130.0 + randf_range(-30.0, 40.0)
			duration = 10.0 + randf_range(-2.0, 4.0)
		
		CorkscrewPattern.COMBAT_ROLL:
			spiral_radius = 160.0
			pattern_frequency = 2.5
			forward_speed = 120.0
			duration = 10.0

func _start_corkscrew_pattern() -> void:
	"""Initialize corkscrew pattern execution"""
	pattern_start_time = Time.get_time_from_start()
	
	corkscrew_started.emit(corkscrew_pattern, duration)

func _execute_corkscrew_movement(delta: float) -> void:
	"""Execute the corkscrew movement pattern"""
	if not ship_controller:
		return
	
	var ship_pos: Vector3 = get_ship_position()
	
	# Calculate spiral motion
	var spiral_time: float = pattern_progress * pattern_frequency * 2.0 * PI * spiral_direction
	var current_radius: float = _get_current_radius()
	
	# Apply pattern-specific modifications
	var radius_x: float = current_radius
	var radius_y: float = current_radius
	
	match corkscrew_pattern:
		CorkscrewPattern.TIGHT_SPIRAL:
			# Gradually tightening spiral
			radius_x *= (1.0 - pattern_progress * 0.3)
			radius_y *= (1.0 - pattern_progress * 0.3)
		
		CorkscrewPattern.WIDE_HELIX:
			# Elliptical helix
			radius_x *= 1.2
			radius_y *= 0.8
		
		CorkscrewPattern.IRREGULAR:
			# Irregular variations
			var noise_factor: float = sin(pattern_progress * 7.0 * PI) * 0.3
			radius_x *= (1.0 + noise_factor)
			radius_y *= (1.0 - noise_factor * 0.5)
		
		CorkscrewPattern.COMBAT_ROLL:
			# More aggressive rolling motion
			spiral_time *= 1.5
			radius_y *= 0.6
	
	# Calculate spiral position
	var spiral_offset: Vector3 = perpendicular_axis_1 * cos(spiral_time) * radius_x
	spiral_offset += perpendicular_axis_2 * sin(spiral_time) * radius_y
	
	# Add forward movement
	var forward_progress: Vector3 = corkscrew_axis * forward_speed * pattern_progress * (duration / 10.0)
	
	# Apply skill-based variations
	var skill_level: float = 0.7
	if ai_agent and ai_agent.has_method("get_skill_level"):
		skill_level = ai_agent.get_skill_level()
	
	# High-skill pilots can execute tighter, more precise patterns
	var precision_factor: float = lerp(0.8, 1.1, skill_level)
	spiral_offset *= precision_factor
	
	# Low-skill pilots may have some wobble in their patterns
	if skill_level < 0.5:
		var wobble: Vector3 = Vector3(
			sin(pattern_progress * 13.0 * PI) * 20.0,
			cos(pattern_progress * 17.0 * PI) * 15.0,
			sin(pattern_progress * 11.0 * PI) * 18.0
		) * (0.5 - skill_level)
		spiral_offset += wobble
	
	# Calculate target position
	var target_position: Vector3 = base_position + forward_progress + spiral_offset
	set_ship_target_position(target_position)
	
	# Adjust throttle based on pattern intensity
	var throttle: float = _calculate_pattern_throttle()
	_set_ship_throttle(throttle)

func _get_current_radius() -> float:
	"""Get current spiral radius with pattern-specific modifications"""
	var base_radius: float = spiral_radius
	
	match corkscrew_pattern:
		CorkscrewPattern.TIGHT_SPIRAL:
			# Gradually decrease radius
			return base_radius * (1.0 - pattern_progress * 0.4)
		
		CorkscrewPattern.WIDE_HELIX:
			# Slightly increase radius over time
			return base_radius * (1.0 + pattern_progress * 0.2)
		
		CorkscrewPattern.IRREGULAR:
			# Random radius variations
			var variation: float = sin(pattern_progress * 5.0 * PI) * 0.3
			return base_radius * (1.0 + variation)
		
		_:
			return base_radius

func _calculate_pattern_throttle() -> float:
	"""Calculate appropriate throttle for pattern intensity"""
	var base_throttle: float = 1.0
	
	match corkscrew_pattern:
		CorkscrewPattern.TIGHT_SPIRAL:
			base_throttle = 0.8  # Reduce speed for tight maneuvers
		
		CorkscrewPattern.WIDE_HELIX:
			base_throttle = 1.2  # Increase speed for wide patterns
		
		CorkscrewPattern.IRREGULAR:
			# Variable throttle for unpredictability
			var throttle_variation: float = sin(pattern_progress * 6.0 * PI) * 0.2
			base_throttle = 1.0 + throttle_variation
		
		CorkscrewPattern.COMBAT_ROLL:
			base_throttle = 0.9  # Moderate speed for control
		
		_:
			base_throttle = 1.0
	
	return clamp(base_throttle, 0.6, 1.4)

func _check_pattern_adjustment() -> void:
	"""Check if pattern should be adjusted based on effectiveness"""
	# Only adjust pattern once during execution
	if pattern_progress < 0.3 or pattern_progress > 0.7:
		return
	
	var current_effectiveness: float = _calculate_current_effectiveness()
	
	if current_effectiveness < 0.3:
		# Pattern is not effective, try to switch
		var new_pattern: CorkscrewPattern = _select_emergency_pattern()
		if new_pattern != corkscrew_pattern:
			_switch_pattern(new_pattern, "Low effectiveness detected")

func _select_emergency_pattern() -> CorkscrewPattern:
	"""Select emergency pattern when current pattern is ineffective"""
	match corkscrew_pattern:
		CorkscrewPattern.STANDARD:
			return CorkscrewPattern.IRREGULAR
		CorkscrewPattern.WIDE_HELIX:
			return CorkscrewPattern.TIGHT_SPIRAL
		CorkscrewPattern.TIGHT_SPIRAL:
			return CorkscrewPattern.COMBAT_ROLL
		_:
			return CorkscrewPattern.IRREGULAR

func _switch_pattern(new_pattern: CorkscrewPattern, reason: String) -> void:
	"""Switch to a different corkscrew pattern mid-execution"""
	corkscrew_pattern = new_pattern
	_configure_pattern_parameters()
	pattern_adjusted.emit(new_pattern, reason)

func _calculate_current_effectiveness() -> float:
	"""Calculate current evasion effectiveness"""
	var effectiveness: float = 0.5  # Base effectiveness
	
	# Check if we're still taking damage
	if ai_agent and ai_agent.has_method("get_recent_damage"):
		var recent_damage: float = ai_agent.get_recent_damage()
		if recent_damage < 10.0:
			effectiveness += 0.3  # Not taking much damage = effective
		else:
			effectiveness -= 0.2  # Still taking damage = less effective
	
	# Check if threat is still targeting us effectively
	if threat_source and threat_source.has_method("get_target_lock_strength"):
		var lock_strength: float = threat_source.get_target_lock_strength()
		effectiveness += (1.0 - lock_strength) * 0.3
	
	# Pattern-specific effectiveness factors
	match corkscrew_pattern:
		CorkscrewPattern.IRREGULAR:
			effectiveness += 0.1  # Irregular patterns are generally more effective
		CorkscrewPattern.TIGHT_SPIRAL:
			if distance_to_node(threat_source) < 500.0:
				effectiveness += 0.2  # Tight spirals good for close range
			else:
				effectiveness -= 0.1  # Less effective at long range
	
	return clamp(effectiveness, 0.0, 1.0)

func _update_evasion_effectiveness() -> void:
	"""Update overall evasion effectiveness rating"""
	var current_effectiveness: float = _calculate_current_effectiveness()
	
	# Running average of effectiveness
	evasion_effectiveness = lerp(evasion_effectiveness, current_effectiveness, 0.1)

func _assess_threat_level() -> float:
	"""Assess current threat level (0.0 to 10.0)"""
	if not threat_source:
		return 3.0
	
	var base_threat: float = 5.0
	var distance: float = distance_to_node(threat_source)
	
	# Closer threats are more dangerous
	var distance_factor: float = clamp(1000.0 / distance, 0.5, 2.0)
	
	# Check if threat has lock on us
	if threat_source.has_method("has_target_lock") and threat_source.has_target_lock():
		base_threat += 2.0
	
	# Check for multiple threats
	if ai_agent and ai_agent.has_method("get_threat_count"):
		var threat_count: int = ai_agent.get_threat_count()
		base_threat += threat_count * 0.5
	
	return clamp(base_threat * distance_factor, 1.0, 10.0)

func _complete_corkscrew() -> int:
	"""Complete corkscrew evasion maneuver"""
	corkscrew_completed.emit(evasion_effectiveness)
	
	# Return success if evasion was reasonably effective
	return 1 if evasion_effectiveness > 0.4 else 0

func get_pattern_info() -> Dictionary:
	"""Get information about current corkscrew pattern"""
	return {
		"pattern": CorkscrewPattern.keys()[corkscrew_pattern],
		"progress": pattern_progress,
		"effectiveness": evasion_effectiveness,
		"spiral_radius": spiral_radius,
		"forward_speed": forward_speed,
		"duration": duration,
		"threat_distance": distance_to_node(threat_source) if threat_source else 0.0
	}