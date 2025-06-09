class_name HUDElementBase
extends Control

## EPIC-012 HUD-001: Base HUD Element Framework
## Abstract base class for all HUD elements in WCS-Godot conversion
## Provides standard interface, lifecycle management, data binding, and performance optimization

signal element_activated()
signal element_deactivated()
signal data_binding_changed(data_type: String)
signal performance_warning(frame_time_ms: float)

# Element identification and state
@export var element_id: String = ""
@export var element_priority: int = 0  # Higher values updated first
@export var is_active: bool = true
@export var auto_hide_when_inactive: bool = true

# Container and positioning
@export var container_type: String = "core"  # core, targeting, status, radar, communication, navigation
@export var anchor_mode: String = "top_left"  # top_left, center, bottom_right, etc.
@export var position_offset: Vector2 = Vector2.ZERO
@export var scale_with_ui: bool = true

# Data binding configuration
@export var data_sources: Array[String] = []  # Data types this element is interested in
@export var update_frequency: float = 60.0  # Updates per second
@export var use_dirty_tracking: bool = true  # Only update when data changes

# Performance and optimization
@export var frame_time_budget_ms: float = 0.1  # Maximum time per frame
@export var can_skip_frames: bool = true  # Can skip updates when over budget
@export var lod_distance_threshold: float = -1.0  # LOD threshold (-1 = always visible)

# Internal state
var hud_manager: HUDManager
var cached_data: Dictionary = {}
var needs_update: bool = true
var last_update_time: float = 0.0
var last_data_hash: int = 0
var performance_samples: Array[float] = []
var frame_skip_counter: int = 0

# Visibility and interaction state
var base_modulate: Color = Color.WHITE
var is_flashing: bool = false
var flash_timer: float = 0.0
var flash_interval: float = 0.5

func _init():
	name = "HUDElement"
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Most HUD elements don't need mouse input
	set_process(false)  # Managed by HUD manager

func _ready() -> void:
	# Ensure element has valid ID
	if element_id.is_empty():
		element_id = _generate_element_id()
	
	# Set initial visibility
	_update_visibility()
	
	# Store base modulate for flash effects
	base_modulate = modulate

## Generate unique element ID if none provided
func _generate_element_id() -> String:
	return "%s_%d" % [get_script().get_global_name(), get_instance_id()]

## Called by HUD manager when element is registered
func set_hud_manager(manager: HUDManager) -> void:
	hud_manager = manager
	
	# Register for data updates
	if hud_manager.data_provider:
		for data_type in data_sources:
			_subscribe_to_data(data_type)

## Subscribe to data updates
func _subscribe_to_data(data_type: String) -> void:
	if hud_manager and hud_manager.data_provider:
		# This would be implemented when data provider is ready
		pass

## Get container type for this element
func get_container_type() -> String:
	return container_type

## Check if element is interested in data type
func is_interested_in_data(data_type: String) -> bool:
	return data_sources.has(data_type)

## Check if element can update this frame
func can_update_this_frame() -> bool:
	if not is_active:
		return false
	
	# Check update frequency
	var current_time = Time.get_ticks_usec() / 1000000.0
	var time_since_update = current_time - last_update_time
	var target_interval = 1.0 / update_frequency
	
	if time_since_update < target_interval:
		return false
	
	# Check frame skipping
	if can_skip_frames and frame_skip_counter > 0:
		frame_skip_counter -= 1
		return false
	
	return true

## Virtual method called when element is ready (override in subclasses)
func _element_ready() -> void:
	pass

## Virtual method called every frame (override in subclasses)
func _element_update(delta: float) -> void:
	last_update_time = Time.get_ticks_usec() / 1000000.0
	
	# Update flash effect if active
	if is_flashing:
		_update_flash_effect(delta)
	
	# Mark as updated
	needs_update = false

## Virtual method called when data changes (override in subclasses)
func _element_data_changed(data_type: String, data: Dictionary) -> void:
	# Cache the data
	cached_data[data_type] = data
	
	# Check if data actually changed using hash
	if use_dirty_tracking:
		var new_hash = hash(data)
		if new_hash == last_data_hash:
			return
		last_data_hash = new_hash
	
	# Mark for update
	needs_update = true

## Handle screen size changes
func _on_screen_size_changed(new_size: Vector2) -> void:
	# Update positioning based on anchor mode
	_update_positioning(new_size)

## Update element positioning based on screen size and anchor
func _update_positioning(screen_size: Vector2) -> void:
	if not hud_manager or not hud_manager.layout_manager:
		return
	
	var new_position = hud_manager.layout_manager.calculate_element_position(
		anchor_mode, position_offset, screen_size
	)
	
	position = new_position
	
	# Apply UI scaling if enabled
	if scale_with_ui and hud_manager:
		scale = Vector2.ONE * hud_manager.ui_scale

## Element activation and deactivation

## Activate element
func activate() -> void:
	if is_active:
		return
	
	is_active = true
	_update_visibility()
	element_activated.emit()

## Deactivate element
func deactivate() -> void:
	if not is_active:
		return
	
	is_active = false
	_update_visibility()
	element_deactivated.emit()

