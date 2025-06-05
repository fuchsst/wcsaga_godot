class_name PhysicsDebugger
extends Node

## Physics debugging tools for visualizing force vectors and momentum
## Provides visual debugging capabilities for force application and momentum systems
## Integrates with ForceApplication and PhysicsManager for comprehensive physics debugging

signal debug_mode_changed(enabled: bool)
signal force_visualization_updated()
signal momentum_display_updated()

# Debug configuration
@export var debug_enabled: bool = false
@export var force_visualization_enabled: bool = true
@export var momentum_visualization_enabled: bool = true
@export var velocity_visualization_enabled: bool = true
@export var force_scale: float = 0.01  # Scale factor for force vector visualization
@export var velocity_scale: float = 0.1  # Scale factor for velocity vector visualization
@export var max_debug_objects: int = 50  # Limit debug visualizations for performance

# Debug colors
@export var force_color: Color = Color.RED
@export var velocity_color: Color = Color.BLUE
@export var momentum_color: Color = Color.GREEN
@export var thruster_color: Color = Color.ORANGE
@export var collision_color: Color = Color.YELLOW

# Debug tracking
var debug_objects: Dictionary = {}  # body -> DebugData
var debug_lines: Array[Line3D] = []
var debug_labels: Array[Label3D] = []
var performance_stats: Dictionary = {}

# Debug data structure
class DebugData:
	var body: RigidBody3D
	var force_lines: Array[Line3D] = []
	var velocity_line: Line3D
	var momentum_label: Label3D
	var last_update_time: float
	
	func _init(physics_body: RigidBody3D) -> void:
		body = physics_body
		last_update_time = Time.get_time_dict_from_system()["second"]

func _ready() -> void:
	set_process(debug_enabled)
	print("PhysicsDebugger: Physics debugging system initialized")

func _process(delta: float) -> void:
	if debug_enabled:
		_update_debug_visualizations(delta)
		_update_performance_stats()

## Enable or disable physics debugging
func set_debug_enabled(enabled: bool) -> void:
	"""Enable or disable physics debugging visualization.
	
	Args:
		enabled: true to enable debugging, false to disable
	"""
	if debug_enabled != enabled:
		debug_enabled = enabled
		set_process(enabled)
		
		if not enabled:
			_clear_all_debug_visualizations()
		
		debug_mode_changed.emit(enabled)
		print("PhysicsDebugger: Debug mode %s" % ("enabled" if enabled else "disabled"))

## Register a physics body for debug visualization
func register_debug_body(body: RigidBody3D) -> bool:
	"""Register a RigidBody3D for physics debugging visualization.
	
	Args:
		body: RigidBody3D to track for debugging
		
	Returns:
		true if registration successful, false otherwise
	"""
	if not is_instance_valid(body):
		push_error("PhysicsDebugger: Cannot register invalid body")
		return false
	
	if debug_objects.size() >= max_debug_objects:
		push_warning("PhysicsDebugger: Maximum debug objects reached, ignoring registration")
		return false
	
	if body in debug_objects:
		push_warning("PhysicsDebugger: Body already registered for debugging")
		return false
	
	# Create debug data
	debug_objects[body] = DebugData.new(body)
	
	# Create debug visualizations
	if debug_enabled:
		_create_debug_visualizations(body)
	
	return true

## Unregister a physics body from debug visualization
func unregister_debug_body(body: RigidBody3D) -> void:
	"""Remove a RigidBody3D from debug visualization tracking.
	
	Args:
		body: RigidBody3D to stop tracking
	"""
	if body in debug_objects:
		_cleanup_debug_visualizations(body)
		debug_objects.erase(body)

## Visualize force application to a physics body
func visualize_force(body: RigidBody3D, force: Vector3, application_point: Vector3, force_type: String = "generic") -> void:
	"""Add force vector visualization for a physics body.
	
	Args:
		body: RigidBody3D the force is applied to
		force: Force vector being applied
		application_point: Point where force is applied (local coordinates)
		force_type: Type of force for color coding
	"""
	if not debug_enabled or not force_visualization_enabled:
		return
	
	if body not in debug_objects:
		register_debug_body(body)
	
	if body not in debug_objects:
		return  # Registration failed
	
	var debug_data: DebugData = debug_objects[body]
	
	# Create force visualization line
	var force_line: Line3D = _create_force_line(body, force, application_point, force_type)
	if force_line:
		debug_data.force_lines.append(force_line)
		add_child(force_line)
	
	force_visualization_updated.emit()

## Update momentum visualization for a physics body
func update_momentum_display(body: RigidBody3D, momentum_data: Dictionary) -> void:
	"""Update momentum display for a physics body.
	
	Args:
		body: RigidBody3D to update momentum display for
		momentum_data: Dictionary containing momentum information
	"""
	if not debug_enabled or not momentum_visualization_enabled:
		return
	
	if body not in debug_objects:
		register_debug_body(body)
	
	if body not in debug_objects:
		return
	
	var debug_data: DebugData = debug_objects[body]
	
	# Update momentum label
	if debug_data.momentum_label:
		var momentum_text: String = "Mass: %.1fkg\nVel: %.1fm/s\nMomentum: %.1fkg⋅m/s" % [
			momentum_data.get("mass", 0.0),
			momentum_data.get("linear_velocity", Vector3.ZERO).length(),
			momentum_data.get("linear_momentum", Vector3.ZERO).length()
		]
		debug_data.momentum_label.text = momentum_text
		debug_data.momentum_label.global_position = body.global_position + Vector3(0, 2, 0)
	
	momentum_display_updated.emit()

