class_name Weapon
extends Area3D

# Base class for all projectile weapons

signal hit_target(target, damage_info)
signal expired()

@export var weapon_data: WCSWeaponData
var shooter: Node3D # The ship that fired this weapon
var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 0.0
var damage_multiplier: float = 1.0

func _ready() -> void:
	if weapon_data:
		lifetime = weapon_data.projectile_lifetime
		
		# Setup collision
		body_entered.connect(_on_body_entered)
		area_entered.connect(_on_area_entered)
		
		# Setup visual
		_setup_visuals()

func _physics_process(delta: float) -> void:
	# Move projectile
	global_position += velocity * delta
	
	# Handle lifetime
	lifetime -= delta
	if lifetime <= 0:
		expire()

func initialize(data: WCSWeaponData, source: Node3D, start_pos: Vector3, start_rot: Quaternion, initial_velocity: Vector3) -> void:
	weapon_data = data
	shooter = source
	global_position = start_pos
	global_rotation = start_rot.get_euler() # Godot uses Euler for rotation property
	
	# Calculate velocity vector
	var forward = - global_transform.basis.z
	velocity = initial_velocity + (forward * weapon_data.muzzle_velocity_mps)

func _setup_visuals() -> void:
	# Load model or create sprite based on weapon_data
	# Load model or create sprite based on weapon_data
	if has_node("Visuals"):
		return # Already set up by generator

	if not weapon_data.projectile_model.is_empty() and weapon_data.projectile_model != "none":
		# Model should be instantiated by the generator as a child node named "Visuals"
		pass
	elif not weapon_data.laser_bitmap.is_empty():
		# Create laser sprite/mesh
		# For now, just a placeholder mesh
		var mesh_instance = MeshInstance3D.new()
		var mesh = CapsuleMesh.new()
		mesh.radius = weapon_data.laser_head_radius
		mesh.height = weapon_data.laser_length_meters
		mesh_instance.mesh = mesh
		
		# Rotate to align with Z axis
		mesh_instance.rotation_degrees.x = 90
		
		# Apply color
		var material = StandardMaterial3D.new()
		material.albedo_color = weapon_data.laser_primary_color
		material.emission_enabled = true
		material.emission = weapon_data.laser_primary_color
		material.emission_energy_multiplier = 2.0
		mesh_instance.material_override = material
		
		add_child(mesh_instance)

func _on_body_entered(body: Node3D) -> void:
	if body == shooter:
		return # Don't hit self immediately (needs safer check for large ships)
		
	_apply_damage(body)
	expire()

func _on_area_entered(area: Area3D) -> void:
	# Handle hitting shields or other areas
	pass

func _apply_damage(target: Node3D) -> void:
	# Calculate damage using WeaponData's logic
	# This requires target to have specific methods or properties
	# For now, just emit signal
	var impact_velocity = velocity.length()
	var impact_angle = 0.0 # Calculate angle
	
	# Mock target data for now
	var damage_info = weapon_data.calculate_damage_against_target(
		"Terran", # Target species
		100.0, # Armor
		100.0, # Shield
		to_local(target.global_position), # Impact point local
		impact_angle,
		impact_velocity
	)
	
	hit_target.emit(target, damage_info)
	
	# If target has a 'take_damage' method, call it
	if target.has_method("take_damage"):
		target.take_damage(damage_info)

func expire() -> void:
	expired.emit()
	queue_free()
