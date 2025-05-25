@tool
class_name MissionObjectNode3D
extends Node3D

## 3D representation of a mission object in the FRED2 mission editor.
## Provides visual representation, selection highlighting, and interaction
## for ships, waypoints, and other mission elements.

signal object_clicked(object: MissionObjectNode3D, multi_select: bool)
signal transform_changed(object: MissionObjectNode3D)
signal properties_requested(object: MissionObjectNode3D)

# Transformation signals for undo/redo system
signal transformation_started()
signal transformation_changed()
signal transformation_finished()

@export var selection_color: Color = Color.YELLOW
@export var hover_color: Color = Color.WHITE
@export var default_color: Color = Color.GRAY
@export var selection_outline_width: float = 0.1

# Object state
var mission_object: MissionObject
var object_type: MissionObject.Type
var is_selected: bool = false
var is_hovered: bool = false

# Visual components
var mesh_instance: MeshInstance3D
var selection_outline: MeshInstance3D
var label_3d: Label3D
var collision_area: Area3D
var collision_shape: CollisionShape3D

# Materials
var base_material: StandardMaterial3D
var selection_material: StandardMaterial3D
var hover_material: StandardMaterial3D

# Object properties
var selection_radius: float = 5.0
var label_offset: Vector3 = Vector3(0, 10, 0)

func _ready() -> void:
	setup_materials()
	setup_collision()
	setup_visual_components()
	
	# Connect signals
	if collision_area:
		collision_area.input_event.connect(_on_area_input_event)
		collision_area.mouse_entered.connect(_on_mouse_entered)
		collision_area.mouse_exited.connect(_on_mouse_exited)

## Sets up the object from mission data.
func setup_from_mission_object(obj_data: MissionObject) -> void:
	if not obj_data:
		push_error("Cannot setup MissionObjectNode3D with null mission object")
		return
	
	mission_object = obj_data
	object_type = obj_data.type
	name = obj_data.name
	
	# Set transform from mission data
	position = obj_data.position
	rotation_degrees = obj_data.rotation
	
	# Create visual representation based on type
	create_visual_representation()
	
	# Update label
	if label_3d:
		label_3d.text = obj_data.name

## Creates materials for different visual states.
func setup_materials() -> void:
	# Base material
	base_material = StandardMaterial3D.new()
	base_material.albedo_color = default_color
	base_material.metallic = 0.2
	base_material.roughness = 0.8
	
	# Selection material
	selection_material = StandardMaterial3D.new()
	selection_material.albedo_color = selection_color
	selection_material.emission = selection_color * 0.3
	selection_material.metallic = 0.1
	selection_material.roughness = 0.9
	
	# Hover material
	hover_material = StandardMaterial3D.new()
	hover_material.albedo_color = hover_color
	hover_material.emission = hover_color * 0.1
	hover_material.metallic = 0.2
	hover_material.roughness = 0.7

## Sets up collision detection for mouse interaction.
func setup_collision() -> void:
	collision_area = Area3D.new()
	collision_area.name = "CollisionArea"
	add_child(collision_area)
	
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	collision_area.add_child(collision_shape)
	
	# Configure area for input detection
	collision_area.input_ray_pickable = true
	collision_area.monitoring = false
	collision_area.monitorable = true

## Sets up visual components.
func setup_visual_components() -> void:
	# Main mesh instance
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance"
	add_child(mesh_instance)
	
	# Selection outline
	selection_outline = MeshInstance3D.new()
	selection_outline.name = "SelectionOutline"
	selection_outline.visible = false
	add_child(selection_outline)
	
	# Object label
	label_3d = Label3D.new()
	label_3d.name = "ObjectLabel"
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	label_3d.position = label_offset
	label_3d.modulate = Color.WHITE
	add_child(label_3d)

