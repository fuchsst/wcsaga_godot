class_name HUDManager
extends Node

## EPIC-012 HUD-001: HUD Manager and Element Framework
## Central HUD coordination and management system for WCS-Godot conversion
## Provides comprehensive HUD element lifecycle, data provider integration, and performance optimization

signal hud_element_registered(element_id: String, element: HUDElementBase)
signal hud_element_unregistered(element_id: String)
signal hud_visibility_changed(enabled: bool)
signal hud_configuration_changed(config: Dictionary)
signal hud_performance_warning(element_id: String, frame_time_ms: float)

# Singleton instance for global access
static var instance: HUDManager

# HUD element management
var registered_elements: Dictionary = {}  # element_id -> HUDElementBase
var active_elements: Array[HUDElementBase] = []
var element_update_order: Array[String] = []
var element_containers: Dictionary = {}  # container_type -> Control

# Core systems
var data_provider: HUDDataProvider
var performance_monitor: HUDPerformanceMonitor
var layout_manager: HUDLayoutManager

# HUD state management
var hud_enabled: bool = true
var debug_mode: bool = false
var initialization_complete: bool = false

# Performance configuration
@export var target_fps: float = 60.0
@export var max_frame_time_budget_ms: float = 2.0  # Total HUD budget per frame
@export var element_frame_budget_ms: float = 0.1   # Per-element budget

# Screen and layout management
var screen_size: Vector2
var safe_area: Rect2
var ui_scale: float = 1.0

# HUD configuration
var hud_config: HUDConfig
var legacy_hud_manager: Node  # Reference to existing HUD manager if present

func _init():
	if instance == null:
		instance = self
	name = "HUDManager"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _ready() -> void:
	_initialize_hud_system()

## Initialize the HUD system with all components
func _initialize_hud_system() -> void:
	print("HUDManager: Initializing comprehensive HUD framework...")
	
	# Initialize core systems
	_initialize_core_systems()
	
	# Setup screen and layout management
	_initialize_screen_management()
	
	# Initialize element containers
	_initialize_element_containers()
	
	# Connect to existing HUD system if present
	_integrate_with_legacy_hud()
	
	# Setup signal connections
	_setup_signal_connections()
	
	initialization_complete = true
	print("HUDManager: HUD framework initialization complete")

## Initialize core HUD systems
func _initialize_core_systems() -> void:
	# Create data provider for real-time information
	data_provider = HUDDataProvider.new()
	add_child(data_provider)
	
	# Create performance monitor
	performance_monitor = HUDPerformanceMonitor.new()
	add_child(performance_monitor)
	performance_monitor.setup_monitoring(target_fps, max_frame_time_budget_ms)
	
	# Create layout manager
	layout_manager = HUDLayoutManager.new()
	add_child(layout_manager)
	
	print("HUDManager: Core systems initialized")

## Initialize screen management and safe areas
func _initialize_screen_management() -> void:
	screen_size = get_viewport().get_visible_rect().size
	_update_safe_area()
	
	# Connect to viewport size changes
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	print("HUDManager: Screen management initialized - Size: %s" % screen_size)

## Update safe area calculations to avoid 3D viewport obstruction
func _update_safe_area() -> void:
	# Calculate safe area that doesn't obstruct 3D gameplay
	var margin_x: float = screen_size.x * 0.05  # 5% margin on sides
	var margin_y: float = screen_size.y * 0.05  # 5% margin top/bottom
	
	safe_area = Rect2(
		Vector2(margin_x, margin_y),
		Vector2(screen_size.x - 2 * margin_x, screen_size.y - 2 * margin_y)
	)
	
	# Update layout manager with new safe area
	if layout_manager:
		layout_manager.set_safe_area(safe_area)

## Initialize element containers for organized HUD layout
func _initialize_element_containers() -> void:
	# Create main HUD layer as CanvasLayer for optimal rendering
	var hud_canvas_layer = CanvasLayer.new()
	hud_canvas_layer.name = "HUDCanvasLayer"
	hud_canvas_layer.layer = 100  # Ensure HUD renders on top
	get_tree().root.add_child(hud_canvas_layer)
	
	# Create container structure
	var containers_config = {
		"core": {"position": Vector2.ZERO, "anchor": "full"},
		"targeting": {"position": Vector2(0.7, 0.3), "anchor": "center_right"},
		"status": {"position": Vector2(0.0, 0.8), "anchor": "bottom_left"},
		"radar": {"position": Vector2(0.9, 0.1), "anchor": "top_right"},
		"communication": {"position": Vector2(0.0, 0.0), "anchor": "top_left"},
		"navigation": {"position": Vector2(0.5, 0.95), "anchor": "bottom_center"},
		"debug": {"position": Vector2.ZERO, "anchor": "full"}
	}
	
	for container_name in containers_config:
		var container = Control.new()
		container.name = "%sContainer" % container_name.capitalize()
		container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		hud_canvas_layer.add_child(container)
		element_containers[container_name] = container
	
	# Hide debug container initially
	element_containers["debug"].visible = debug_mode
	
	print("HUDManager: Element containers initialized")