## Update visibility based on state
func _update_visibility() -> void:
	if auto_hide_when_inactive:
		visible = is_active
	
	# Additional visibility logic can be added here

## Flash effect system

## Start flash effect
func start_flash(duration: float = -1.0, interval: float = 0.5) -> void:
	is_flashing = true
	flash_timer = 0.0
	flash_interval = interval
	
	if duration > 0:
		get_tree().create_timer(duration).timeout.connect(stop_flash)

## Stop flash effect
func stop_flash() -> void:
	is_flashing = false
	modulate = base_modulate

## Update flash effect
func _update_flash_effect(delta: float) -> void:
	flash_timer += delta
	
	if flash_timer >= flash_interval:
		flash_timer = 0.0
		
		# Toggle between base and bright modulate
		if modulate == base_modulate:
			modulate = Color(base_modulate.r * 1.5, base_modulate.g * 1.5, base_modulate.b * 1.5, base_modulate.a)
		else:
			modulate = base_modulate

## Performance tracking and optimization

## Record performance sample
func record_performance_sample(frame_time_ms: float) -> void:
	performance_samples.append(frame_time_ms)
	
	# Keep only recent samples
	if performance_samples.size() > 60:  # Keep 1 second at 60 FPS
		performance_samples.pop_front()
	
	# Check performance budget
	if frame_time_ms > frame_time_budget_ms:
		_handle_performance_warning(frame_time_ms)

## Handle performance warnings
func _handle_performance_warning(frame_time_ms: float) -> void:
	performance_warning.emit(frame_time_ms)
	
	# Implement frame skipping if enabled
	if can_skip_frames:
		var severity = frame_time_ms / frame_time_budget_ms
		frame_skip_counter = int(severity - 1)  # Skip frames based on severity

## Get average performance
func get_average_performance() -> float:
	if performance_samples.is_empty():
		return 0.0
	
	var sum = 0.0
	for sample in performance_samples:
		sum += sample
	
	return sum / performance_samples.size()

## Data access helpers

## Get cached data for type
func get_cached_data(data_type: String, default_value = null):
	return cached_data.get(data_type, default_value)

## Check if cached data exists
func has_cached_data(data_type: String) -> bool:
	return cached_data.has(data_type)

## Force data refresh
func refresh_data() -> void:
	needs_update = true
	last_data_hash = 0  # Force dirty tracking to update

## Configuration and customization

## Set element priority
func set_element_priority(priority: int) -> void:
	element_priority = priority
	
	# Notify HUD manager to rebuild update order
	if hud_manager:
		hud_manager._rebuild_update_order()

## Set update frequency
func set_update_frequency(frequency: float) -> void:
	update_frequency = max(1.0, frequency)  # Minimum 1 FPS

## Set frame time budget
func set_frame_time_budget(budget_ms: float) -> void:
	frame_time_budget_ms = max(0.01, budget_ms)  # Minimum 0.01ms

## Element information and debugging

## Get element status
func get_element_status() -> Dictionary:
	return {
		"element_id": element_id,
		"is_active": is_active,
		"container_type": container_type,
		"priority": element_priority,
		"update_frequency": update_frequency,
		"frame_budget_ms": frame_time_budget_ms,
		"needs_update": needs_update,
		"data_sources": data_sources,
		"cached_data_types": cached_data.keys(),
		"average_performance_ms": get_average_performance(),
		"position": position,
		"size": size,
		"visible": visible
	}

## Get debug information
func get_debug_info() -> String:
	var status = get_element_status()
	var debug_text = "Element: %s\n" % element_id
	debug_text += "Active: %s | Priority: %d\n" % [status.is_active, status.priority]
	debug_text += "Update: %.1f Hz | Budget: %.2f ms\n" % [status.update_frequency, status.frame_budget_ms]
	debug_text += "Performance: %.2f ms avg\n" % status.average_performance_ms
	debug_text += "Position: %s | Size: %s\n" % [status.position, status.size]
	debug_text += "Data Sources: %s" % status.data_sources
	
	return debug_text

## Cleanup and resource management

## Cleanup element resources
func cleanup() -> void:
	# Clear cached data
	cached_data.clear()
	performance_samples.clear()
	
	# Stop any active effects
	stop_flash()
	
	# Disconnect from HUD manager
	if hud_manager:
		hud_manager = null

func _exit_tree() -> void:
	cleanup()

## Static utility methods

## Create element with basic configuration
static func create_element(id: String, priority: int = 0, container: String = "core") -> HUDElementBase:
	var element = HUDElementBase.new()
	element.element_id = id
	element.element_priority = priority
	element.container_type = container
	return element

## Validate element configuration
static func validate_element_config(config: Dictionary) -> bool:
	# Check required fields
	if not config.has("element_id") or config.element_id.is_empty():
		return false
	
	# Validate priority
	if config.has("priority") and (config.priority < 0 or config.priority > 1000):
		return false
	
	# Validate container type
	var valid_containers = ["core", "targeting", "status", "radar", "communication", "navigation", "debug"]
	if config.has("container_type") and not config.container_type in valid_containers:
		return false
	
	return true