class_name ObjectDebugger
extends Control

## Comprehensive object system debugging and visualization tools.
## Provides visual debugging for object states, physics forces, collision shapes,
## spatial partitioning, and real-time system monitoring for development efficiency.

# EPIC-002 Asset Core Integration
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

signal debug_mode_changed(enabled: bool)
signal object_selected(object: BaseSpaceObject)
signal validation_results_updated(results: Dictionary)
signal error_detected(error_type: String, object: BaseSpaceObject, details: Dictionary)

# Debug configuration
@export var debug_enabled: bool = false
@export var show_object_info: bool = true
@export var show_physics_vectors: bool = true
@export var show_collision_shapes: bool = true
@export var show_spatial_partitioning: bool = false
@export var show_performance_metrics: bool = true
@export var update_frequency: float = 0.1  # Update frequency in seconds

# Debug colors
@export var object_outline_color: Color = Color.CYAN
@export var physics_force_color: Color = Color.RED
@export var velocity_color: Color = Color.BLUE
@export var collision_shape_color: Color = Color.YELLOW
@export var spatial_grid_color: Color = Color.GREEN
@export var error_highlight_color: Color = Color.MAGENTA

# Debug UI elements
var debug_panel: Panel
var object_list: ItemList
var properties_panel: VBoxContainer
var metrics_display: RichTextLabel
var error_log: RichTextLabel

# Debug tracking
var registered_objects: Array[BaseSpaceObject] = []
var selected_object: BaseSpaceObject
var debug_visualizations: Dictionary = {}  # object -> Array[Node3D]
var error_count: int = 0
var validation_history: Array[Dictionary] = []

# Debug update timer
var debug_update_timer: float = 0.0

# System references
var object_manager: ObjectManager
var physics_manager: PhysicsManager
var collision_detector: CollisionDetector
var performance_monitor: PerformanceMonitor

func _ready() -> void:
	_setup_debug_ui()
	_find_system_references()
	_connect_system_signals()
	
	set_process(debug_enabled)
	print("ObjectDebugger: Debug tools initialized")

func _process(delta: float) -> void:
	"""Update debug visualization each frame."""
	if not debug_enabled:
		return
	
	debug_update_timer += delta
	if debug_update_timer >= update_frequency:
		_update_debug_display()
		_update_object_visualizations()
		_validate_object_states()
		debug_update_timer = 0.0

## Public API Functions (AC1-AC6)

func enable_debug_mode(enabled: bool) -> void:
	"""Enable or disable comprehensive object debugging.
	
	Args:
		enabled: true to enable debugging, false to disable
	"""
	if debug_enabled != enabled:
		debug_enabled = enabled
		set_process(enabled)
		
		if enabled:
			_refresh_object_list()
			_show_debug_panel()
		else:
			_hide_debug_panel()
			_clear_all_visualizations()
		
		debug_mode_changed.emit(enabled)
		print("ObjectDebugger: Debug mode %s" % ("enabled" if enabled else "disabled"))

func register_object_for_debugging(object: BaseSpaceObject) -> void:
	"""Register an object for debugging and validation.
	
	Args:
		object: BaseSpaceObject to track for debugging
	"""
	if not is_instance_valid(object):
		push_error("ObjectDebugger: Cannot register invalid object")
		return
	
	if object in registered_objects:
		push_warning("ObjectDebugger: Object already registered for debugging")
		return
	
	registered_objects.append(object)
	
	# Create debug visualizations if enabled
	if debug_enabled:
		_create_object_visualizations(object)
		_refresh_object_list()
	
	print("ObjectDebugger: Registered object for debugging: %s" % object.name)

func unregister_object_from_debugging(object: BaseSpaceObject) -> void:
	"""Remove an object from debugging and validation.
	
	Args:
		object: BaseSpaceObject to stop tracking
	"""
	if object in registered_objects:
		registered_objects.erase(object)
		_cleanup_object_visualizations(object)
		
		if selected_object == object:
			selected_object = null
			_clear_properties_panel()
		
		_refresh_object_list()
	
	print("ObjectDebugger: Unregistered object from debugging: %s" % object.name)

