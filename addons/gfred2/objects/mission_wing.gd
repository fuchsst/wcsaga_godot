@tool
extends Node3D

# Mission object reference
var mission_object: MissionObject

# Visual components
var label: Label3D
var wing_marker: MeshInstance3D
var collision_shape: CollisionShape3D

# Materials
var default_material: StandardMaterial3D

func _ready():
	# Add to selectable group
	add_to_group("selectable")
	
	# Create wing marker visual
	wing_marker = MeshInstance3D.new()
	wing_marker.mesh = CylinderMesh.new()
	wing_marker.mesh.height = 0.2
	wing_marker.mesh.radius = 1.0
	add_child(wing_marker)
	
	# Setup default material
	default_material = StandardMaterial3D.new()
	default_material.albedo_color = Color(0.2, 0.7, 0.2) # Green for wings
	wing_marker.material_override = default_material
	
	# Create collision shape for selection
	var static_body = StaticBody3D.new()
	static_body.collision_layer = 0x2 # Selection layer
	add_child(static_body)
	
	collision_shape = CollisionShape3D.new()
	collision_shape.shape = CylinderShape3D.new()
	collision_shape.shape.height = wing_marker.mesh.height
	collision_shape.shape.radius = wing_marker.mesh.radius
	static_body.add_child(collision_shape)
	
	# Create label
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.text = mission_object.name if mission_object else "Wing"
	add_child(label)
	label.position.y = 2.0 # Place above marker

func _process(_delta):
	if !mission_object:
		return
		
	# Update transform from mission object
	global_transform = mission_object.transform
	
	# Update label
	label.text = mission_object.name
	
	# Update visibility
	visible = mission_object.visible
	
	# Update collision shape to match visual
	collision_shape.shape.height = wing_marker.mesh.height
	collision_shape.shape.radius = wing_marker.mesh.radius
