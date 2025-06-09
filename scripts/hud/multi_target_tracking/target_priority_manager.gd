class_name TargetPriorityManager
extends Node

## HUD-008 Component 2: Target Priority Assessment and Ranking System
## Intelligent target priority calculation based on threat, distance, tactical importance, and dynamic combat factors
## Provides real-time priority updates and automatic priority management for multi-target scenarios

signal priority_changed(track_id: int, old_priority: int, new_priority: int)
signal priority_recalculated(priority_data: Array[Dictionary])
signal high_priority_target_detected(track_id: int, priority: int)
signal priority_conflict_resolved(conflicting_tracks: Array[int], resolution: String)

# Priority calculation parameters
@export var max_targets: int = 32
@export var auto_management_enabled: bool = true
@export var priority_update_frequency: float = 10.0  # 10Hz for priority updates
@export var priority_decay_rate: float = 0.02  # Priority decay per second for stale targets

# Priority weighting factors
var priority_weights: Dictionary = {
	"distance": 0.25,           # Closer targets = higher priority
	"threat_level": 0.35,       # More dangerous = higher priority
	"target_type": 0.15,        # Strategic importance
	"velocity": 0.10,           # Fast targets = higher priority
	"heading": 0.05,            # Targets heading toward player
	"vulnerability": 0.10       # Exposed/damaged targets
}

# Priority configuration
var priority_config: Dictionary = {
	"min_priority": 1,
	"max_priority": 100,
	"default_priority": 50,
	"critical_threshold": 85,    # Above this = critical priority
	"high_threshold": 70,        # Above this = high priority
	"low_threshold": 30,         # Below this = low priority
	"distance_max": 50000.0,     # Maximum distance for priority calculation
	"velocity_max": 1000.0,      # Maximum velocity for normalization
	"threat_response_multiplier": 2.0,  # Multiplier for immediate threats
	"engagement_bonus": 15,      # Bonus for currently engaged targets
	"formation_penalty": -10     # Penalty for targets in formation (harder to hit)
}

# Target type priority values
var target_type_priorities: Dictionary = {
	"missile": 95,               # Incoming ordnance - highest priority
	"torpedo": 90,
	"bomb": 85,
	"fighter": 60,
	"bomber": 75,
	"interceptor": 55,
	"assault": 65,
	"corvette": 50,
	"frigate": 45,
	"destroyer": 40,
	"cruiser": 35,
	"capital": 30,
	"carrier": 25,
	"transport": 20,
	"cargo": 15,
	"debris": 5,
	"unknown": 25               # Moderate priority for unknowns
}

# Special priority modifiers
var priority_modifiers: Dictionary = {
	"ace_pilot": 20,            # Bonus for ace pilots
	"elite_unit": 15,           # Bonus for elite units
	"commander": 25,            # Bonus for command vessels
	"stealth": -10,             # Penalty for stealth units (harder to track)
	"jammed": -15,              # Penalty for jammed targets
	"friendly_fire_risk": -20,  # Penalty if friendly fire risk
	"low_ammunition": 10,       # Bonus if target is low on ammo
	"damaged": 15,              # Bonus for damaged targets
	"shields_down": 20,         # Bonus for targets with shields down
	"engines_disabled": 25      # Bonus for immobilized targets
}

# Priority management state
var current_priorities: Dictionary = {}  # track_id -> priority
var priority_history: Dictionary = {}   # track_id -> Array[priority_snapshots]
var last_priority_update: float = 0.0
var priority_update_timer: Timer
var auto_management_timer: Timer

# Performance tracking
var calculation_time_ms: float = 0.0
var priorities_calculated_per_second: int = 0
var priority_changes_per_second: int = 0

func _ready() -> void:
	_initialize_priority_manager()

