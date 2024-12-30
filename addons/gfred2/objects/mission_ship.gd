@tool
extends Node3D

# Mission object reference
var mission_object: MissionObject

# Visual components
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var label: Label3D

# Materials
var default_material: StandardMaterial3D

func _ready():
	# Add to selectable group
	add_to_group("selectable")
	
	# Create visual representation
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new() # Temporary mesh, should load ship model
	add_child(mesh_instance)
	
	# Setup default material
	default_material = StandardMaterial3D.new()
	default_material.albedo_color = Color(0.7, 0.7, 0.7)
	mesh_instance.material_override = default_material
	
	# Create collision shape for selection
	var static_body = StaticBody3D.new()
	static_body.collision_layer = 0x2 # Selection layer
	add_child(static_body)
	
	collision_shape = CollisionShape3D.new()
	collision_shape.shape = BoxShape3D.new()
	collision_shape.shape.size = Vector3(2, 2, 2) # Match visual size
	static_body.add_child(collision_shape)
	
	# Create label
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.text = mission_object.name if mission_object else "Ship"
	add_child(label)
	label.position.y = 2.0 # Place above ship

func _process(_delta):
	if !mission_object:
		return
		
	# Update transform from mission object
	global_transform = mission_object.transform
	
	# Update label
	label.text = mission_object.name
	
	# Update visibility
	visible = mission_object.visible
	
	# Update collision shape to match mesh bounds
	if mesh_instance.mesh:
		var aabb = mesh_instance.mesh.get_aabb()
		collision_shape.shape.size = aabb.size
		collision_shape.position = aabb.position + aabb.size * 0.5
