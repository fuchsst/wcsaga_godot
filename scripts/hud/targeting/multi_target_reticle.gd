class_name MultiTargetReticle
extends Control

## HUD-006: Multi-Target Reticle System
## Handles simultaneous reticle display for multiple weapons and targets
## with weapon group coordination and target switching optimization

signal target_list_updated(targets: Array[Node])
signal weapon_group_changed(group_id: String, weapons: Array[Node])
signal reticle_switching_completed(old_target: Node, new_target: Node)
signal multi_reticle_performance_warning(frame_time_ms: float)

# Target and weapon management
var tracked_targets: Array[Node] = []
var primary_target: Node = null
var secondary_targets: Array[Node] = []
var weapon_groups: Dictionary = {}  # group_id -> Array[Node]
var reticle_instances: Dictionary = {}  # target_id -> TargetingReticle

# Display configuration
var max_simultaneous_reticles: int = 5
var max_secondary_targets: int = 3
var primary_reticle_priority: bool = true
var show_secondary_reticles: bool = true

# Performance management
var reticle_lod_manager: Dictionary = {}
var update_frequency_map: Dictionary = {}
var performance_budget_ms: float = 3.0  # Max 3ms per frame for reticles
var adaptive_lod_enabled: bool = true

# Target switching
var target_switch_queue: Array[Node] = []
var switch_animation_duration: float = 0.2
var switch_interpolation_enabled: bool = true
var rapid_switch_detection: bool = true
var switch_cooldown_time: float = 0.1

# Visual priority system
var reticle_priorities: Dictionary = {}
var priority_colors: Dictionary = {
	"primary": Color.GREEN,
	"secondary": Color.YELLOW,
	"tertiary": Color.ORANGE,
	"background": Color.GRAY
}

# Performance tracking
var frame_start_time: int = 0
var reticle_update_times: Dictionary = {}
var performance_warnings: int = 0

func _ready() -> void:
	set_process(true)
	_initialize_multi_target_system()
	print("MultiTargetReticle: Multi-target reticle system initialized")

func _initialize_multi_target_system() -> void:
	# Set up full-screen canvas for multi-reticle display
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Initialize weapon groups
	weapon_groups = {
		"primary": [],
		"secondary": [],
		"missiles": [],
		"turrets": []
	}
	
	# Initialize performance tracking
	for i in range(max_simultaneous_reticles):
		reticle_update_times[i] = 0.0
		update_frequency_map[i] = 60.0  # Start at full frequency

## Set primary target with full reticle display
func set_primary_target(target: Node) -> void:
	if primary_target == target:
		return
	
	var old_target = primary_target
	primary_target = target
	
	# Update primary target reticle
	if target:
		_ensure_reticle_exists(target, "primary")
		_update_target_priority(target, 1.0)
	
	# Clean up old primary reticle if it's not in secondary targets
	if old_target and not secondary_targets.has(old_target):
		_remove_reticle(old_target)
	
	_update_tracked_targets()
	target_list_updated.emit(tracked_targets)
	
	print("MultiTargetReticle: Primary target set to %s" % (target.name if target else "None"))

## Add secondary target with reduced reticle display
func add_secondary_target(target: Node) -> void:
	if not target or secondary_targets.has(target) or target == primary_target:
		return
	
	# Limit secondary targets
	if secondary_targets.size() >= max_secondary_targets:
		# Remove least important secondary target
		var least_important = _find_least_important_secondary()
		if least_important:
			remove_secondary_target(least_important)
	
	secondary_targets.append(target)
	
	if show_secondary_reticles:
		_ensure_reticle_exists(target, "secondary")
		var priority = 0.7 - (secondary_targets.size() * 0.1)  # Decreasing priority
		_update_target_priority(target, priority)
	
	_update_tracked_targets()
	target_list_updated.emit(tracked_targets)
	
	print("MultiTargetReticle: Added secondary target %s" % target.name)

