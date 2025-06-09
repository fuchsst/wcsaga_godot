class_name HUDRenderOptimizer
extends Node

## EPIC-012 HUD-003: Render optimization for HUD elements
## Manages culling, batching, and efficient rendering of HUD components

signal element_culled(element_id: String, reason: String)
signal batch_rendered(batch_type: String, element_count: int, render_time_ms: float)
signal render_optimization_applied(optimization_type: String, savings_ms: float)

# Culling configuration
@export var enable_culling: bool = true
@export var culling_margin: float = 50.0              # Extra margin for culling bounds
@export var off_screen_culling: bool = true           # Cull elements outside viewport
@export var occlusion_culling: bool = false           # Cull elements behind others (advanced)
@export var distance_culling: bool = true             # Cull elements too far from focus

# Batching configuration
@export var enable_batching: bool = true
@export var batch_similar_elements: bool = true       # Batch elements with same material/texture
@export var max_batch_size: int = 50                  # Maximum elements per batch
@export var batch_time_budget_ms: float = 0.5         # Time budget for batching operations

# Element tracking for optimization
var tracked_elements: Dictionary = {}                 # element_id -> element_info
var element_visibility: Dictionary = {}               # element_id -> visibility state
var element_render_bounds: Dictionary = {}            # element_id -> Rect2 bounds
var element_materials: Dictionary = {}                # element_id -> material hash
var element_z_layers: Dictionary = {}                 # element_id -> z-layer

# Render batches
var render_batches: Dictionary = {}                   # batch_key -> batch_info
var batch_dirty_flags: Dictionary = {}               # batch_key -> needs rebuild
var batch_element_lists: Dictionary = {}             # batch_key -> Array[element_id]

# Culling results
var culled_elements: Dictionary = {}                  # element_id -> culling reason
var culling_stats: Dictionary = {}                   # Statistics for different culling types

# Performance tracking
var total_elements_tracked: int = 0
var elements_rendered_this_frame: int = 0
var elements_culled_this_frame: int = 0
var batches_rendered_this_frame: int = 0
var render_optimization_savings_ms: float = 0.0

# Viewport information
var viewport_size: Vector2
var viewport_rect: Rect2
var camera_transform: Transform2D

func _ready() -> void:
	print("HUDRenderOptimizer: Initializing render optimization system")
	_initialize_optimizer()

func _initialize_optimizer() -> void:
	# Get initial viewport information
	_update_viewport_info()
	
	# Set up frame processing
	set_process(true)
	
	# Initialize culling statistics
	culling_stats = {
		"off_screen": 0,
		"distance": 0,
		"occlusion": 0,
		"manual": 0,
		"total": 0
	}
	
	print("HUDRenderOptimizer: Render optimizer initialized")

func _process(delta: float) -> void:
	if not (enable_culling or enable_batching):
		return
	
	# Update viewport information
	_update_viewport_info()
	
	# Reset frame counters
	elements_rendered_this_frame = 0
	elements_culled_this_frame = 0
	batches_rendered_this_frame = 0
	render_optimization_savings_ms = 0.0
	
	# Perform culling operations
	if enable_culling:
		_perform_culling()
	
	# Update render batches
	if enable_batching:
		_update_render_batches()

## Register an element for render optimization
func register_element(element_id: String, element_node: Control, material_hash: String = "", z_layer: int = 0) -> void:
	tracked_elements[element_id] = {
		"node": element_node,
		"material_hash": material_hash,
		"z_layer": z_layer,
		"last_bounds": Rect2(),
		"render_enabled": true,
		"cull_enabled": true
	}
	
	element_visibility[element_id] = true
	element_materials[element_id] = material_hash
	element_z_layers[element_id] = z_layer
	
	# Update render bounds
	_update_element_bounds(element_id)
	
	# Add to appropriate render batch
	if enable_batching:
		_add_element_to_batch(element_id)
	
	total_elements_tracked += 1
	print("HUDRenderOptimizer: Registered element %s (material: %s, z-layer: %d)" % [element_id, material_hash, z_layer])

## Unregister an element from render optimization
func unregister_element(element_id: String) -> void:
	if not tracked_elements.has(element_id):
		return
	
	# Remove from batches
	_remove_element_from_batch(element_id)
	
	# Clean up tracking data
	tracked_elements.erase(element_id)
	element_visibility.erase(element_id)
	element_render_bounds.erase(element_id)
	element_materials.erase(element_id)
	element_z_layers.erase(element_id)
	culled_elements.erase(element_id)
	
	total_elements_tracked -= 1
	print("HUDRenderOptimizer: Unregistered element %s" % element_id)

## Update element bounds for culling calculations
func update_element_bounds(element_id: String, bounds: Rect2) -> void:
	if not tracked_elements.has(element_id):
		return
	
	element_render_bounds[element_id] = bounds
	
	# Check if element needs to move to different batch
	if enable_batching:
		_check_batch_reassignment(element_id)