func _initialize_priority_manager() -> void:
	print("TargetPriorityManager: Initializing target priority management system...")
	
	# Setup update timers
	priority_update_timer = Timer.new()
	priority_update_timer.wait_time = 1.0 / priority_update_frequency
	priority_update_timer.timeout.connect(_on_priority_update_timer)
	priority_update_timer.autostart = true
	add_child(priority_update_timer)
	
	auto_management_timer = Timer.new()
	auto_management_timer.wait_time = 2.0  # Auto management every 2 seconds
	auto_management_timer.timeout.connect(_on_auto_management_timer)
	auto_management_timer.autostart = auto_management_enabled
	add_child(auto_management_timer)
	
	print("TargetPriorityManager: Priority management system initialized")

## Set maximum number of targets to manage
func set_max_targets(max: int) -> void:
	max_targets = max

## Enable or disable automatic priority management
func enable_auto_management(enabled: bool) -> void:
	auto_management_enabled = enabled
	if auto_management_timer:
		auto_management_timer.autostart = enabled
		if enabled:
			auto_management_timer.start()
		else:
			auto_management_timer.stop()

## Update priorities for all provided targets
func update_priorities(track_data_array: Array[Dictionary]) -> void:
	var start_time = Time.get_ticks_usec()
	var priority_updates: Array[Dictionary] = []
	
	for track_data in track_data_array:
		var track_id = track_data.track_id
		var old_priority = current_priorities.get(track_id, priority_config.default_priority)
		var new_priority = calculate_target_priority(track_data)
		
		# Update priority if changed significantly
		if abs(new_priority - old_priority) >= 2:  # Minimum change threshold
			current_priorities[track_id] = new_priority
			_record_priority_change(track_id, old_priority, new_priority)
			
			priority_updates.append({
				"track_id": track_id,
				"old_priority": old_priority,
				"new_priority": new_priority,
				"priority": new_priority
			})
			
			# Emit individual priority change signal
			priority_changed.emit(track_id, old_priority, new_priority)
			
			# Check for high priority targets
			if new_priority >= priority_config.critical_threshold:
				high_priority_target_detected.emit(track_id, new_priority)
	
	# Emit batch priority update
	if not priority_updates.is_empty():
		priority_recalculated.emit(priority_updates)
	
	# Performance tracking
	var calculation_time = (Time.get_ticks_usec() - start_time) / 1000.0
	calculation_time_ms = calculation_time
	priorities_calculated_per_second = track_data_array.size()
	priority_changes_per_second = priority_updates.size()

## Calculate priority for a single target
func calculate_target_priority(track_data: Dictionary) -> int:
	var base_priority = priority_config.default_priority
	var priority_score = 0.0
	
	# Extract track data
	var track_id = track_data.get("track_id", -1)
	var distance = track_data.get("distance", 10000.0)
	var threat_level = track_data.get("threat_level", 0.0)
	var target_type = track_data.get("target_type", "unknown")
	var relationship = track_data.get("relationship", "unknown")
	var velocity = track_data.get("velocity", Vector3.ZERO).length() if track_data.get("velocity") is Vector3 else track_data.get("velocity", 0.0)
	var position = track_data.get("position", Vector3.ZERO)
	var heading = track_data.get("heading", 0.0)
	
	# Skip friendly targets unless specifically requested
	if relationship == "friendly":
		return priority_config.min_priority
	
	# Distance factor (closer = higher priority)
	var distance_factor = 1.0 - clamp(distance / priority_config.distance_max, 0.0, 1.0)
	priority_score += distance_factor * priority_weights.distance
	
	# Threat level factor
	priority_score += threat_level * priority_weights.threat_level
	
	# Target type factor
	var type_priority = target_type_priorities.get(target_type, target_type_priorities.unknown)
	var type_factor = type_priority / 100.0
	priority_score += type_factor * priority_weights.target_type
	
	# Velocity factor (fast targets need attention)
	var velocity_factor = clamp(velocity / priority_config.velocity_max, 0.0, 1.0)
	priority_score += velocity_factor * priority_weights.velocity
	
	# Heading factor (targets coming toward player)
	var heading_factor = _calculate_heading_threat_factor(position, heading)
	priority_score += heading_factor * priority_weights.heading
	
	# Vulnerability factor
	var vulnerability_factor = _calculate_vulnerability_factor(track_data)
	priority_score += vulnerability_factor * priority_weights.vulnerability
	
	# Apply special modifiers
	priority_score += _calculate_special_modifiers(track_data)
	
	# Convert to integer priority
	var final_priority = base_priority + int(priority_score * 50)  # Scale factor
	
	# Apply range limits
	final_priority = clamp(final_priority, priority_config.min_priority, priority_config.max_priority)
	
	return final_priority

