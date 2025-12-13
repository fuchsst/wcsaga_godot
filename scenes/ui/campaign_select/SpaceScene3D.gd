extends Node3D

# SpaceScene3D.gd
# Handles the 3D background visualization (rotating ships, stars)

@onready var ship_pivot: Node3D
@onready var camera: Camera3D

func _ready():
	_setup_scene()

func _setup_scene():
	# 1. Setup Camera
	camera = Camera3D.new()
	camera.name = "MainCamera"
	# position set here, look_at called safely
	add_child(camera)
	camera.position = Vector3(0, 3, 8)
	camera.current = true

	# Defer look_at to ensure transform is valid in tree
	if is_inside_tree():
		camera.look_at(Vector3.ZERO)
	else:
		call_deferred("_safe_look_at", Vector3.ZERO)

func _safe_look_at(target: Vector3):
	if camera and is_instance_valid(camera):
		camera.look_at(target)

	# 2. Setup Lighting
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45, -45, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)

	var env = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var environment_res = Environment.new()
	environment_res.background_mode = Environment.BG_COLOR
	environment_res.background_color = Color(0.02, 0.02, 0.05) # Deep Space Blue-Black
	environment_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_res.ambient_light_color = Color(0.1, 0.1, 0.2)
	env.environment = environment_res
	add_child(env)

	# 3. Setup Placeholder Ship
	ship_pivot = Node3D.new()
	ship_pivot.name = "ShipPivot"
	add_child(ship_pivot)

	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.5, 0.5, 4.0) # Fuselage
	mesh_instance.mesh = box
	ship_pivot.add_child(mesh_instance)

	var wings = MeshInstance3D.new()
	var prism = PrismMesh.new()
	prism.size = Vector3(6.0, 0.2, 2.0)
	wings.mesh = prism
	wings.rotation_degrees.x = -90
	wings.position = Vector3(0, 0, 0.5)
	ship_pivot.add_child(wings)

	# Create a simple material
	var secondary_material = StandardMaterial3D.new()
	secondary_material.albedo_color = Color(0.4, 0.5, 0.6)
	secondary_material.metallic = 0.8
	secondary_material.roughness = 0.2
	mesh_instance.material_override = secondary_material
	wings.material_override = secondary_material

func _process(delta):
	if ship_pivot:
		# Slow rotation
		ship_pivot.rotation_degrees.y += 15.0 * delta
		# Gentle bobbing
		ship_pivot.rotation_degrees.z = sin(Time.get_ticks_msec() / 2000.0) * 5.0
		ship_pivot.position.y = sin(Time.get_ticks_msec() / 1500.0) * 0.2
