class_name HUDLODManager
extends Node

## EPIC-012 HUD-003: Level-of-Detail management for HUD elements
## Provides performance optimization through intelligent LOD scaling

signal lod_level_changed(element_id: String, old_level: LODLevel, new_level: LODLevel)
signal global_lod_changed(old_level: LODLevel, new_level: LODLevel)

# LOD levels from highest to lowest quality
enum LODLevel {
	MAXIMUM = 0,  # Full quality, 60 FPS updates
	HIGH = 1,     # High quality, 45 FPS updates  
	MEDIUM = 2,   # Medium quality, 30 FPS updates
	LOW = 3,      # Low quality, 15 FPS updates
	MINIMAL = 4   # Minimal quality, 5 FPS updates
}

# Element priority levels for LOD assignment
enum ElementPriority {
	CRITICAL = 0,  # Always maintain highest LOD (targeting, flight data)
	HIGH = 1,      # Maintain good LOD (weapons, shields)
	MEDIUM = 2,    # Can reduce LOD under pressure (secondary info)
	LOW = 3        # First to reduce LOD (decorative elements)
}

# Global LOD settings
var global_lod_level: LODLevel = LODLevel.MAXIMUM
var auto_lod_enabled: bool = true
var lod_hysteresis_time: float = 2.0  # Prevent rapid LOD changes

# Element-specific LOD configuration
var element_lod_levels: Dictionary = {}           # element_id -> current LODLevel
var element_priorities: Dictionary = {}           # element_id -> ElementPriority
var element_lod_overrides: Dictionary = {}        # element_id -> manual LODLevel override
var element_min_lod: Dictionary = {}              # element_id -> minimum allowed LODLevel

# LOD transition timing
var lod_change_timers: Dictionary = {}            # element_id -> time since last LOD change
var global_lod_change_timer: float = 0.0

# Performance thresholds for automatic LOD adjustment
var fps_thresholds: Dictionary = {
	LODLevel.MAXIMUM: 58.0,   # Above 58 FPS: MAXIMUM LOD
	LODLevel.HIGH: 50.0,      # Above 50 FPS: HIGH LOD
	LODLevel.MEDIUM: 40.0,    # Above 40 FPS: MEDIUM LOD
	LODLevel.LOW: 30.0,       # Above 30 FPS: LOW LOD
	LODLevel.MINIMAL: 20.0    # Below 30 FPS: MINIMAL LOD
}

# Update frequency mapping for each LOD level
var lod_update_frequencies: Dictionary = {
	LODLevel.MAXIMUM: 60.0,   # 60 FPS
	LODLevel.HIGH: 45.0,      # 45 FPS
	LODLevel.MEDIUM: 30.0,    # 30 FPS
	LODLevel.LOW: 15.0,       # 15 FPS
	LODLevel.MINIMAL: 5.0     # 5 FPS
}

# Statistics tracking
var lod_adjustment_count: int = 0
var performance_based_adjustments: int = 0
var manual_overrides_active: int = 0

func _ready() -> void:
	print("HUDLODManager: Initializing LOD management system")
	_initialize_lod_system()

func _initialize_lod_system() -> void:
	# Set up default LOD configuration
	global_lod_level = LODLevel.MAXIMUM
	
	# Start performance monitoring
	set_process(true)
	
	print("HUDLODManager: LOD system initialized with MAXIMUM quality")

func _process(delta: float) -> void:
	# Update timing for LOD hysteresis
	global_lod_change_timer += delta
	
	for element_id in lod_change_timers:
		lod_change_timers[element_id] += delta
	
	# Auto-adjust LOD based on performance if enabled
	if auto_lod_enabled:
		_update_automatic_lod()

## Register an element with the LOD system
func register_element(element_id: String, priority: ElementPriority, min_lod: LODLevel = LODLevel.MINIMAL) -> void:
	element_priorities[element_id] = priority
	element_min_lod[element_id] = min_lod
	element_lod_levels[element_id] = global_lod_level
	lod_change_timers[element_id] = 0.0
	
	print("HUDLODManager: Registered element %s with priority %s" % [element_id, ElementPriority.keys()[priority]])

