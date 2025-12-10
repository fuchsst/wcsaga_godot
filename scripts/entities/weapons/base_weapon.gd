class_name BaseWeapon
extends Node3D

# Dependencies - using alias to avoid shadowing global class_name
const WCSWeaponData = preload("res://scripts/resources/weapons/weapon_data.gd")
# DamageResult is available via class_name, no preload needed

# Configuration
@export var weapon_data: WCSWeaponData

# State
var fired_by: Node3D  # Ship or object that fired this
var life_time: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var team: int = 0
var target: Node3D = null  # For homing/AI

# Signals
signal weapon_detonated(position: Vector3)
signal weapon_expired


func _ready() -> void:
	# Try to load weapon_data from metadata if not set via @export
	if not weapon_data:
		_load_weapon_data_from_metadata()

	if weapon_data:
		_initialize_from_data()
	else:
		push_warning("BaseWeapon initialized without WeaponData!")

	# Connect to HitArea if it exists (added by weapon_scene_generator)
	var hit_area = get_node_or_null("HitArea")
	if hit_area and hit_area is Area3D:
		hit_area.body_entered.connect(_on_body_entered)
		# Setup collision layers based on team at runtime
		_setup_collision_layers(hit_area)

	# Setup automated cleanup
	var lifetime: float = weapon_data.lifetime if weapon_data else 5.0
	get_tree().create_timer(max(lifetime, 0.1)).timeout.connect(_on_lifetime_expired)


func _load_weapon_data_from_metadata() -> void:
	# Scene generator stores weapon_data_path in metadata
	if has_meta("weapon_data_path"):
		var path = get_meta("weapon_data_path")
		if ResourceLoader.exists(path):
			weapon_data = load(path)
			return

	# Fallback: check for weapon_data directly in metadata (older scenes)
	if has_meta("weapon_data"):
		weapon_data = get_meta("weapon_data")


func _setup_collision_layers(area: Area3D) -> void:
	# Projectiles should only hit things not on their team
	# For now use basic setup - will be refined by CollisionManager
	if CollisionManager:
		area.collision_layer = CollisionManager.Layer.PROJECTILE
		area.collision_mask = CollisionManager.get_collision_mask("projectile", "")
	else:
		# Fallback if CollisionManager not available
		area.collision_layer = 1 << 4  # Layer 5: projectiles
		area.collision_mask = 1 | 2 | 4  # Players, Allies, Enemies


func _initialize_from_data() -> void:
	# Create laser visual if no model exists and this is a laser weapon
	if not get_node_or_null("Visuals") and weapon_data:
		if weapon_data.laser_bitmap and weapon_data.laser_length > 0:
			_create_laser_visual()


func _create_laser_visual() -> void:
	# Create elongated quad mesh for laser projectile
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "LaserMesh"

	# Create quad mesh (oriented along Z axis)
	var quad = QuadMesh.new()
	quad.size = Vector2(weapon_data.laser_head_radius * 2.0, weapon_data.laser_length)
	quad.orientation = PlaneMesh.FACE_Z
	mesh_instance.mesh = quad

	# Create material with laser texture
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.albedo_color = weapon_data.laser_color if weapon_data.laser_color else Color.RED

	if weapon_data.laser_bitmap:
		material.albedo_texture = weapon_data.laser_bitmap

	if weapon_data.laser_glow:
		material.emission_enabled = true
		material.emission = weapon_data.laser_color if weapon_data.laser_color else Color.RED
		material.emission_energy_multiplier = 2.0

	mesh_instance.material_override = material

	# Position mesh so it extends forward from origin
	mesh_instance.position.z = -weapon_data.laser_length / 2.0

	add_child(mesh_instance)


func setup(
	origin: Vector3, initial_velocity: Vector3, shooter: Node3D, _target: Node3D = null
) -> void:
	global_position = origin
	fired_by = shooter
	target = _target

	if "team" in shooter:
		team = shooter.team

	# Combine muzzle velocity with shooter velocity
	var muzzle_speed = weapon_data.velocity_mps if weapon_data else 100.0
	var forward_dir = -global_transform.basis.z
	velocity = initial_velocity + (forward_dir * muzzle_speed)

	look_at(global_position + velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	if weapon_data:
		life_time += delta
		if life_time >= weapon_data.lifetime:
			_on_lifetime_expired()
			return

	# Update Position
	var step = velocity * delta

	# Simple collision check (RayCast or ShapeCast is better for high speed, but Area3D is acceptable for now)
	# For high speed projectiles, we might want to raycast the step
	_handle_movement(step)


func _handle_movement(step: Vector3) -> void:
	# Basic movement - override in subclasses for guidance
	global_position += step


func _on_body_entered(body: Node3D) -> void:
	if body == fired_by:
		return  # Don't hit yourself immediately

	_detonate(body)


func _detonate(hit_object: Node3D = null) -> void:
	# Arming Checks
	if weapon_data:
		if life_time < weapon_data.arm_time:
			print("DEBUG: Weapon hit before arm time (Dummy Hit)")
			queue_free()
			return

		# If we have a shooter, check arm distance
		if fired_by and is_instance_valid(fired_by):
			var dist = global_position.distance_to(fired_by.global_position)
			if dist < weapon_data.arm_dist:
				print("DEBUG: Weapon hit inside arm distance (Dummy Hit)")
				queue_free()
				return

	weapon_detonated.emit(global_position)

	if weapon_data.flags & WCSWeaponData.WeaponFlags.PARTICLE_SPEW:
		_spawn_particle_spew()

	if hit_object and weapon_data:
		# Apply damage
		if hit_object.has_method("take_damage"):
			var damage_info = weapon_data.calculate_damage_against_target(
				"Unknown", 1.0, 100.0, global_position, 0.0, velocity.length()  # Needs species from target  # Target Armor  # Target Shield  # Impact Angle
			)

			# Inject Effects
			if weapon_data.flags & WCSWeaponData.WeaponFlags.ENERGY_SUCK:
				# Use total damage as base for suck amount if not specified otherwise
				damage_info["energy_suck"] = damage_info.get("total_damage", 0.0)

			if weapon_data.flags & WCSWeaponData.WeaponFlags.EMP:
				damage_info["emp"] = {
					"intensity": weapon_data.emp_intensity, "time": weapon_data.emp_time
				}

			if weapon_data.flags & WCSWeaponData.WeaponFlags.ELECTRONICS:
				damage_info["electronics"] = true

			hit_object.take_damage(damage_info, fired_by)

	queue_free()


func _on_lifetime_expired() -> void:
	weapon_expired.emit()
	queue_free()


func _spawn_particle_spew() -> void:
	if not weapon_data or not weapon_data.particle_spew:
		return

	# Placeholder for particle spew implementation
	# Ideally instantiate a GPUParticles3D or custom scene
	print(
		(
			"DEBUG: Spawning particle spew: Count="
			+ str(weapon_data.particle_spew.count)
			+ " Bitmap="
			+ weapon_data.particle_spew.bitmap
		)
	)