## Remove secondary target
func remove_secondary_target(target: Node) -> void:
	if not secondary_targets.has(target):
		return
	
	secondary_targets.erase(target)
	_remove_reticle(target)
	
	# Rebalance remaining secondary target priorities
	_rebalance_secondary_priorities()
	
	_update_tracked_targets()
	target_list_updated.emit(tracked_targets)
	
	print("MultiTargetReticle: Removed secondary target %s" % target.name)

func _find_least_important_secondary() -> Node:
	if secondary_targets.is_empty():
		return null
	
	var least_important = secondary_targets[0]
	var lowest_priority = reticle_priorities.get(least_important.get_instance_id(), 0.0)
	
	for target in secondary_targets:
		var priority = reticle_priorities.get(target.get_instance_id(), 0.0)
		if priority < lowest_priority:
			lowest_priority = priority
			least_important = target
	
	return least_important

func _rebalance_secondary_priorities() -> void:
	for i in range(secondary_targets.size()):
		var target = secondary_targets[i]
		var priority = 0.7 - (i * 0.1)
		_update_target_priority(target, priority)

func _update_tracked_targets() -> void:
	tracked_targets.clear()
	
	if primary_target:
		tracked_targets.append(primary_target)
	
	for target in secondary_targets:
		tracked_targets.append(target)

## Configure weapon groups for multi-weapon reticles
func set_weapon_group(group_id: String, weapons: Array[Node]) -> void:
	weapon_groups[group_id] = weapons.duplicate()
	
	# Update reticles for all targets with this weapon group
	for target in tracked_targets:
		var reticle = _get_reticle_for_target(target)
		if reticle:
			reticle.set_active_weapons(weapons)
	
	weapon_group_changed.emit(group_id, weapons)
	print("MultiTargetReticle: Weapon group '%s' updated with %d weapons" % [group_id, weapons.size()])

## Switch targets with smooth transition
func switch_target(new_target: Node, transition_type: String = "smooth") -> void:
	if new_target == primary_target:
		return
	
	# Add to switch queue for smooth handling
	if rapid_switch_detection and target_switch_queue.size() > 0:
		# Replace last queued switch to prevent spam
		target_switch_queue[-1] = new_target
	else:
		target_switch_queue.append(new_target)
	
	_process_target_switch_queue()

func _process_target_switch_queue() -> void:
	if target_switch_queue.is_empty():
		return
	
	var next_target = target_switch_queue.pop_front()
	var old_target = primary_target
	
	# Perform the switch
	if switch_interpolation_enabled:
		_smooth_target_switch(old_target, next_target)
	else:
		_instant_target_switch(old_target, next_target)
	
	reticle_switching_completed.emit(old_target, next_target)

func _smooth_target_switch(old_target: Node, new_target: Node) -> void:
	# Implement smooth transition animation
	var old_reticle = _get_reticle_for_target(old_target) if old_target else null
	var new_reticle = _get_reticle_for_target(new_target)
	
	if new_reticle:
		new_reticle.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(new_reticle, "modulate:a", 1.0, switch_animation_duration)
	
	if old_reticle and old_target != new_target:
		var tween = create_tween()
		tween.tween_property(old_reticle, "modulate:a", 0.6, switch_animation_duration)
	
	# Update target assignments
	set_primary_target(new_target)
	if old_target and old_target != new_target:
		add_secondary_target(old_target)

func _instant_target_switch(old_target: Node, new_target: Node) -> void:
	# Immediate target switch
	set_primary_target(new_target)
	if old_target and old_target != new_target:
		add_secondary_target(old_target)