## Set element visibility (manual override)
func set_element_visibility(element_id: String, visible: bool, reason: String = "manual") -> void:
	if not tracked_elements.has(element_id):
		return
	
	var was_visible = element_visibility.get(element_id, true)
	element_visibility[element_id] = visible
	
	if was_visible != visible:
		if visible:
			# Element became visible, remove from culled list
			culled_elements.erase(element_id)
		else:
			# Element became hidden, add to culled list
			culled_elements[element_id] = reason
			element_culled.emit(element_id, reason)
		
		# Update batch if needed
		if enable_batching:
			_mark_batch_dirty_for_element(element_id)

## Check if an element is currently visible
func is_element_visible(element_id: String) -> bool:
	return element_visibility.get(element_id, false) and not culled_elements.has(element_id)

## Get elements that should be rendered this frame
func get_visible_elements() -> Array[String]:
	var visible_elements: Array[String] = []
	
	for element_id in tracked_elements.keys():
		if is_element_visible(element_id):
			visible_elements.append(element_id)
	
	return visible_elements

## Perform culling operations for all elements
func _perform_culling() -> void:
	var culling_start_time = Time.get_ticks_usec()
	var culled_count = 0
	
	for element_id in tracked_elements.keys():
		var element_info = tracked_elements[element_id]
		
		# Skip if culling disabled for this element
		if not element_info.get("cull_enabled", true):
			continue
		
		var should_cull = false
		var cull_reason = ""
		
		# Off-screen culling
		if off_screen_culling and _is_element_off_screen(element_id):
			should_cull = true
			cull_reason = "off_screen"
			culling_stats.off_screen += 1
		
		# Distance culling (for elements that scale based on distance)
		elif distance_culling and _is_element_too_distant(element_id):
			should_cull = true
			cull_reason = "distance"
			culling_stats.distance += 1
		
		# Occlusion culling (advanced feature)
		elif occlusion_culling and _is_element_occluded(element_id):
			should_cull = true
			cull_reason = "occlusion"
			culling_stats.occlusion += 1
		
		# Update culling state
		var was_culled = culled_elements.has(element_id)
		
		if should_cull and not was_culled:
			culled_elements[element_id] = cull_reason
			element_culled.emit(element_id, cull_reason)
			culled_count += 1
		elif not should_cull and was_culled:
			culled_elements.erase(element_id)
	
	var culling_end_time = Time.get_ticks_usec()
	var culling_time_ms = (culling_end_time - culling_start_time) / 1000.0
	
	elements_culled_this_frame = culled_count
	culling_stats.total += culled_count
	
	if culled_count > 0:
		render_optimization_applied.emit("culling", culling_time_ms)
		render_optimization_savings_ms += culling_time_ms

## Check if element is off-screen
func _is_element_off_screen(element_id: String) -> bool:
	var bounds = element_render_bounds.get(element_id, Rect2())
	
	if bounds.size == Vector2.ZERO:
		return false  # Can't determine bounds, assume visible
	
	# Add culling margin for smooth transitions
	var expanded_viewport = viewport_rect.grow(culling_margin)
	
	return not expanded_viewport.intersects(bounds)

## Check if element is too distant (placeholder for 3D distance culling)
func _is_element_too_distant(element_id: String) -> bool:
	# For 2D HUD elements, distance culling is typically not needed
	# This could be used for HUD elements that scale based on 3D world distance
	return false

## Check if element is occluded by other elements
func _is_element_occluded(element_id: String) -> bool:
	# Advanced occlusion culling - check if element is behind opaque elements
	# This is complex to implement efficiently and may not be worth it for HUD
	return false

## Update viewport information
func _update_viewport_info() -> void:
	var viewport = get_viewport()
	if viewport:
		viewport_size = viewport.get_visible_rect().size
		viewport_rect = Rect2(Vector2.ZERO, viewport_size)

## Update element bounds from its node
func _update_element_bounds(element_id: String) -> void:
	var element_info = tracked_elements.get(element_id)
	if not element_info:
		return
	
	var node = element_info.get("node")
	if not node or not is_instance_valid(node):
		return
	
	# Get global rect for the control node
	if node is Control:
		var control_node = node as Control
		var global_rect = control_node.get_global_rect()
		element_render_bounds[element_id] = global_rect

## Update render batches for efficient rendering
func _update_render_batches() -> void:
	if not enable_batching:
		return
	
	var batch_start_time = Time.get_ticks_usec()
	
	# Rebuild dirty batches
	for batch_key in batch_dirty_flags.keys():
		if batch_dirty_flags[batch_key]:
			_rebuild_batch(batch_key)
			batch_dirty_flags[batch_key] = false
	
	var batch_end_time = Time.get_ticks_usec()
	var batch_time_ms = (batch_end_time - batch_start_time) / 1000.0
	
	if batch_time_ms > 0.1:  # Only emit if significant time spent
		render_optimization_applied.emit("batching", batch_time_ms)