func _calculate_heading_threat_factor(target_position: Vector3, target_heading: float) -> float:
	var player_position = _get_player_position()
	var to_player = (player_position - target_position).normalized()
	var target_direction = Vector3(sin(target_heading), 0, cos(target_heading))
	
	# Calculate how much the target is heading toward the player
	var dot_product = target_direction.dot(to_player)
	return max(0.0, dot_product)  # 0 to 1, where 1 means heading directly at player

func _calculate_vulnerability_factor(track_data: Dictionary) -> float:
	var vulnerability = 0.0
	
	# Check for damage indicators
	if track_data.has("hull_percentage"):
		var hull = track_data.hull_percentage
		if hull < 0.5:  # Less than 50% hull
			vulnerability += 0.3
		if hull < 0.25:  # Critical damage
			vulnerability += 0.3
	
	# Check for shield status
	if track_data.has("shield_percentage"):
		var shields = track_data.shield_percentage
		if shields < 0.1:  # Shields down
			vulnerability += 0.4
	
	# Check for disabled subsystems
	if track_data.has("disabled_subsystems"):
		var disabled = track_data.disabled_subsystems
		if disabled.has("engines"):
			vulnerability += 0.3
		if disabled.has("weapons"):
			vulnerability += 0.2
	
	return clamp(vulnerability, 0.0, 1.0)

func _calculate_special_modifiers(track_data: Dictionary) -> float:
	var modifier_total = 0.0
	
	# Check for special flags or properties
	if track_data.has("is_ace_pilot") and track_data.is_ace_pilot:
		modifier_total += priority_modifiers.ace_pilot / 100.0
	
	if track_data.has("is_elite") and track_data.is_elite:
		modifier_total += priority_modifiers.elite_unit / 100.0
	
	if track_data.has("is_commander") and track_data.is_commander:
		modifier_total += priority_modifiers.commander / 100.0
	
	if track_data.has("is_stealth") and track_data.is_stealth:
		modifier_total += priority_modifiers.stealth / 100.0
	
	if track_data.has("is_jammed") and track_data.is_jammed:
		modifier_total += priority_modifiers.jammed / 100.0
	
	if track_data.has("friendly_fire_risk") and track_data.friendly_fire_risk:
		modifier_total += priority_modifiers.friendly_fire_risk / 100.0
	
	# Dynamic modifiers based on engagement state
	if track_data.has("is_engaged") and track_data.is_engaged:
		modifier_total += priority_modifiers.get("engagement_bonus", 15) / 100.0
	
	if track_data.has("in_formation") and track_data.in_formation:
		modifier_total += priority_modifiers.get("formation_penalty", -10) / 100.0
	
	return modifier_total

## Get current priority for a target
func get_target_priority(track_id: int) -> int:
	return current_priorities.get(track_id, priority_config.default_priority)

## Set priority for a target manually
func set_target_priority(track_id: int, priority: int) -> void:
	var old_priority = current_priorities.get(track_id, priority_config.default_priority)
	var new_priority = clamp(priority, priority_config.min_priority, priority_config.max_priority)
	
	if old_priority != new_priority:
		current_priorities[track_id] = new_priority
		_record_priority_change(track_id, old_priority, new_priority)
		priority_changed.emit(track_id, old_priority, new_priority)

## Get targets sorted by priority
func get_targets_by_priority(count: int = -1) -> Array[Dictionary]:
	var priority_list: Array[Dictionary] = []
	
	for track_id in current_priorities.keys():
		priority_list.append({
			"track_id": track_id,
			"priority": current_priorities[track_id]
		})
	
	# Sort by priority (highest first)
	priority_list.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Return requested count
	if count > 0:
		return priority_list.slice(0, min(count, priority_list.size()))
	else:
		return priority_list