## Creates visual representation based on object type.
func create_visual_representation() -> void:
	if not mission_object:
		return
	
	match object_type:
		MissionObject.Type.SHIP:
			create_ship_representation()
		MissionObject.Type.WAYPOINT:
			create_waypoint_representation()
		MissionObject.Type.WING:
			create_wing_representation()
		MissionObject.Type.JUMP_NODE:
			create_jump_node_representation()
		_:
			create_generic_representation()

## Creates representation for ships.
func create_ship_representation() -> void:
	# Create ship placeholder mesh (box with direction indicator)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(20, 5, 30)  # Length, height, width
	
	mesh_instance.mesh = mesh
	mesh_instance.material_override = get_ship_material()
	
	# Create selection outline
	var outline_mesh: BoxMesh = BoxMesh.new()
	outline_mesh.size = mesh.size * 1.1
	selection_outline.mesh = outline_mesh
	selection_outline.material_override = selection_material
	
	# Set collision shape
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = mesh.size
	collision_shape.shape = shape
	
	selection_radius = mesh.size.length() * 0.5
	
	# Add direction indicator
	create_direction_indicator()

## Creates representation for waypoints.
func create_waypoint_representation() -> void:
	# Create waypoint mesh (sphere)
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 3.0
	mesh.height = 6.0
	
	mesh_instance.mesh = mesh
	mesh_instance.material_override = get_waypoint_material()
	
	# Create selection outline
	var outline_mesh: SphereMesh = SphereMesh.new()
	outline_mesh.radius = mesh.radius * 1.2
	outline_mesh.height = mesh.height * 1.2
	selection_outline.mesh = outline_mesh
	selection_outline.material_override = selection_material
	
	# Set collision shape
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = mesh.radius
	collision_shape.shape = shape
	
	selection_radius = mesh.radius

## Creates representation for wings.
func create_wing_representation() -> void:
	# Wing is represented as a formation of ship indicators
	create_ship_representation()
	
	# Add formation indicators
	create_formation_indicators()

## Creates representation for jump nodes.
func create_jump_node_representation() -> void:
	# Create jump node mesh (cylinder with glow effect)
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 15.0
	mesh.bottom_radius = 15.0
	mesh.height = 30.0
	
	mesh_instance.mesh = mesh
	mesh_instance.material_override = get_jump_node_material()
	
	# Create selection outline
	var outline_mesh: CylinderMesh = CylinderMesh.new()
	outline_mesh.top_radius = mesh.top_radius * 1.1
	outline_mesh.bottom_radius = mesh.bottom_radius * 1.1
	outline_mesh.height = mesh.height * 1.1
	selection_outline.mesh = outline_mesh
	selection_outline.material_override = selection_material
	
	# Set collision shape
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.top_radius = mesh.top_radius
	shape.bottom_radius = mesh.bottom_radius
	shape.height = mesh.height
	collision_shape.shape = shape
	
	selection_radius = mesh.top_radius

## Creates generic representation for unknown types.
func create_generic_representation() -> void:
	# Create generic mesh (octahedron)
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 5.0
	mesh.height = 10.0
	
	mesh_instance.mesh = mesh
	mesh_instance.material_override = base_material
	
	# Set collision shape
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = mesh.radius
	collision_shape.shape = shape
	
	selection_radius = mesh.radius

## Creates direction indicator for ships.
func create_direction_indicator() -> void:
	var indicator: MeshInstance3D = MeshInstance3D.new()
	indicator.name = "DirectionIndicator"
	
	# Create cone pointing forward
	var cone_mesh: SphereMesh = SphereMesh.new()
	cone_mesh.radius = 2.0
	cone_mesh.height = 8.0
	
	indicator.mesh = cone_mesh
	indicator.position = Vector3(0, 0, -20)  # Front of ship
	indicator.material_override = hover_material
	
	add_child(indicator)

