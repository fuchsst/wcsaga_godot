@tool
extends Node3D

# Mission object reference
var mission_object: MissionObject

# Visual components
var marker: MeshInstance3D
var collision_shape: CollisionShape3D
var label: Label3D

# Materials
var default_material: StandardMaterial3D

func _ready():
	# Add to selectable group
	add_to_group("selectable")
	
	# Create waypoint marker visual
	marker = MeshInstance3D.new()
	marker.mesh = SphereMesh.new()
	marker.mesh.radius = 0.5
	marker.mesh.height = 1.0
	add_child(marker)
	
	# Setup default material
	default_material = StandardMaterial3D.new()
	default_material.albedo_color = Color(0.7, 0.2, 0.2) # Red for waypoints
	default_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	default_material.albedo_color.a = 0.7 # Semi-transparent
	marker.material_override = default_material
	
	# Create collision shape for selection
	var static_body = StaticBody3D.new()
	static_body.collision_layer = 0x2 # Selection layer
	add_child(static_body)
	
	collision_shape = CollisionShape3D.new()
	collision_shape.shape = SphereShape3D.new()
	collision_shape.shape.radius = marker.mesh.radius
	static_body.add_child(collision_shape)
	
	# Create label
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.text = mission_object.name if mission_object else "Waypoint"
	add_child(label)
	label.position.y = 1.5 # Place above marker

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
	collision_shape.shape.radius = marker.mesh.radius