## Ensure reticle exists for target
func _ensure_reticle_exists(target: Node, reticle_type: String) -> void:
	var target_id = target.get_instance_id()
	
	if reticle_instances.has(target_id):
		return  # Already exists
	
	# Create new targeting reticle
	var reticle = TargetingReticle.new()
	reticle.set_target(target)
	
	# Configure based on type
	match reticle_type:
		"primary":
			reticle.update_frequency = 60.0
			reticle.modulate = priority_colors["primary"]
		"secondary":
			reticle.update_frequency = 30.0
			reticle.modulate = priority_colors["secondary"]
		"tertiary":
			reticle.update_frequency = 15.0
			reticle.modulate = priority_colors["tertiary"]
		_:
			reticle.update_frequency = 30.0
			reticle.modulate = priority_colors["background"]
	
	# Set active weapons (use primary weapon group)
	var primary_weapons = weapon_groups.get("primary", [])
	if not primary_weapons.is_empty():
		reticle.set_active_weapons(primary_weapons)
	
	add_child(reticle)
	reticle_instances[target_id] = reticle
	
	print("MultiTargetReticle: Created %s reticle for target %s" % [reticle_type, target.name])

## Remove reticle for target
func _remove_reticle(target: Node) -> void:
	var target_id = target.get_instance_id()
	
	if reticle_instances.has(target_id):
		var reticle = reticle_instances[target_id]
		reticle.queue_free()
		reticle_instances.erase(target_id)
		reticle_priorities.erase(target_id)
		reticle_update_times.erase(target_id)
		
		print("MultiTargetReticle: Removed reticle for target %s" % target.name)

## Get reticle instance for target
func _get_reticle_for_target(target: Node) -> TargetingReticle:
	if not target:
		return null
	
	var target_id = target.get_instance_id()
	return reticle_instances.get(target_id)

## Update target priority
func _update_target_priority(target: Node, priority: float) -> void:
	var target_id = target.get_instance_id()
	reticle_priorities[target_id] = priority
	
	# Update reticle display based on priority
	var reticle = _get_reticle_for_target(target)
	if reticle:
		# Adjust visual prominence based on priority
		var alpha = 0.4 + (priority * 0.6)  # Range from 0.4 to 1.0
		reticle.modulate.a = alpha
		
		# Adjust update frequency based on priority
		if adaptive_lod_enabled:
			var frequency = 15.0 + (priority * 45.0)  # Range from 15 to 60 Hz
			update_frequency_map[target_id] = frequency

## Performance monitoring and LOD management
func _process(delta: float) -> void:
	frame_start_time = Time.get_ticks_usec()
	
	# Update all active reticles with performance monitoring
	_update_all_reticles_with_lod()
	
	# Check performance budget
	var frame_end_time = Time.get_ticks_usec()
	var frame_time_ms = (frame_end_time - frame_start_time) / 1000.0
	
	if frame_time_ms > performance_budget_ms:
		_handle_performance_warning(frame_time_ms)
	
	# Process target switch queue
	if not target_switch_queue.is_empty():
		_process_target_switch_queue()

func _update_all_reticles_with_lod() -> void:
	var update_start_time = Time.get_ticks_usec()
	
	for target_id in reticle_instances.keys():
		var reticle = reticle_instances[target_id]
		var priority = reticle_priorities.get(target_id, 0.5)
		
		# Skip low-priority reticles if over budget
		var current_time_ms = (Time.get_ticks_usec() - update_start_time) / 1000.0
		if current_time_ms > performance_budget_ms * 0.8 and priority < 0.3:
			continue
		
		# Update reticle with appropriate frequency
		var update_frequency = update_frequency_map.get(target_id, 30.0)
		var update_interval = 1.0 / update_frequency
		
		var last_update = reticle_update_times.get(target_id, 0.0)
		var current_time = Time.get_ticks_usec() / 1000000.0
		
		if current_time - last_update >= update_interval:
			_update_single_reticle(reticle, target_id)
			reticle_update_times[target_id] = current_time

func _update_single_reticle(reticle: TargetingReticle, target_id: int) -> void:
	var reticle_start_time = Time.get_ticks_usec()
	
	# Update the reticle
	reticle.update_element()
	
	# Track update time for this reticle
	var reticle_time_ms = (Time.get_ticks_usec() - reticle_start_time) / 1000.0
	reticle_update_times[target_id] = reticle_time_ms