## Get high priority targets
func get_high_priority_targets() -> Array[int]:
	var high_priority_tracks: Array[int] = []
	
	for track_id in current_priorities.keys():
		if current_priorities[track_id] >= priority_config.high_threshold:
			high_priority_tracks.append(track_id)
	
	return high_priority_tracks

## Get critical priority targets
func get_critical_priority_targets() -> Array[int]:
	var critical_priority_tracks: Array[int] = []
	
	for track_id in current_priorities.keys():
		if current_priorities[track_id] >= priority_config.critical_threshold:
			critical_priority_tracks.append(track_id)
	
	return critical_priority_tracks

## Automatic priority management
func _on_auto_management_timer() -> void:
	if not auto_management_enabled:
		return
	
	_perform_automatic_priority_adjustment()
	_resolve_priority_conflicts()
	_apply_priority_decay()

func _perform_automatic_priority_adjustment() -> void:
	# Get player position for proximity calculations
	var player_position = _get_player_position()
	
	# Boost priority for very close threats
	for track_id in current_priorities.keys():
		var current_priority = current_priorities[track_id]
		
		# This would need actual track data to work properly
		# For now, we'll just implement the framework
		
		# In a real implementation, we'd check:
		# - Distance to player
		# - Immediate threat level
		# - Engagement status
		# - Target behavior patterns
	
	print("TargetPriorityManager: Performed automatic priority adjustment")

func _resolve_priority_conflicts() -> void:
	# Find targets with similar priorities that might need differentiation
	var priority_groups: Dictionary = {}
	
	for track_id in current_priorities.keys():
		var priority = current_priorities[track_id]
		if not priority_groups.has(priority):
			priority_groups[priority] = []
		priority_groups[priority].append(track_id)
	
	# Resolve conflicts for groups with multiple targets
	for priority in priority_groups.keys():
		var tracks = priority_groups[priority]
		if tracks.size() > 1:
			_differentiate_similar_priority_targets(tracks, priority)

func _differentiate_similar_priority_targets(tracks: Array, base_priority: int) -> void:
	# Apply small adjustments to break ties
	for i in range(tracks.size()):
		var track_id = tracks[i]
		var adjustment = (i - tracks.size() / 2) * 2  # Spread around base priority
		var new_priority = clamp(base_priority + adjustment, priority_config.min_priority, priority_config.max_priority)
		
		if current_priorities[track_id] != new_priority:
			var old_priority = current_priorities[track_id]
			current_priorities[track_id] = new_priority
			priority_changed.emit(track_id, old_priority, new_priority)
	
	priority_conflict_resolved.emit(tracks, "priority_spread")

func _apply_priority_decay() -> void:
	# Decay priorities for targets that haven't been updated recently
	var current_time = Time.get_ticks_usec() / 1000000.0
	var decay_amount = priority_decay_rate * 2.0  # 2 second interval
	
	for track_id in current_priorities.keys():
		var last_update = _get_last_priority_update_time(track_id)
		var time_since_update = current_time - last_update
		
		if time_since_update > 5.0:  # Decay after 5 seconds without update
			var old_priority = current_priorities[track_id]
			var decay = int(decay_amount * time_since_update)
			var new_priority = max(priority_config.min_priority, old_priority - decay)
			
			if new_priority != old_priority:
				current_priorities[track_id] = new_priority
				priority_changed.emit(track_id, old_priority, new_priority)

## Priority history and tracking

func _record_priority_change(track_id: int, old_priority: int, new_priority: int) -> void:
	if not priority_history.has(track_id):
		priority_history[track_id] = []
	
	var history = priority_history[track_id]
	var timestamp = Time.get_ticks_usec() / 1000000.0
	
	history.append({
		"timestamp": timestamp,
		"old_priority": old_priority,
		"new_priority": new_priority
	})
	
	# Keep only recent history (last 50 changes)
	if history.size() > 50:
		history.pop_front()

func _get_last_priority_update_time(track_id: int) -> float:
	if priority_history.has(track_id) and not priority_history[track_id].is_empty():
		var history = priority_history[track_id]
		return history.back().timestamp
	
	return Time.get_ticks_usec() / 1000000.0  # Current time as fallback

