class_name AsteroidObject
extends RigidBody3D

## Asteroid and debris behavior controller
## Handles physics simulation, collision detection, and destruction effects for asteroids

@export var asteroid_data: AsteroidData
@export var hull_strength: float = 500.0

var _current_lod_model: String = ""
var _model_node: Node3D
var _explosion_effects: Array[Node] = []

func _ready() -> void:
	if asteroid_data:
		_initialize_from_data()
	
	# Connect collision detection from Area3D
	var area: Area3D = get_node_or_null("Area3D")
	if area:
		area.body_entered.connect(_on_body_entered)

func _initialize_from_data() -> void:
	"""Initialize asteroid properties from data resource."""
	if not asteroid_data:
		return
	
	hull_strength = float(asteroid_data.hitpoints)
	
	# Update debug label
	var debug_label: Label3D = get_node_or_null("DebugInfo")
	if debug_label:
		debug_label.text = asteroid_data.get_display_name()
	
	# Set up collision shape based on asteroid size (estimate from hitpoints)
	var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if collision_shape and collision_shape.shape is SphereShape3D:
		var sphere: SphereShape3D = collision_shape.shape as SphereShape3D
		# Scale collision radius based on hitpoints (rough estimate)
		sphere.radius = max(10.0, sqrt(float(asteroid_data.hitpoints)) * 5.0)
	
	# Update Area3D collision shape to match
	var area: Area3D = get_node_or_null("Area3D")
	if area:
		var area_shape: CollisionShape3D = area.get_node_or_null("DetectionShape")
		if area_shape and collision_shape:
			area_shape.shape = collision_shape.shape
	
	# Load initial model
	if not asteroid_data.detail_distances.is_empty():
		# Start with closest LOD model
		var initial_model: String = asteroid_data.get_model_for_distance(0.0)
		if not initial_model.is_empty():
			_load_model(initial_model)
			_current_lod_model = initial_model
	
	# Set up initial physics properties
	if asteroid_data.max_speed > 0.0:
		# Apply some initial random rotation
		angular_velocity = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0), 
			randf_range(-1.0, 1.0)
		) * 0.1

func _physics_process(delta: float) -> void:
	# Update LOD model based on camera distance if needed
	_update_lod_model()

func _update_lod_model() -> void:
	"""Update the visible model based on viewing distance."""
	if not asteroid_data:
		return
	
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return
	
	var distance: float = global_position.distance_to(camera.global_position)
	var target_model: String = asteroid_data.get_model_for_distance(distance)
	
	if target_model != _current_lod_model and not target_model.is_empty():
		_load_model(target_model)
		_current_lod_model = target_model

func _load_model(model_path: String) -> void:
	"""Load and display the specified 3D model."""
	if _model_node:
		_model_node.queue_free()
		_model_node = null
	
	# Load the GLB model
	var full_path: String = "res://assets/" + model_path
	if ResourceLoader.exists(full_path):
		var model_scene: PackedScene = load(full_path)
		if model_scene:
			_model_node = model_scene.instantiate()
			# Add to ModelContainer if it exists, otherwise to self
			var container: Node3D = get_node_or_null("ModelContainer")
			if container:
				container.add_child(_model_node)
			else:
				add_child(_model_node)

func hit(source_object: Node, hit_pos: Vector3, damage: float) -> void:
	"""Handle damage from weapons or collisions."""
	if hull_strength <= 0.0:
		return # Already destroyed
	
	hull_strength -= damage
	
	if hull_strength <= 0.0:
		_destroy_asteroid()

func _destroy_asteroid() -> void:
	"""Handle asteroid destruction with effects and debris."""
	if not asteroid_data:
		queue_free()
		return
	
	# Create explosion effect if configured
	if asteroid_data.has_explosion():
		_create_explosion_effect()
	
	# TODO: Spawn debris fragments based on asteroid type
	_spawn_debris()
	
	queue_free()