## Unregister an element from the LOD system
func unregister_element(element_id: String) -> void:
	element_priorities.erase(element_id)
	element_min_lod.erase(element_id)
	element_lod_levels.erase(element_id)
	element_lod_overrides.erase(element_id)
	lod_change_timers.erase(element_id)
	
	print("HUDLODManager: Unregistered element %s" % element_id)

## Get current LOD level for an element
func get_element_lod(element_id: String) -> LODLevel:
	# Check for manual override first
	if element_lod_overrides.has(element_id):
		return element_lod_overrides[element_id]
	
	# Return element-specific LOD or global LOD
	return element_lod_levels.get(element_id, global_lod_level)

## Set LOD level for a specific element (manual override)
func set_element_lod(element_id: String, lod_level: LODLevel) -> void:
	if not element_priorities.has(element_id):
		push_warning("HUDLODManager: Trying to set LOD for unregistered element: %s" % element_id)
		return
	
	# Respect minimum LOD constraint
	var min_lod = element_min_lod.get(element_id, LODLevel.MINIMAL)
	var constrained_lod = min(lod_level, min_lod)
	
	var old_lod = get_element_lod(element_id)
	element_lod_overrides[element_id] = constrained_lod
	
	if old_lod != constrained_lod:
		lod_level_changed.emit(element_id, old_lod, constrained_lod)
		lod_adjustment_count += 1
		print("HUDLODManager: Set element %s LOD to %s (manual)" % [element_id, LODLevel.keys()[constrained_lod]])

## Remove manual LOD override for an element
func clear_element_lod_override(element_id: String) -> void:
	if element_lod_overrides.has(element_id):
		var old_lod = element_lod_overrides[element_id]
		element_lod_overrides.erase(element_id)
		
		var new_lod = get_element_lod(element_id)
		if old_lod != new_lod:
			lod_level_changed.emit(element_id, old_lod, new_lod)
		
		print("HUDLODManager: Cleared LOD override for element %s" % element_id)

## Set global LOD level (affects all elements without overrides)
func set_global_lod(lod_level: LODLevel) -> void:
	if global_lod_level == lod_level:
		return
	
	# Implement hysteresis to prevent rapid changes
	if global_lod_change_timer < lod_hysteresis_time:
		return
	
	var old_global_lod = global_lod_level
	global_lod_level = lod_level
	global_lod_change_timer = 0.0
	
	# Update all elements without overrides
	for element_id in element_priorities.keys():
		if not element_lod_overrides.has(element_id):
			var old_lod = element_lod_levels.get(element_id, old_global_lod)
			var min_lod = element_min_lod.get(element_id, LODLevel.MINIMAL)
			var new_lod = min(lod_level, min_lod)
			
			element_lod_levels[element_id] = new_lod
			
			if old_lod != new_lod:
				lod_level_changed.emit(element_id, old_lod, new_lod)
	
	global_lod_changed.emit(old_global_lod, global_lod_level)
	lod_adjustment_count += 1
	print("HUDLODManager: Global LOD changed from %s to %s" % [LODLevel.keys()[old_global_lod], LODLevel.keys()[global_lod_level]])

## Get update frequency for an LOD level
func get_lod_update_frequency(lod_level: LODLevel) -> float:
	return lod_update_frequencies.get(lod_level, 30.0)

## Get update interval for an LOD level
func get_lod_update_interval(lod_level: LODLevel) -> float:
	var frequency = get_lod_update_frequency(lod_level)
	return 1.0 / frequency

## Automatically adjust LOD based on current performance
func _update_automatic_lod() -> void:
	var current_fps = Engine.get_frames_per_second()
	var target_lod = _calculate_target_lod_for_fps(current_fps)
	
	if target_lod != global_lod_level:
		set_global_lod(target_lod)
		performance_based_adjustments += 1