func _handle_performance_warning(frame_time_ms: float) -> void:
	performance_warnings += 1
	multi_reticle_performance_warning.emit(frame_time_ms)
	
	# Adaptive LOD reduction
	if adaptive_lod_enabled:
		_reduce_reticle_lod()
	
	print("MultiTargetReticle: Performance warning - frame time %.2fms exceeds budget %.2fms" % [frame_time_ms, performance_budget_ms])

func _reduce_reticle_lod() -> void:
	# Reduce update frequencies for all reticles
	for target_id in update_frequency_map.keys():
		var current_freq = update_frequency_map[target_id]
		var reduced_freq = max(5.0, current_freq * 0.8)  # Reduce by 20%, min 5 Hz
		update_frequency_map[target_id] = reduced_freq
		
		# Reduce visual quality for low-priority reticles
		var priority = reticle_priorities.get(target_id, 0.5)
		if priority < 0.5:
			var reticle = reticle_instances.get(target_id)
			if reticle and reticle.has_method("set_render_lod"):
				reticle.set_render_lod(1)  # Reduced quality

## Target management utilities
func get_all_tracked_targets() -> Array[Node]:
	return tracked_targets.duplicate()

func get_primary_target() -> Node:
	return primary_target

func get_secondary_targets() -> Array[Node]:
	return secondary_targets.duplicate()

func clear_all_targets() -> void:
	# Clear primary target
	primary_target = null
	
	# Clear secondary targets
	secondary_targets.clear()
	
	# Remove all reticles
	for target_id in reticle_instances.keys():
		var reticle = reticle_instances[target_id]
		reticle.queue_free()
	
	reticle_instances.clear()
	reticle_priorities.clear()
	reticle_update_times.clear()
	tracked_targets.clear()
	
	target_list_updated.emit(tracked_targets)
	print("MultiTargetReticle: Cleared all targets and reticles")

## Configuration
func configure_multi_target_system(config: Dictionary) -> void:
	if config.has("max_simultaneous_reticles"):
		max_simultaneous_reticles = config["max_simultaneous_reticles"]
	
	if config.has("max_secondary_targets"):
		max_secondary_targets = config["max_secondary_targets"]
	
	if config.has("show_secondary_reticles"):
		show_secondary_reticles = config["show_secondary_reticles"]
	
	if config.has("performance_budget_ms"):
		performance_budget_ms = config["performance_budget_ms"]
	
	if config.has("adaptive_lod_enabled"):
		adaptive_lod_enabled = config["adaptive_lod_enabled"]
	
	if config.has("switch_animation_duration"):
		switch_animation_duration = config["switch_animation_duration"]
	
	if config.has("switch_interpolation_enabled"):
		switch_interpolation_enabled = config["switch_interpolation_enabled"]
	
	if config.has("priority_colors"):
		var colors = config["priority_colors"]
		for color_name in colors.keys():
			priority_colors[color_name] = colors[color_name]
	
	print("MultiTargetReticle: Configuration updated")

## Get system statistics
func get_multi_target_statistics() -> Dictionary:
	return {
		"tracked_targets": tracked_targets.size(),
		"primary_target": primary_target.name if primary_target else "None",
		"secondary_targets": secondary_targets.size(),
		"active_reticles": reticle_instances.size(),
		"weapon_groups": weapon_groups.size(),
		"performance_warnings": performance_warnings,
		"switch_queue_size": target_switch_queue.size(),
		"adaptive_lod_enabled": adaptive_lod_enabled,
		"performance_budget_ms": performance_budget_ms,
		"average_reticle_update_time": _calculate_average_update_time()
	}

func _calculate_average_update_time() -> float:
	if reticle_update_times.is_empty():
		return 0.0
	
	var total_time = 0.0
	var count = 0
	
	for target_id in reticle_update_times.keys():
		var update_time = reticle_update_times[target_id]
		if update_time > 0:
			total_time += update_time
			count += 1
	
	return total_time / max(1, count)