func _create_explosion_effect() -> void:
	"""Create explosion effects based on asteroid data."""
	if not asteroid_data:
		return
	
	# Create explosion at asteroid position
	var explosion_pos: Vector3 = global_position
	
	# Apply explosion damage to nearby objects
	if asteroid_data.explosion_damage > 0.0:
		_apply_area_damage(explosion_pos, asteroid_data.explosion_damage, 
						   asteroid_data.explosion_inner_radius, 
						   asteroid_data.explosion_outer_radius)
	
	# TODO: Integrate with WCS effects system for visual explosion
	print("Asteroid destroyed with explosion damage: %.1f" % asteroid_data.explosion_damage)

func _apply_area_damage(center: Vector3, damage: float, inner_radius: float, outer_radius: float) -> void:
	"""Apply area-of-effect damage to nearby objects."""
	if outer_radius <= 0.0:
		return
	
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	
	# Create sphere shape for area damage detection
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = outer_radius
	query.shape = sphere_shape
	query.transform.origin = center
	
	var results: Array[Dictionary] = space_state.intersect_shape(query)
	
	for result in results:
		var body: Node = result.get("collider")
		if body and body != self and body.has_method("hit"):
			var distance: float = center.distance_to(body.global_position)
			var damage_factor: float = 1.0
			
			# Reduce damage based on distance
			if distance > inner_radius:
				var falloff: float = (distance - inner_radius) / (outer_radius - inner_radius)
				damage_factor = 1.0 - falloff
			
			var final_damage: float = damage * damage_factor
			if final_damage > 0.0:
				body.hit(self, body.global_position, final_damage)

func _spawn_debris() -> void:
	"""Spawn smaller debris pieces when asteroid is destroyed."""
	# TODO: Implement debris spawning based on asteroid type
	# This would create smaller AsteroidObjects with debris data
	pass

func _on_body_entered(body: Node3D) -> void:
	"""Handle collision with other objects."""
	if hull_strength <= 0.0:
		return # Ignore if already destroyed
	
	var hit_pos: Vector3 = global_position # Approximate collision point
	
	if body.has_method("hit"):
		# This is a ship or other object that can take damage
		var collision_damage: float = _calculate_collision_damage(body)
		if collision_damage > 0.0:
			body.hit(self, hit_pos, collision_damage)
		
		# Asteroid also takes damage from the collision
		var asteroid_damage: float = collision_damage * 0.5 # Asteroids are tough
		hit(body, hit_pos, asteroid_damage)

func _calculate_collision_damage(other_body: Node3D) -> float:
	"""Calculate collision damage based on relative velocity and mass."""
	var relative_velocity: Vector3 = linear_velocity
	if other_body is RigidBody3D:
		relative_velocity -= (other_body as RigidBody3D).linear_velocity
	
	var speed: float = relative_velocity.length()
	var base_damage: float = speed * 0.1 # Adjust multiplier as needed
	
	# Scale by mass if available
	if other_body is RigidBody3D:
		var other_mass: float = (other_body as RigidBody3D).mass
		base_damage *= sqrt(other_mass) # Square root scaling to avoid extreme values
	
	return base_damage

func get_asteroid_data() -> AsteroidData:
	"""Get the asteroid data resource."""
	return asteroid_data

func set_asteroid_data(data: AsteroidData) -> void:
	"""Set new asteroid data and reinitialize."""
	asteroid_data = data
	if is_inside_tree():
		_initialize_from_data()

func load_asteroid_from_file(file_path: String) -> bool:
	"""Load asteroid data from .tres file and initialize.
	Args:
		file_path: Path to .tres file (e.g., 'res://assets/campaigns/.../large_asteroid.tres')
	Returns:
		true if loaded successfully, false otherwise"""
	
	if not ResourceLoader.exists(file_path):
		push_error("Asteroid data file not found: " + file_path)
		return false
	
	var data: Resource = load(file_path)
	if not data is AsteroidData:
		push_error("File is not AsteroidData resource: " + file_path)
		return false
	
	set_asteroid_data(data as AsteroidData)
	return true

func setup_asteroid(data: AsteroidData, position: Vector3 = Vector3.ZERO, rotation: Vector3 = Vector3.ZERO) -> void:
	"""Quick setup method for placing asteroids in scenes.
	Args:
		data: AsteroidData resource
		position: World position
		rotation: Rotation in radians"""
	
	set_asteroid_data(data)
	global_position = position
	global_rotation = rotation