func select_object_for_inspection(object: BaseSpaceObject) -> void:
	"""Select an object for detailed inspection and visualization.
	
	Args:
		object: BaseSpaceObject to inspect in detail
	"""
	if not is_instance_valid(object):
		push_error("ObjectDebugger: Cannot select invalid object")
		return
	
	# Clear previous selection highlight
	if selected_object:
		_clear_object_highlight(selected_object)
	
	selected_object = object
	
	# Add highlight to new selection
	_highlight_selected_object(object)
	
	# Update properties panel
	_update_properties_panel(object)
	
	object_selected.emit(object)
	print("ObjectDebugger: Selected object for inspection: %s" % object.name)

func validate_all_objects() -> Dictionary:
	"""Perform comprehensive validation of all registered objects.
	
	Returns:
		Dictionary containing validation results and error reports
	"""
	var validation_results: Dictionary = {
		"timestamp": Time.get_time_dict_from_system(),
		"total_objects": registered_objects.size(),
		"errors": [],
		"warnings": [],
		"performance_issues": [],
		"state_corruption": [],
		"summary": {}
	}
	
	for object in registered_objects:
		if not is_instance_valid(object):
			_add_validation_error(validation_results, "invalid_object", null, 
				{"message": "Object reference invalid"})
			continue
		
		_validate_object_state(object, validation_results)
		_validate_object_physics(object, validation_results)
		_validate_object_collision(object, validation_results)
		_validate_object_performance(object, validation_results)
	
	# Generate summary
	validation_results.summary = {
		"error_count": validation_results.errors.size(),
		"warning_count": validation_results.warnings.size(),
		"performance_issue_count": validation_results.performance_issues.size(),
		"state_corruption_count": validation_results.state_corruption.size()
	}
	
	# Store in history
	validation_history.append(validation_results)
	if validation_history.size() > 50:  # Keep last 50 validations
		validation_history.pop_front()
	
	validation_results_updated.emit(validation_results)
	print("ObjectDebugger: Validation complete - %d errors, %d warnings" % 
		[validation_results.summary.error_count, validation_results.summary.warning_count])
	
	return validation_results

func get_debug_performance_statistics() -> Dictionary:
	"""Get performance statistics for debug system operations.
	
	Returns:
		Dictionary containing debug system performance metrics
	"""
	return {
		"registered_objects": registered_objects.size(),
		"active_visualizations": debug_visualizations.size(),
		"error_count": error_count,
		"validation_history_count": validation_history.size(),
		"debug_enabled": debug_enabled,
		"selected_object": selected_object.name if selected_object else "none",
		"update_frequency": update_frequency,
		"last_validation": validation_history[-1] if validation_history.size() > 0 else null
	}

func force_object_validation(object: BaseSpaceObject) -> Dictionary:
	"""Force immediate validation of a specific object.
	
	Args:
		object: BaseSpaceObject to validate
		
	Returns:
		Dictionary containing validation results for the object
	"""
	if not is_instance_valid(object):
		return {"error": "Invalid object provided"}
	
	var validation_results: Dictionary = {
		"object_name": object.name,
		"timestamp": Time.get_time_dict_from_system(),
		"errors": [],
		"warnings": [],
		"performance_issues": [],
		"state_issues": []
	}
	
	_validate_object_state(object, validation_results)
	_validate_object_physics(object, validation_results)
	_validate_object_collision(object, validation_results)
	_validate_object_performance(object, validation_results)
	
	print("ObjectDebugger: Forced validation of %s - %d issues found" % 
		[object.name, validation_results.errors.size() + validation_results.warnings.size()])
	
	return validation_results

# Private implementation methods