## Integrate with existing legacy HUD system
func _integrate_with_legacy_hud() -> void:
	# Look for existing HUD manager in the scene tree
	var existing_hud = _find_legacy_hud_manager()
	if existing_hud:
		legacy_hud_manager = existing_hud
		print("HUDManager: Integrated with legacy HUD system")
	else:
		print("HUDManager: No legacy HUD system found, operating independently")

## Find existing HUD manager in scene tree
func _find_legacy_hud_manager() -> Node:
	# Search for existing HUD components
	var root = get_tree().root
	return _recursive_find_node(root, "HUDConfig")

func _recursive_find_node(node: Node, target_name: String) -> Node:
	if node.name == target_name or node.get_script() and node.get_script().get_global_name() == target_name:
		return node
	
	for child in node.get_children():
		var result = _recursive_find_node(child, target_name)
		if result:
			return result
	
	return null

## Setup signal connections for system integration
func _setup_signal_connections() -> void:
	# Connect performance monitoring signals
	performance_monitor.performance_warning.connect(_on_performance_warning)
	performance_monitor.frame_budget_exceeded.connect(_on_frame_budget_exceeded)
	
	# Connect data provider signals
	data_provider.data_updated.connect(_on_hud_data_updated)
	data_provider.data_source_error.connect(_on_data_source_error)

## Main HUD processing loop
func _process(delta: float) -> void:
	if not initialization_complete or not hud_enabled:
		return
	
	# Start performance frame measurement
	performance_monitor.start_frame_measurement()
	
	# Update all active HUD elements
	_update_hud_elements(delta)
	
	# Update performance monitoring
	performance_monitor.end_frame_measurement()
	
	# Handle debug mode updates
	if debug_mode:
		_update_debug_display()

## Update all active HUD elements with performance monitoring
func _update_hud_elements(delta: float) -> void:
	var elements_to_update = _get_update_order()
	
	for element_id in elements_to_update:
		var element = registered_elements.get(element_id)
		if not element or not element.is_active:
			continue
		
		# Check element frame budget
		if not element.can_update_this_frame():
			continue
		
		# Measure element update performance
		var start_time = Time.get_ticks_usec()
		
		# Update element
		element._element_update(delta)
		
		# Record performance
		var end_time = Time.get_ticks_usec()
		var frame_time_ms = (end_time - start_time) / 1000.0
		
		performance_monitor.record_element_performance(element_id, frame_time_ms)
		
		# Check element performance budget
		if frame_time_ms > element_frame_budget_ms:
			hud_performance_warning.emit(element_id, frame_time_ms)

## Get element update order based on priority
func _get_update_order() -> Array[String]:
	if element_update_order.is_empty():
		_rebuild_update_order()
	
	return element_update_order

## Rebuild element update order based on priorities
func _rebuild_update_order() -> void:
	element_update_order.clear()
	
	# Create array of [element_id, priority] pairs
	var priority_pairs: Array = []
	for element_id in registered_elements:
		var element = registered_elements[element_id]
		priority_pairs.append([element_id, element.element_priority])
	
	# Sort by priority (higher priority first)
	priority_pairs.sort_custom(func(a, b): return a[1] > b[1])
	
	# Extract element IDs in priority order
	for pair in priority_pairs:
		element_update_order.append(pair[0])

## Register a new HUD element
func register_element(element: HUDElementBase) -> bool:
	if not element or element.element_id.is_empty():
		push_error("HUDManager: Cannot register element - invalid element or missing ID")
		return false
	
	if registered_elements.has(element.element_id):
		push_warning("HUDManager: Element already registered: " + element.element_id)
		return false
	
	# Register element
	registered_elements[element.element_id] = element
	active_elements.append(element)
	
	# Add to appropriate container
	var container = _get_element_container(element)
	if container:
		container.add_child(element)
	
	# Setup element
	element.set_hud_manager(self)
	element._element_ready()
	
	# Rebuild update order
	_rebuild_update_order()
	
	hud_element_registered.emit(element.element_id, element)
	print("HUDManager: Registered element: " + element.element_id)
	
	return true

## Unregister a HUD element
func unregister_element(element_id: String) -> bool:
	if not registered_elements.has(element_id):
		push_warning("HUDManager: Element not found for unregistration: " + element_id)
		return false
	
	var element = registered_elements[element_id]
	
	# Remove from collections
	registered_elements.erase(element_id)
	active_elements.erase(element)
	element_update_order.erase(element_id)
	
	# Remove from scene
	if element.get_parent():
		element.get_parent().remove_child(element)
	
	hud_element_unregistered.emit(element_id)
	print("HUDManager: Unregistered element: " + element_id)
	
	return true