## Calculate target LOD level based on current FPS
func _calculate_target_lod_for_fps(fps: float) -> LODLevel:
	# Find appropriate LOD level based on FPS thresholds
	if fps >= fps_thresholds[LODLevel.MAXIMUM]:
		return LODLevel.MAXIMUM
	elif fps >= fps_thresholds[LODLevel.HIGH]:
		return LODLevel.HIGH
	elif fps >= fps_thresholds[LODLevel.MEDIUM]:
		return LODLevel.MEDIUM
	elif fps >= fps_thresholds[LODLevel.LOW]:
		return LODLevel.LOW
	else:
		return LODLevel.MINIMAL

## Adjust LOD for performance critical scenarios
func enable_performance_mode() -> void:
	print("HUDLODManager: Enabling performance mode")
	
	# Reduce LOD for non-critical elements
	for element_id in element_priorities.keys():
		var priority = element_priorities[element_id]
		
		match priority:
			ElementPriority.CRITICAL:
				# Keep critical elements at high quality
				continue
			ElementPriority.HIGH:
				# Reduce high priority elements to MEDIUM
				set_element_lod(element_id, LODLevel.MEDIUM)
			ElementPriority.MEDIUM:
				# Reduce medium priority elements to LOW
				set_element_lod(element_id, LODLevel.LOW)
			ElementPriority.LOW:
				# Reduce low priority elements to MINIMAL
				set_element_lod(element_id, LODLevel.MINIMAL)

## Restore normal LOD levels
func disable_performance_mode() -> void:
	print("HUDLODManager: Disabling performance mode")
	
	# Clear all manual overrides to restore automatic LOD
	for element_id in element_lod_overrides.keys():
		clear_element_lod_override(element_id)

## Enable or disable automatic LOD adjustment
func set_auto_lod_enabled(enabled: bool) -> void:
	auto_lod_enabled = enabled
	print("HUDLODManager: Automatic LOD adjustment %s" % ("enabled" if enabled else "disabled"))

## Get LOD statistics
func get_lod_statistics() -> Dictionary:
	var stats = {
		"global_lod_level": LODLevel.keys()[global_lod_level],
		"auto_lod_enabled": auto_lod_enabled,
		"registered_elements": element_priorities.size(),
		"manual_overrides": element_lod_overrides.size(),
		"total_adjustments": lod_adjustment_count,
		"performance_adjustments": performance_based_adjustments,
		"current_fps": Engine.get_frames_per_second()
	}
	
	# Add per-element LOD information
	var element_lods = {}
	for element_id in element_priorities.keys():
		element_lods[element_id] = {
			"current_lod": LODLevel.keys()[get_element_lod(element_id)],
			"priority": ElementPriority.keys()[element_priorities[element_id]],
			"has_override": element_lod_overrides.has(element_id),
			"min_lod": LODLevel.keys()[element_min_lod.get(element_id, LODLevel.MINIMAL)],
			"update_frequency": get_lod_update_frequency(get_element_lod(element_id))
		}
	
	stats["element_lods"] = element_lods
	return stats

## Configure FPS thresholds for LOD levels
func set_fps_thresholds(thresholds: Dictionary) -> void:
	fps_thresholds = thresholds
	print("HUDLODManager: Updated FPS thresholds for LOD adjustment")

## Get recommended LOD level for an element based on its priority and current performance
func get_recommended_lod(element_id: String, current_fps: float) -> LODLevel:
	if not element_priorities.has(element_id):
		return global_lod_level
	
	var priority = element_priorities[element_id]
	var base_lod = _calculate_target_lod_for_fps(current_fps)
	
	# Adjust LOD based on element priority
	match priority:
		ElementPriority.CRITICAL:
			# Critical elements get better LOD
			return max(LODLevel.MAXIMUM, base_lod - 1) if base_lod > LODLevel.MAXIMUM else LODLevel.MAXIMUM
		ElementPriority.HIGH:
			# High priority elements maintain base LOD
			return base_lod
		ElementPriority.MEDIUM:
			# Medium priority elements get slightly reduced LOD
			return min(LODLevel.MINIMAL, base_lod + 1) if base_lod < LODLevel.MINIMAL else LODLevel.MINIMAL
		ElementPriority.LOW:
			# Low priority elements get significantly reduced LOD
			return min(LODLevel.MINIMAL, base_lod + 2) if base_lod < LODLevel.MEDIUM else LODLevel.MINIMAL
	
	return base_lod