func _setup_debug_ui() -> void:
	"""Create debug overlay UI elements."""
	# Main debug panel
	debug_panel = Panel.new()
	debug_panel.size = Vector2(800, 600)
	debug_panel.position = Vector2(50, 50)
	debug_panel.visible = debug_enabled
	add_child(debug_panel)
	
	# Main horizontal container
	var main_hbox: HBoxContainer = HBoxContainer.new()
	debug_panel.add_child(main_hbox)
	
	# Left panel (object list and controls)
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(250, 580)
	main_hbox.add_child(left_panel)
	
	# Title
	var title_label: Label = Label.new()
	title_label.text = "Object System Debugger"
	title_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(title_label)
	
	# Object list
	var list_label: Label = Label.new()
	list_label.text = "Registered Objects:"
	left_panel.add_child(list_label)
	
	object_list = ItemList.new()
	object_list.custom_minimum_size = Vector2(230, 200)
	object_list.item_selected.connect(_on_object_list_item_selected)
	left_panel.add_child(object_list)
	
	# Control buttons
	var button_container: VBoxContainer = VBoxContainer.new()
	left_panel.add_child(button_container)
	
	var validate_button: Button = Button.new()
	validate_button.text = "Validate All Objects"
	validate_button.pressed.connect(_on_validate_all_pressed)
	button_container.add_child(validate_button)
	
	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh List"
	refresh_button.pressed.connect(_on_refresh_list_pressed)
	button_container.add_child(refresh_button)
	
	var clear_errors_button: Button = Button.new()
	clear_errors_button.text = "Clear Error Log"
	clear_errors_button.pressed.connect(_on_clear_errors_pressed)
	button_container.add_child(clear_errors_button)
	
	# Right panel (properties and metrics)
	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(520, 580)
	main_hbox.add_child(right_panel)
	
	# Properties panel
	var props_label: Label = Label.new()
	props_label.text = "Object Properties:"
	right_panel.add_child(props_label)
	
	var props_scroll: ScrollContainer = ScrollContainer.new()
	props_scroll.custom_minimum_size = Vector2(500, 200)
	right_panel.add_child(props_scroll)
	
	properties_panel = VBoxContainer.new()
	props_scroll.add_child(properties_panel)
	
	# Metrics display
	var metrics_label: Label = Label.new()
	metrics_label.text = "Performance Metrics:"
	right_panel.add_child(metrics_label)
	
	metrics_display = RichTextLabel.new()
	metrics_display.custom_minimum_size = Vector2(500, 150)
	metrics_display.fit_content = true
	right_panel.add_child(metrics_display)
	
	# Error log
	var error_label: Label = Label.new()
	error_label.text = "Error Log:"
	right_panel.add_child(error_label)
	
	error_log = RichTextLabel.new()
	error_log.custom_minimum_size = Vector2(500, 150)
	error_log.fit_content = true
	right_panel.add_child(error_log)

func _find_system_references() -> void:
	"""Find references to other system components."""
	object_manager = get_node_or_null("/root/ObjectManager")
	physics_manager = get_node_or_null("/root/PhysicsManager")
	collision_detector = get_node_or_null("/root/CollisionDetector")
	performance_monitor = get_node_or_null("/root/PerformanceMonitor")
	
	if not object_manager:
		push_warning("ObjectDebugger: ObjectManager not found")
	if not physics_manager:
		push_warning("ObjectDebugger: PhysicsManager not found")
	if not collision_detector:
		push_warning("ObjectDebugger: CollisionDetector not found")
	if not performance_monitor:
		push_warning("ObjectDebugger: PerformanceMonitor not found")

func _connect_system_signals() -> void:
	"""Connect to system signals for automatic debugging."""
	if object_manager:
		object_manager.object_created.connect(_on_object_created)
		object_manager.object_destroyed.connect(_on_object_destroyed)
	
	if physics_manager:
		physics_manager.physics_step_completed.connect(_on_physics_step_completed)
	
	if collision_detector:
		collision_detector.collision_pair_detected.connect(_on_collision_detected)

func _update_debug_display() -> void:
	"""Update the debug overlay with current information."""
	if not debug_enabled or not debug_panel.visible:
		return
	
	_update_metrics_display()
	
	if selected_object and is_instance_valid(selected_object):
		_update_properties_panel(selected_object)