## Configuration management

## Update priority weights
func update_priority_weights(new_weights: Dictionary) -> void:
	for key in new_weights.keys():
		if priority_weights.has(key):
			priority_weights[key] = new_weights[key]
	
	# Normalize weights to sum to 1.0
	_normalize_priority_weights()

func _normalize_priority_weights() -> void:
	var total_weight = 0.0
	for weight in priority_weights.values():
		total_weight += weight
	
	if total_weight > 0.0:
		for key in priority_weights.keys():
			priority_weights[key] = priority_weights[key] / total_weight

## Update target type priorities
func update_target_type_priorities(new_priorities: Dictionary) -> void:
	for key in new_priorities.keys():
		target_type_priorities[key] = new_priorities[key]

## Update priority configuration
func update_priority_config(new_config: Dictionary) -> void:
	for key in new_config.keys():
		if priority_config.has(key):
			priority_config[key] = new_config[key]

## Remove target from priority management
func remove_target(track_id: int) -> void:
	current_priorities.erase(track_id)
	priority_history.erase(track_id)

## Clear all priority data
func clear_all_priorities() -> void:
	current_priorities.clear()
	priority_history.clear()

## Timer callbacks

func _on_priority_update_timer() -> void:
	last_priority_update = Time.get_ticks_usec() / 1000000.0
	
	# This timer just tracks when we should do updates
	# The actual updates are triggered by the MultiTargetTracker

## Utility functions

func _get_player_position() -> Vector3:
	var player_ship = _get_player_ship()
	return player_ship.global_position if player_ship else Vector3.ZERO

func _get_player_ship() -> Node:
	var player_ships = get_tree().get_nodes_in_group("player_ships")
	return player_ships[0] if not player_ships.is_empty() else null

## Status and debugging

## Get priority manager status
func get_priority_status() -> Dictionary:
	return {
		"auto_management_enabled": auto_management_enabled,
		"max_targets": max_targets,
		"update_frequency": priority_update_frequency,
		"active_priorities": current_priorities.size(),
		"priority_weights": priority_weights,
		"critical_threshold": priority_config.critical_threshold,
		"high_threshold": priority_config.high_threshold,
		"last_update": last_priority_update
	}

## Get performance statistics
func get_performance_stats() -> Dictionary:
	return {
		"calculation_time_ms": calculation_time_ms,
		"priorities_per_second": priorities_calculated_per_second,
		"changes_per_second": priority_changes_per_second,
		"active_targets": current_priorities.size(),
		"history_entries": _count_total_history_entries()
	}

func _count_total_history_entries() -> int:
	var total = 0
	for history in priority_history.values():
		total += history.size()
	return total

## Get priority distribution
func get_priority_distribution() -> Dictionary:
	var distribution = {
		"critical": 0,
		"high": 0,
		"medium": 0,
		"low": 0
	}
	
	for priority in current_priorities.values():
		if priority >= priority_config.critical_threshold:
			distribution.critical += 1
		elif priority >= priority_config.high_threshold:
			distribution.high += 1
		elif priority >= priority_config.low_threshold:
			distribution.medium += 1
		else:
			distribution.low += 1
	
	return distribution

## Debug information
func get_debug_info() -> String:
	var debug_text = "TargetPriorityManager Debug Info:\n"
	debug_text += "Active Targets: %d\n" % current_priorities.size()
	debug_text += "Auto Management: %s\n" % auto_management_enabled
	debug_text += "Update Frequency: %.1f Hz\n" % priority_update_frequency
	debug_text += "Last Calculation: %.2f ms\n" % calculation_time_ms
	
	var distribution = get_priority_distribution()
	debug_text += "Priority Distribution:\n"
	debug_text += "  Critical: %d\n" % distribution.critical
	debug_text += "  High: %d\n" % distribution.high
	debug_text += "  Medium: %d\n" % distribution.medium
	debug_text += "  Low: %d\n" % distribution.low
	
	return debug_text
