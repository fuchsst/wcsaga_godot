class_name RadarZoomController
extends RefCounted

## HUD-009 Component 4: Radar Zoom Controller
## Handles multiple zoom levels with smooth transitions for tactical and strategic views
## Provides dynamic range adjustment and scale management for 3D radar display

signal zoom_changed(new_zoom: int)
signal range_changed(new_range: float)
signal zoom_mode_changed(mode: String)

# Zoom configuration
var zoom_levels: Array[float] = []
var current_zoom_level: int = 2
var max_zoom_levels: int = 5
var min_zoom_level: int = 1

# Zoom transition settings
var zoom_transition_duration: float = 0.3
var smooth_transitions: bool = true
var auto_zoom_enabled: bool = false

# Range management
var current_range: float = 10000.0
var range_multipliers: Array[float] = [0.2, 0.5, 1.0, 2.5, 5.0]  # Multipliers for base range
var base_range: float = 10000.0

# Zoom modes
var zoom_modes: Dictionary = {
	"manual": {"auto_adjust": false, "user_control": true},
	"auto_tactical": {"auto_adjust": true, "focus": "close_range"},
	"auto_strategic": {"auto_adjust": true, "focus": "long_range"},
	"auto_adaptive": {"auto_adjust": true, "focus": "situational"}
}
var current_zoom_mode: String = "manual"

# Auto-zoom configuration
var auto_zoom_thresholds: Dictionary = {
	"close_contact_distance": 2000.0,
	"medium_contact_distance": 5000.0,
	"high_density_threshold": 5,
	"low_density_threshold": 2
}

# Transition state
var is_transitioning: bool = false
var transition_start_time: float = 0.0
var transition_start_range: float = 0.0
var transition_target_range: float = 0.0

# Performance monitoring
var last_zoom_change_time: float = 0.0
var zoom_change_frequency: float = 0.0
var performance_limited: bool = false

func _init():
	_initialize_zoom_controller()

func _initialize_zoom_controller() -> void:
	print("RadarZoomController: Initializing zoom control system...")
	
	# Set default zoom levels if not provided
	if zoom_levels.is_empty():
		zoom_levels = [2000.0, 5000.0, 10000.0, 25000.0, 50000.0]
	
	# Ensure we have the right number of zoom levels
	max_zoom_levels = zoom_levels.size()
	
	# Validate current zoom level
	current_zoom_level = clamp(current_zoom_level, min_zoom_level, max_zoom_levels)
	
	# Set initial range
	current_range = zoom_levels[current_zoom_level - 1]
	
	print("RadarZoomController: Zoom control system initialized with %d levels" % max_zoom_levels)

## Setup zoom system with custom levels
func setup_zoom_system(levels: Array[float], initial_zoom: int) -> void:
	zoom_levels = levels.duplicate()
	max_zoom_levels = zoom_levels.size()
	current_zoom_level = clamp(initial_zoom, min_zoom_level, max_zoom_levels)
	current_range = zoom_levels[current_zoom_level - 1]
	
	# Update range multipliers to match zoom levels
	_update_range_multipliers()

## Set zoom level
func set_zoom_level(new_zoom: int) -> void:
	var target_zoom = clamp(new_zoom, min_zoom_level, max_zoom_levels)
	
	if target_zoom == current_zoom_level:
		return
	
	var old_zoom = current_zoom_level
	current_zoom_level = target_zoom
	var target_range = zoom_levels[current_zoom_level - 1]
	
	# Record zoom change for performance monitoring
	var current_time = Time.get_ticks_usec() / 1000000.0
	zoom_change_frequency = 1.0 / max(current_time - last_zoom_change_time, 0.1)
	last_zoom_change_time = current_time
	
	if smooth_transitions and not performance_limited:
		_start_range_transition(current_range, target_range)
	else:
		current_range = target_range
		range_changed.emit(current_range)
	
	zoom_changed.emit(current_zoom_level)
	print("RadarZoomController: Zoom level changed from %d to %d (range: %.0fm)" % [old_zoom, current_zoom_level, current_range])

## Zoom in (decrease zoom level number = closer view)
func zoom_in() -> void:
	if current_zoom_level > min_zoom_level:
		set_zoom_level(current_zoom_level - 1)

## Zoom out (increase zoom level number = farther view)
func zoom_out() -> void:
	if current_zoom_level < max_zoom_levels:
		set_zoom_level(current_zoom_level + 1)

## Set zoom mode
func set_zoom_mode(mode: String) -> void:
	if mode in zoom_modes:
		var old_mode = current_zoom_mode
		current_zoom_mode = mode
		auto_zoom_enabled = zoom_modes[mode].auto_adjust
		zoom_mode_changed.emit(current_zoom_mode)
		print("RadarZoomController: Zoom mode changed from '%s' to '%s'" % [old_mode, current_zoom_mode])