func _update_metrics_display() -> void:
	"""Update performance metrics in the debug panel."""
	if not metrics_display:
		return
	
	var stats: Dictionary = get_debug_performance_statistics()
	var perf_stats: Dictionary = {}
	
	if performance_monitor:
		perf_stats = performance_monitor.get_current_performance_metrics()
	
	var metrics_text: String = "[b]Object System Debug Metrics:[/b]\n"
	metrics_text += "• Registered Objects: %d\n" % stats["registered_objects"]
	metrics_text += "• Active Visualizations: %d\n" % stats["active_visualizations"]
	metrics_text += "• Error Count: %d\n" % stats["error_count"]
	metrics_text += "• Selected Object: %s\n" % stats["selected_object"]
	
	if perf_stats.size() > 0:
		metrics_text += "\n[b]Performance Metrics:[/b]\n"
		metrics_text += "• FPS: %.1f\n" % perf_stats.get("fps", 0.0)
		metrics_text += "• Frame Time: %.2fms\n" % perf_stats.get("frame_time_ms", 0.0)
		metrics_text += "• Physics Time: %.2fms\n" % perf_stats.get("physics_time_ms", 0.0)
		metrics_text += "• Object Count: %d\n" % perf_stats.get("object_count", 0)
	
	metrics_display.text = metrics_text

func _update_object_visualizations() -> void:
	"""Update visual representations of all registered objects."""
	if not show_collision_shapes and not show_physics_vectors:
		return
	
	for object in registered_objects:
		if is_instance_valid(object):
			_update_object_visualization(object)

func _validate_object_states() -> void:
	"""Perform quick validation of object states."""
	for object in registered_objects:
		if not is_instance_valid(object):
			continue
		
		# Quick validation checks
		_check_object_for_errors(object)

func _create_object_visualizations(object: BaseSpaceObject) -> void:
	"""Create debug visualizations for an object."""
	if not debug_enabled:
		return
	
	var visualizations: Array[Node3D] = []
	
	# Create collision shape visualization
	if show_collision_shapes:
		var collision_vis: Node3D = _create_collision_visualization(object)
		if collision_vis:
			visualizations.append(collision_vis)
			add_child(collision_vis)
	
	# Create physics vector visualization
	if show_physics_vectors:
		var physics_vis: Node3D = _create_physics_visualization(object)
		if physics_vis:
			visualizations.append(physics_vis)
			add_child(physics_vis)
	
	debug_visualizations[object] = visualizations

func _create_collision_visualization(object: BaseSpaceObject) -> Node3D:
	"""Create collision shape visualization for an object."""
	# Implementation would create wireframe visualization of collision shapes
	# This is a placeholder that would need specific 3D line rendering
	var visualization: Node3D = Node3D.new()
	visualization.name = "CollisionVisualization_%s" % object.name
	visualization.global_position = object.global_position
	return visualization

func _create_physics_visualization(object: BaseSpaceObject) -> Node3D:
	"""Create physics vector visualization for an object."""
	# Implementation would create arrows for force vectors and velocity
	# This is a placeholder that would need specific 3D line rendering
	var visualization: Node3D = Node3D.new()
	visualization.name = "PhysicsVisualization_%s" % object.name
	visualization.global_position = object.global_position
	return visualization

func _update_object_visualization(object: BaseSpaceObject) -> void:
	"""Update visualization for a specific object."""
	if object not in debug_visualizations:
		return
	
	var visualizations: Array[Node3D] = debug_visualizations[object]
	
	for vis in visualizations:
		if is_instance_valid(vis):
			vis.global_position = object.global_position
			# Update visualization based on object state
			_update_visualization_appearance(vis, object)

func _update_visualization_appearance(visualization: Node3D, object: BaseSpaceObject) -> void:
	"""Update the appearance of a debug visualization."""
	# Implementation would update colors, visibility, etc. based on object state
	# This is a placeholder for actual visualization updates
	pass