## Get debug performance statistics
func get_debug_performance_stats() -> Dictionary:
	"""Get performance statistics for debug visualization system.
	
	Returns:
		Dictionary containing debug performance metrics
	"""
	return performance_stats.duplicate()

## Clear all debug visualizations
func clear_all_debug() -> void:
	"""Clear all debug visualizations and reset debugging state."""
	_clear_all_debug_visualizations()
	debug_objects.clear()
	performance_stats.clear()

# Private implementation methods

func _create_debug_visualizations(body: RigidBody3D) -> void:
	"""Create initial debug visualizations for a body."""
	if body not in debug_objects:
		return
	
	var debug_data: DebugData = debug_objects[body]
	
	# Create velocity line visualization
	if velocity_visualization_enabled:
		debug_data.velocity_line = _create_velocity_line(body)
		if debug_data.velocity_line:
			add_child(debug_data.velocity_line)
	
	# Create momentum label
	if momentum_visualization_enabled:
		debug_data.momentum_label = _create_momentum_label(body)
		if debug_data.momentum_label:
			add_child(debug_data.momentum_label)

func _create_force_line(body: RigidBody3D, force: Vector3, application_point: Vector3, force_type: String) -> Line3D:
	"""Create a Line3D to visualize force vector."""
	# Note: Line3D is a simplified representation - actual implementation would depend on 
	# available 3D line drawing system in Godot or custom mesh generation
	
	# For now, return null as this would require a custom 3D line rendering system
	# In a full implementation, this would create a MeshInstance3D with a custom line mesh
	return null

func _create_velocity_line(body: RigidBody3D) -> Line3D:
	"""Create a Line3D to visualize velocity vector."""
	# Similar to force line, would require custom 3D line rendering
	return null

func _create_momentum_label(body: RigidBody3D) -> Label3D:
	"""Create a Label3D to display momentum information."""
	var label: Label3D = Label3D.new()
	label.text = "Momentum Data"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 12
	label.modulate = momentum_color
	return label

func _update_debug_visualizations(delta: float) -> void:
	"""Update all debug visualizations."""
	var updated_count: int = 0
	
	for body in debug_objects.keys():
		if not is_instance_valid(body):
			debug_objects.erase(body)
			continue
		
		var debug_data: DebugData = debug_objects[body]
		
		# Update velocity visualization
		if velocity_visualization_enabled and debug_data.velocity_line:
			_update_velocity_line(body, debug_data.velocity_line)
		
		# Update momentum label
		if momentum_visualization_enabled and debug_data.momentum_label:
			var momentum_data: Dictionary = {
				"mass": body.mass,
				"linear_velocity": body.linear_velocity,
				"linear_momentum": body.linear_velocity * body.mass
			}
			update_momentum_display(body, momentum_data)
		
		# Clean up old force lines
		_cleanup_old_force_lines(debug_data, delta)
		
		debug_data.last_update_time = Time.get_time_dict_from_system()["second"]
		updated_count += 1
	
	performance_stats["debug_objects_updated"] = updated_count

func _update_velocity_line(body: RigidBody3D, velocity_line: Line3D) -> void:
	"""Update velocity line visualization."""
	if not velocity_line:
		return
	
	# Update line position and direction based on body velocity
	var start_pos: Vector3 = body.global_position
	var end_pos: Vector3 = start_pos + body.linear_velocity * velocity_scale
	
	# Update line geometry (implementation depends on Line3D system)
	velocity_line.global_position = start_pos

func _cleanup_old_force_lines(debug_data: DebugData, delta: float) -> void:
	"""Clean up force lines that are too old."""
	var force_line_lifetime: float = 1.0  # 1 second lifetime for force visualizations
	
	for i in range(debug_data.force_lines.size() - 1, -1, -1):
		var force_line: Line3D = debug_data.force_lines[i]
		if not is_instance_valid(force_line):
			debug_data.force_lines.remove_at(i)
			continue
		
		# Check line age (would need timestamp tracking on lines)
		# For now, just remove after a fixed time
		debug_data.force_lines.remove_at(i)
		force_line.queue_free()

func _cleanup_debug_visualizations(body: RigidBody3D) -> void:
	"""Clean up debug visualizations for a specific body."""
	if body not in debug_objects:
		return
	
	var debug_data: DebugData = debug_objects[body]
	
	# Clean up force lines
	for force_line in debug_data.force_lines:
		if is_instance_valid(force_line):
			force_line.queue_free()
	debug_data.force_lines.clear()
	
	# Clean up velocity line
	if debug_data.velocity_line and is_instance_valid(debug_data.velocity_line):
		debug_data.velocity_line.queue_free()
	
	# Clean up momentum label
	if debug_data.momentum_label and is_instance_valid(debug_data.momentum_label):
		debug_data.momentum_label.queue_free()

func _clear_all_debug_visualizations() -> void:
	"""Clear all debug visualizations from the scene."""
	for body in debug_objects.keys():
		_cleanup_debug_visualizations(body)
	
	debug_objects.clear()

func _update_performance_stats() -> void:
	"""Update debug performance statistics."""
	performance_stats["debug_objects_count"] = debug_objects.size()
	performance_stats["debug_lines_count"] = debug_lines.size()
	performance_stats["debug_labels_count"] = debug_labels.size()
	performance_stats["debug_enabled"] = debug_enabled
	performance_stats["force_visualization_enabled"] = force_visualization_enabled
	performance_stats["momentum_visualization_enabled"] = momentum_visualization_enabled
	performance_stats["velocity_visualization_enabled"] = velocity_visualization_enabled