## Update auto-zoom based on tactical situation
func update_auto_zoom(contact_data: Dictionary) -> void:
	if not auto_zoom_enabled:
		return
	
	var contacts = contact_data.get("contacts", [])
	var player_position = contact_data.get("player_position", Vector3.ZERO)
	
	var suggested_zoom = _calculate_optimal_zoom(contacts, player_position)
	
	if suggested_zoom != current_zoom_level:
		# Only auto-zoom if not transitioning and enough time has passed
		var current_time = Time.get_ticks_usec() / 1000000.0
		if not is_transitioning and (current_time - last_zoom_change_time) > 2.0:
			set_zoom_level(suggested_zoom)

## Calculate optimal zoom level based on tactical situation
func _calculate_optimal_zoom(contacts: Array, player_position: Vector3) -> int:
	if contacts.is_empty():
		return 3  # Default medium zoom
	
	# Analyze contact distribution
	var close_contacts = 0
	var medium_contacts = 0
	var far_contacts = 0
	var total_contacts = contacts.size()
	
	for contact in contacts:
		var distance = 0.0
		if contact is Dictionary and contact.has("distance"):
			distance = contact.distance
		elif contact is Node and contact.has_method("global_position"):
			distance = player_position.distance_to(contact.global_position)
		
		if distance < auto_zoom_thresholds.close_contact_distance:
			close_contacts += 1
		elif distance < auto_zoom_thresholds.medium_contact_distance:
			medium_contacts += 1
		else:
			far_contacts += 1
	
	# Determine optimal zoom based on contact distribution and mode
	match current_zoom_mode:
		"auto_tactical":
			# Focus on close and medium range contacts
			if close_contacts >= auto_zoom_thresholds.high_density_threshold:
				return 1  # Closest zoom for close combat
			elif close_contacts + medium_contacts >= auto_zoom_thresholds.high_density_threshold:
				return 2  # Close-medium zoom
			else:
				return 3  # Medium zoom
		
		"auto_strategic":
			# Focus on overall battlefield awareness
			if total_contacts >= 10:
				return 5  # Widest zoom for strategic overview
			elif total_contacts >= 5:
				return 4  # Wide zoom
			else:
				return 3  # Medium zoom
		
		"auto_adaptive":
			# Adaptive based on engagement type
			var close_ratio = float(close_contacts) / total_contacts
			var medium_ratio = float(medium_contacts) / total_contacts
			
			if close_ratio > 0.6:
				return 1  # Close combat focus
			elif close_ratio + medium_ratio > 0.7:
				return 2  # Tactical focus
			elif far_contacts > total_contacts * 0.5:
				return 4  # Strategic focus
			else:
				return 3  # Balanced view
	
	return current_zoom_level  # No change

## Start smooth range transition
func _start_range_transition(start_range: float, target_range: float) -> void:
	is_transitioning = true
	transition_start_time = Time.get_ticks_usec() / 1000000.0
	transition_start_range = start_range
	transition_target_range = target_range

## Update transition (called by parent system)
func update_transition(delta: float) -> void:
	if not is_transitioning:
		return
	
	var current_time = Time.get_ticks_usec() / 1000000.0
	var elapsed_time = current_time - transition_start_time
	var progress = elapsed_time / zoom_transition_duration
	
	if progress >= 1.0:
		# Transition complete
		current_range = transition_target_range
		is_transitioning = false
		range_changed.emit(current_range)
	else:
		# Smooth interpolation using easing
		var eased_progress = _ease_in_out(progress)
		current_range = lerp(transition_start_range, transition_target_range, eased_progress)
		range_changed.emit(current_range)

## Easing function for smooth transitions
func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

## Set custom range (manual override)
func set_custom_range(range: float) -> void:
	var clamped_range = clamp(range, 500.0, 100000.0)
	
	if smooth_transitions and not performance_limited:
		_start_range_transition(current_range, clamped_range)
	else:
		current_range = clamped_range
		range_changed.emit(current_range)
	
	# Update zoom level to match custom range
	_update_zoom_level_for_range(clamped_range)

## Update zoom level to match a custom range
func _update_zoom_level_for_range(range: float) -> void:
	var best_zoom = current_zoom_level
	var best_difference = abs(zoom_levels[current_zoom_level - 1] - range)
	
	for i in range(zoom_levels.size()):
		var difference = abs(zoom_levels[i] - range)
		if difference < best_difference:
			best_difference = difference
			best_zoom = i + 1
	
	if best_zoom != current_zoom_level:
		current_zoom_level = best_zoom
		zoom_changed.emit(current_zoom_level)

## Get current zoom information
func get_zoom_info() -> Dictionary:
	return {
		"current_level": current_zoom_level,
		"max_levels": max_zoom_levels,
		"current_range": current_range,
		"zoom_mode": current_zoom_mode,
		"is_transitioning": is_transitioning,
		"auto_zoom_enabled": auto_zoom_enabled,
		"smooth_transitions": smooth_transitions
	}