func _cleanup_object_visualizations(object: BaseSpaceObject) -> void:
	"""Clean up debug visualizations for an object."""
	if object not in debug_visualizations:
		return
	
	var visualizations: Array[Node3D] = debug_visualizations[object]
	
	for vis in visualizations:
		if is_instance_valid(vis):
			vis.queue_free()
	
	debug_visualizations.erase(object)

func _clear_all_visualizations() -> void:
	"""Clear all debug visualizations."""
	for object in debug_visualizations.keys():
		_cleanup_object_visualizations(object)

func _highlight_selected_object(object: BaseSpaceObject) -> void:
	"""Add highlight effect to selected object."""
	# Implementation would add visual highlight
	print("ObjectDebugger: Highlighting object: %s" % object.name)

func _clear_object_highlight(object: BaseSpaceObject) -> void:
	"""Remove highlight effect from object."""
	# Implementation would remove visual highlight
	print("ObjectDebugger: Clearing highlight from object: %s" % object.name)

func _validate_object_state(object: BaseSpaceObject, results: Dictionary) -> void:
	"""Validate object state consistency."""
	# Check for null references, invalid states, etc.
	if not object.has_method("get_object_type"):
		_add_validation_error(results, "missing_method", object, 
			{"method": "get_object_type", "message": "Object missing required method"})
	
	# Check object ID validity
	if object.get("object_id", -1) < 0:
		_add_validation_warning(results, "invalid_id", object,
			{"message": "Object has invalid ID"})

func _validate_object_physics(object: BaseSpaceObject, results: Dictionary) -> void:
	"""Validate object physics state."""
	if object is RigidBody3D:
		var body: RigidBody3D = object as RigidBody3D
		
		# Check for excessive velocities
		if body.linear_velocity.length() > 1000.0:
			_add_validation_warning(results, "excessive_velocity", object,
				{"velocity": body.linear_velocity.length(), "limit": 1000.0})
		
		# Check for NaN values
		if is_nan(body.linear_velocity.x) or is_nan(body.linear_velocity.y) or is_nan(body.linear_velocity.z):
			_add_validation_error(results, "nan_velocity", object,
				{"message": "Object has NaN velocity values"})

func _validate_object_collision(object: BaseSpaceObject, results: Dictionary) -> void:
	"""Validate object collision configuration."""
	if object is CollisionObject3D:
		var collision_obj: CollisionObject3D = object as CollisionObject3D
		
		# Check for collision shapes
		if collision_obj.get_shape_owners().size() == 0:
			_add_validation_warning(results, "no_collision_shapes", object,
				{"message": "Object has no collision shapes"})

func _validate_object_performance(object: BaseSpaceObject, results: Dictionary) -> void:
	"""Validate object performance characteristics."""
	# Check for performance issues like too many nodes, etc.
	var child_count: int = object.get_child_count()
	if child_count > 50:
		_add_validation_warning(results, "excessive_children", object,
			{"child_count": child_count, "recommended_max": 50})

func _check_object_for_errors(object: BaseSpaceObject) -> void:
	"""Quick error check for an object."""
	if not is_instance_valid(object):
		_log_error("invalid_object_reference", object, {"message": "Object reference became invalid"})
		return
	
	# Check for common error conditions
	if object.is_queued_for_deletion():
		_log_error("object_queued_for_deletion", object, {"message": "Object is queued for deletion but still being processed"})

func _add_validation_error(results: Dictionary, error_type: String, object: BaseSpaceObject, details: Dictionary) -> void:
	"""Add a validation error to results."""
	var error: Dictionary = {
		"type": error_type,
		"object_name": object.name if object else "unknown",
		"details": details,
		"timestamp": Time.get_time_dict_from_system()
	}
	results.errors.append(error)
	
	# Also log to error system
	_log_error(error_type, object, details)

func _add_validation_warning(results: Dictionary, warning_type: String, object: BaseSpaceObject, details: Dictionary) -> void:
	"""Add a validation warning to results."""
	var warning: Dictionary = {
		"type": warning_type,
		"object_name": object.name if object else "unknown",
		"details": details,
		"timestamp": Time.get_time_dict_from_system()
	}
	results.warnings.append(warning)