## Creates formation indicators for wings.
func create_formation_indicators() -> void:
	# Add small indicators around the main ship to show formation
	var formation_positions: Array[Vector3] = [
		Vector3(-10, 0, 10),
		Vector3(10, 0, 10),
		Vector3(-15, 0, 20),
		Vector3(15, 0, 20)
	]
	
	for pos: Vector3 in formation_positions:
		var indicator: MeshInstance3D = MeshInstance3D.new()
		var small_mesh: BoxMesh = BoxMesh.new()
		small_mesh.size = Vector3(4, 2, 6)
		
		indicator.mesh = small_mesh
		indicator.position = pos
		indicator.material_override = base_material
		add_child(indicator)

## Gets material for ship based on team.
func get_ship_material() -> StandardMaterial3D:
	if not mission_object:
		return base_material
	
	var material: StandardMaterial3D = base_material.duplicate()
	
	# Color code by team (team is an integer)
	match mission_object.team:
		0:  # Player/Friendly
			material.albedo_color = Color.BLUE
		1:  # Hostile
			material.albedo_color = Color.RED
		2:  # Neutral
			material.albedo_color = Color.YELLOW
		3:  # Unknown
			material.albedo_color = Color.ORANGE
		_:
			material.albedo_color = default_color
	
	return material

## Gets material for waypoints.
func get_waypoint_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = base_material.duplicate()
	material.albedo_color = Color.CYAN
	material.emission = Color.CYAN * 0.2
	return material

## Gets material for jump nodes.
func get_jump_node_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = base_material.duplicate()
	material.albedo_color = Color.MAGENTA
	material.emission = Color.MAGENTA * 0.3
	return material

## Sets the selection state of the object.
func set_selected(selected: bool) -> void:
	if is_selected == selected:
		return
	
	is_selected = selected
	selection_outline.visible = selected
	
	# Update material
	update_material()

## Sets the hover state of the object.
func set_hovered(hovered: bool) -> void:
	if is_hovered == hovered:
		return
	
	is_hovered = hovered
	update_material()

## Updates the object material based on current state.
func update_material() -> void:
	if not mesh_instance:
		return
	
	var current_material: StandardMaterial3D
	
	if is_selected:
		current_material = selection_material
	elif is_hovered:
		current_material = hover_material
	else:
		# Use type-specific material
		match object_type:
			MissionObject.Type.SHIP:
				current_material = get_ship_material()
			MissionObject.Type.WAYPOINT:
				current_material = get_waypoint_material()
			MissionObject.Type.JUMP_NODE:
				current_material = get_jump_node_material()
			_:
				current_material = base_material
	
	mesh_instance.material_override = current_material

## Gets the selection radius for this object.
func get_selection_radius() -> float:
	return selection_radius

## Gets the AABB bounds of this object.
func get_aabb() -> AABB:
	if mesh_instance and mesh_instance.mesh:
		return mesh_instance.get_aabb()
	else:
		# Fallback bounds
		var radius: float = selection_radius
		return AABB(Vector3(-radius, -radius, -radius), Vector3(radius * 2, radius * 2, radius * 2))

## Updates mission object data when transform changes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if mission_object:
			mission_object.position = position
			mission_object.rotation = rotation_degrees
		
		transform_changed.emit(self)

## Signal handlers

func _on_area_input_event(camera: Node, event: InputEvent, click_position: Vector3, click_normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var multi_select: bool = Input.is_key_pressed(KEY_CTRL)
			object_clicked.emit(self, multi_select)
		
		# Consume the event
		get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# Right-click for properties
		properties_requested.emit(self)
		get_viewport().set_input_as_handled()

func _on_mouse_entered() -> void:
	set_hovered(true)

func _on_mouse_exited() -> void:
	set_hovered(false)

## Sync current transform to mission data
func sync_to_mission_data() -> void:
	if not mission_object:
		return
	
	# Update mission object position and rotation
	mission_object.position = global_position
	mission_object.rotation = global_rotation
	mission_object.scale = global_scale
	
	# Emit signal for other systems that need to know about the change
	transform_changed.emit(self)