## Add element to appropriate render batch
func _add_element_to_batch(element_id: String) -> void:
	var material_hash = element_materials.get(element_id, "default")
	var z_layer = element_z_layers.get(element_id, 0)
	var batch_key = "%s_z%d" % [material_hash, z_layer]
	
	# Create batch if it doesn't exist
	if not render_batches.has(batch_key):
		render_batches[batch_key] = {
			"material_hash": material_hash,
			"z_layer": z_layer,
			"elements": []
		}
		batch_element_lists[batch_key] = []
		batch_dirty_flags[batch_key] = false
	
	# Add element to batch
	if not element_id in batch_element_lists[batch_key]:
		batch_element_lists[batch_key].append(element_id)
		_mark_batch_dirty(batch_key)

## Remove element from its render batch
func _remove_element_from_batch(element_id: String) -> void:
	# Find and remove element from all batches (inefficient but reliable)
	for batch_key in batch_element_lists.keys():
		var elements = batch_element_lists[batch_key]
		var index = elements.find(element_id)
		if index >= 0:
			elements.remove_at(index)
			_mark_batch_dirty(batch_key)
			
			# Remove empty batches
			if elements.is_empty():
				_remove_batch(batch_key)

## Mark a batch as needing rebuild
func _mark_batch_dirty(batch_key: String) -> void:
	batch_dirty_flags[batch_key] = true

## Mark batch dirty for a specific element
func _mark_batch_dirty_for_element(element_id: String) -> void:
	for batch_key in batch_element_lists.keys():
		if element_id in batch_element_lists[batch_key]:
			_mark_batch_dirty(batch_key)

## Check if element needs to be reassigned to different batch
func _check_batch_reassignment(element_id: String) -> void:
	# This would check if material or z-layer changed and move element accordingly
	pass

## Rebuild a render batch
func _rebuild_batch(batch_key: String) -> void:
	var batch_info = render_batches.get(batch_key)
	if not batch_info:
		return
	
	var visible_elements = []
	var elements = batch_element_lists.get(batch_key, [])
	
	for element_id in elements:
		if is_element_visible(element_id):
			visible_elements.append(element_id)
	
	batch_info.elements = visible_elements
	
	# Log batch rebuild for debugging
	if visible_elements.size() > 0:
		batch_rendered.emit(batch_key, visible_elements.size(), 0.0)

## Remove an empty batch
func _remove_batch(batch_key: String) -> void:
	render_batches.erase(batch_key)
	batch_element_lists.erase(batch_key)
	batch_dirty_flags.erase(batch_key)

## Get render optimization statistics
func get_statistics() -> Dictionary:
	return {
		"total_elements_tracked": total_elements_tracked,
		"elements_visible": get_visible_elements().size(),
		"elements_culled": culled_elements.size(),
		"elements_rendered_this_frame": elements_rendered_this_frame,
		"elements_culled_this_frame": elements_culled_this_frame,
		"batches_active": render_batches.size(),
		"batches_rendered_this_frame": batches_rendered_this_frame,
		"culling_enabled": enable_culling,
		"batching_enabled": enable_batching,
		"culling_stats": culling_stats,
		"optimization_savings_ms": render_optimization_savings_ms,
		"viewport_size": viewport_size
	}

## Enable or disable culling
func set_culling_enabled(enabled: bool) -> void:
	enable_culling = enabled
	
	if not enabled:
		# Clear all culling when disabled
		culled_elements.clear()
	
	print("HUDRenderOptimizer: Culling %s" % ("enabled" if enabled else "disabled"))

## Enable or disable batching
func set_batching_enabled(enabled: bool) -> void:
	enable_batching = enabled
	
	if not enabled:
		# Clear all batches when disabled
		render_batches.clear()
		batch_element_lists.clear()
		batch_dirty_flags.clear()
	
	print("HUDRenderOptimizer: Batching %s" % ("enabled" if enabled else "disabled"))

## Force update of all element bounds
func update_all_element_bounds() -> void:
	for element_id in tracked_elements.keys():
		_update_element_bounds(element_id)

## Get elements in a specific render batch
func get_batch_elements(batch_key: String) -> Array[String]:
	return batch_element_lists.get(batch_key, [])

## Get all active render batches
func get_active_batches() -> Array[String]:
	var active_batches: Array[String] = []
	
	for batch_key in render_batches.keys():
		var elements = batch_element_lists.get(batch_key, [])
		if not elements.is_empty():
			active_batches.append(batch_key)
	
	return active_batches