func _log_error(error_type: String, object: BaseSpaceObject, details: Dictionary) -> void:
	"""Log an error to the error system."""
	error_count += 1
	
	var error_message: String = "[color=red][ERROR][/color] %s: %s" % [
		error_type,
		details.get("message", "Unknown error")
	]
	
	if object:
		error_message += " (Object: %s)" % object.name
	
	if error_log:
		error_log.text += error_message + "\n"
	
	error_detected.emit(error_type, object, details)
	print("ObjectDebugger ERROR: %s" % error_message)

func _update_properties_panel(object: BaseSpaceObject) -> void:
	"""Update the properties panel with object information."""
	if not properties_panel:
		return
	
	# Clear existing properties
	for child in properties_panel.get_children():
		child.queue_free()
	
	if not is_instance_valid(object):
		var label: Label = Label.new()
		label.text = "Invalid object selected"
		properties_panel.add_child(label)
		return
	
	# Add object properties
	_add_property_label("Name", object.name)
	_add_property_label("Type", str(object.get_class()))
	_add_property_label("Position", str(object.global_position))
	
	if object is RigidBody3D:
		var body: RigidBody3D = object as RigidBody3D
		_add_property_label("Velocity", str(body.linear_velocity))
		_add_property_label("Mass", str(body.mass))
	
	if object.has_method("get_object_type"):
		_add_property_label("Object Type", str(object.get_object_type()))
	
	if object.has_method("get_health"):
		_add_property_label("Health", str(object.get_health()))

func _add_property_label(property_name: String, value: String) -> void:
	"""Add a property label to the properties panel."""
	var container: HBoxContainer = HBoxContainer.new()
	properties_panel.add_child(container)
	
	var name_label: Label = Label.new()
	name_label.text = property_name + ":"
	name_label.custom_minimum_size = Vector2(100, 20)
	container.add_child(name_label)
	
	var value_label: Label = Label.new()
	value_label.text = value
	container.add_child(value_label)

func _clear_properties_panel() -> void:
	"""Clear the properties panel."""
	if properties_panel:
		for child in properties_panel.get_children():
			child.queue_free()

func _refresh_object_list() -> void:
	"""Refresh the object list display."""
	if not object_list:
		return
	
	object_list.clear()
	
	for object in registered_objects:
		if is_instance_valid(object):
			var display_name: String = object.name
			if object == selected_object:
				display_name = "► " + display_name
			object_list.add_item(display_name)

func _show_debug_panel() -> void:
	"""Show the debug panel."""
	if debug_panel:
		debug_panel.visible = true

func _hide_debug_panel() -> void:
	"""Hide the debug panel."""
	if debug_panel:
		debug_panel.visible = false

## Signal handlers

func _on_object_created(object: BaseSpaceObject) -> void:
	"""Handle object creation events."""
	if debug_enabled:
		register_object_for_debugging(object)

func _on_object_destroyed(object: BaseSpaceObject) -> void:
	"""Handle object destruction events."""
	unregister_object_from_debugging(object)

func _on_physics_step_completed(delta: float) -> void:
	"""Handle physics step completion."""
	# Update physics visualizations if needed
	pass

func _on_collision_detected(object_a: BaseSpaceObject, object_b: BaseSpaceObject) -> void:
	"""Handle collision detection events."""
	if debug_enabled and show_collision_shapes:
		print("ObjectDebugger: Collision detected between %s and %s" % [object_a.name, object_b.name])

func _on_object_list_item_selected(index: int) -> void:
	"""Handle object list selection."""
	if index >= 0 and index < registered_objects.size():
		var object: BaseSpaceObject = registered_objects[index]
		select_object_for_inspection(object)

func _on_validate_all_pressed() -> void:
	"""Handle validate all button press."""
	validate_all_objects()

func _on_refresh_list_pressed() -> void:
	"""Handle refresh list button press."""
	_refresh_object_list()

func _on_clear_errors_pressed() -> void:
	"""Handle clear errors button press."""
	if error_log:
		error_log.text = ""
	error_count = 0