## Set zoom levels array
func set_zoom_levels(levels: Array[float]) -> void:
	zoom_levels = levels.duplicate()
	max_zoom_levels = zoom_levels.size()
	
	# Ensure current zoom level is valid
	current_zoom_level = clamp(current_zoom_level, min_zoom_level, max_zoom_levels)
	current_range = zoom_levels[current_zoom_level - 1]
	
	_update_range_multipliers()

## Get available zoom levels
func get_zoom_levels() -> Array[float]:
	return zoom_levels.duplicate()

## Set transition settings
func set_transition_settings(duration: float, smooth: bool) -> void:
	zoom_transition_duration = clamp(duration, 0.1, 2.0)
	smooth_transitions = smooth

## Set auto-zoom thresholds
func set_auto_zoom_thresholds(thresholds: Dictionary) -> void:
	for key in thresholds.keys():
		if key in auto_zoom_thresholds:
			auto_zoom_thresholds[key] = thresholds[key]

## Enable/disable performance limiting
func set_performance_limiting(enabled: bool) -> void:
	performance_limited = enabled
	if enabled:
		smooth_transitions = false

## Calculate range for zoom level
func get_range_for_zoom_level(zoom_level: int) -> float:
	var clamped_zoom = clamp(zoom_level, min_zoom_level, max_zoom_levels)
	return zoom_levels[clamped_zoom - 1]

## Get zoom level for range
func get_zoom_level_for_range(range: float) -> int:
	var best_zoom = 1
	var best_difference = abs(zoom_levels[0] - range)
	
	for i in range(zoom_levels.size()):
		var difference = abs(zoom_levels[i] - range)
		if difference < best_difference:
			best_difference = difference
			best_zoom = i + 1
	
	return best_zoom

## Update range multipliers based on zoom levels
func _update_range_multipliers() -> void:
	if zoom_levels.is_empty():
		return
	
	range_multipliers.clear()
	base_range = zoom_levels[2] if zoom_levels.size() >= 3 else zoom_levels[0]  # Use middle zoom as base
	
	for level_range in zoom_levels:
		range_multipliers.append(level_range / base_range)

## Get next zoom level in direction
func get_next_zoom_level(direction: int) -> int:
	var next_zoom = current_zoom_level + direction
	return clamp(next_zoom, min_zoom_level, max_zoom_levels)

## Check if zoom level is valid
func is_valid_zoom_level(zoom_level: int) -> bool:
	return zoom_level >= min_zoom_level and zoom_level <= max_zoom_levels

## Reset to default zoom
func reset_to_default_zoom() -> void:
	var default_zoom = 3 if max_zoom_levels >= 3 else (max_zoom_levels + 1) / 2
	set_zoom_level(default_zoom)

## Get zoom level name/description
func get_zoom_level_name(zoom_level: int) -> String:
	if not is_valid_zoom_level(zoom_level):
		return "Invalid"
	
	match zoom_level:
		1:
			return "Close Combat"
		2:
			return "Tactical"
		3:
			return "Standard"
		4:
			return "Strategic"
		5:
			return "Long Range"
		_:
			return "Level %d" % zoom_level

## Get performance metrics
func get_performance_metrics() -> Dictionary:
	return {
		"zoom_change_frequency": zoom_change_frequency,
		"last_change_time": last_zoom_change_time,
		"is_transitioning": is_transitioning,
		"performance_limited": performance_limited,
		"transition_duration": zoom_transition_duration
	}

## Advanced zoom features

## Set zoom based on contact density
func set_zoom_for_density(contact_count: int, area_size: float) -> void:
	var density = contact_count / max(area_size, 1.0)
	
	var optimal_zoom: int
	if density > 0.1:
		optimal_zoom = 1  # High density - zoom in
	elif density > 0.05:
		optimal_zoom = 2  # Medium density
	elif density > 0.01:
		optimal_zoom = 3  # Low density
	else:
		optimal_zoom = 4  # Very low density - zoom out
	
	set_zoom_level(optimal_zoom)

## Zoom to fit all contacts
func zoom_to_fit_contacts(contacts: Array, player_position: Vector3, margin: float = 1.2) -> void:
	if contacts.is_empty():
		return
	
	var max_distance = 0.0
	
	for contact in contacts:
		var distance = 0.0
		if contact is Dictionary and contact.has("distance"):
			distance = contact.distance
		elif contact is Node and contact.has_method("global_position"):
			distance = player_position.distance_to(contact.global_position)
		
		max_distance = max(max_distance, distance)
	
	# Add margin and find best zoom level
	var target_range = max_distance * margin
	var optimal_zoom = get_zoom_level_for_range(target_range)
	set_zoom_level(optimal_zoom)

## Zoom to specific target
func zoom_to_target(target_distance: float, zoom_factor: float = 1.5) -> void:
	var target_range = target_distance * zoom_factor
	var optimal_zoom = get_zoom_level_for_range(target_range)
	set_zoom_level(optimal_zoom)