## Get appropriate container for element
func _get_element_container(element: HUDElementBase) -> Control:
	var container_type = element.get_container_type()
	return element_containers.get(container_type, element_containers["core"])

## Get HUD element by ID
func get_element(element_id: String) -> HUDElementBase:
	return registered_elements.get(element_id)

## Get all registered elements
func get_all_elements() -> Array[HUDElementBase]:
	return active_elements.duplicate()

## Set HUD enabled state
func set_hud_enabled(enabled: bool) -> void:
	if hud_enabled == enabled:
		return
	
	hud_enabled = enabled
	
	# Update visibility of all containers
	for container in element_containers.values():
		if container.name != "DebugContainer":  # Keep debug always controlled separately
			container.visible = enabled
	
	hud_visibility_changed.emit(enabled)
	print("HUDManager: HUD enabled: %s" % enabled)

## Set debug mode
func set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled
	
	if element_containers.has("debug"):
		element_containers["debug"].visible = enabled
	
	# Update performance monitoring detail level
	if performance_monitor:
		performance_monitor.set_detailed_monitoring(enabled)
	
	print("HUDManager: Debug mode: %s" % enabled)

## Get comprehensive HUD status
func get_hud_status() -> Dictionary:
	return {
		"enabled": hud_enabled,
		"debug_mode": debug_mode,
		"registered_elements": registered_elements.size(),
		"active_elements": active_elements.size(),
		"screen_size": screen_size,
		"safe_area": safe_area,
		"ui_scale": ui_scale,
		"performance": performance_monitor.get_performance_summary() if performance_monitor else {},
		"initialization_complete": initialization_complete
	}

## Get performance statistics
func get_performance_statistics() -> Dictionary:
	if not performance_monitor:
		return {}
	
	return performance_monitor.get_detailed_statistics()

## Update debug display
func _update_debug_display() -> void:
	if not debug_mode or not element_containers.has("debug"):
		return
	
	# This would update debug overlay with HUD information
	# Implementation would include performance metrics, element states, etc.
	pass

## Handle viewport size changes
func _on_viewport_size_changed() -> void:
	screen_size = get_viewport().get_visible_rect().size
	_update_safe_area()
	
	# Notify all elements of screen size change
	for element in active_elements:
		element._on_screen_size_changed(screen_size)
	
	print("HUDManager: Screen size changed to: %s" % screen_size)

## Handle HUD data updates
func _on_hud_data_updated(data_type: String, data: Dictionary) -> void:
	# Propagate data updates to relevant elements
	for element in active_elements:
		if element.is_interested_in_data(data_type):
			element._element_data_changed(data_type, data)

## Handle data source errors
func _on_data_source_error(source: String, error: String) -> void:
	push_warning("HUDManager: Data source error - %s: %s" % [source, error])

## Handle performance warnings
func _on_performance_warning(metric: String, value: float, threshold: float) -> void:
	push_warning("HUDManager: Performance warning - %s: %.2f > %.2f" % [metric, value, threshold])

## Handle frame budget exceeded
func _on_frame_budget_exceeded(total_time_ms: float, budget_ms: float) -> void:
	push_warning("HUDManager: Frame budget exceeded - %.2f ms > %.2f ms" % [total_time_ms, budget_ms])

## Public API for external systems

## Get singleton instance
static func get_instance() -> HUDManager:
	return instance

## Check if HUD system is ready
static func is_ready() -> bool:
	return instance != null and instance.initialization_complete

## Get data provider for external access
func get_data_provider() -> HUDDataProvider:
	return data_provider

## Get performance monitor for external access
func get_performance_monitor() -> HUDPerformanceMonitor:
	return performance_monitor

## Get layout manager for external access
func get_layout_manager() -> HUDLayoutManager:
	return layout_manager

## Configuration management

## Load HUD configuration
func load_configuration(config_path: String) -> bool:
	# Implementation would load HUD configuration from file
	# For now, use default configuration
	_apply_default_configuration()
	return true

## Apply default HUD configuration
func _apply_default_configuration() -> void:
	# Apply default settings
	hud_enabled = true
	debug_mode = false
	ui_scale = 1.0
	
	hud_configuration_changed.emit(get_hud_status())

## Save current HUD configuration
func save_configuration(config_path: String) -> bool:
	# Implementation would save current HUD configuration
	return true

## Cleanup and shutdown
func _exit_tree() -> void:
	print("HUDManager: Shutting down HUD framework")
	
	# Cleanup all elements
	for element in active_elements:
		if element and is_instance_valid(element):
			element.queue_free()
	
	# Clear collections
	registered_elements.clear()
	active_elements.clear()
	element_update_order.clear()
	
	# Reset singleton
	if instance == self:
		instance = null