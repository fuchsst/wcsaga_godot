class_name WeaponSceneGenerator
extends RefCounted

const WCSWeaponData = preload("res://scripts/resources/weapons/weapon_data.gd")
const Weapon = preload("res://scripts/entities/weapons/base_weapon.gd")
const Missile = preload("res://scripts/entities/weapons/missile_weapon.gd")
const Projectile = preload("res://scripts/entities/weapons/projectile_weapon.gd")
const BeamWeapon = preload("res://scripts/entities/weapons/beam_weapon.gd")
const FlakWeapon = preload("res://scripts/entities/weapons/flak_weapon.gd")


func generate_scene(weapon_data: WCSWeaponData, output_root: String) -> void:
	# Determine folder structure: target/assets/weapons/<category>/<faction>/<weapon>/
	# The parser now populates category and manufacturer_species based on path mapping rules
	var category_slug = weapon_data.category.to_lower().replace(" ", "_")
	var faction_slug = weapon_data.manufacturer_species.to_lower()

	if faction_slug.is_empty() or faction_slug == "unknown":
		faction_slug = "common"

	var weapon_slug = weapon_data.id.to_lower().replace(" ", "_")

	var target_dir = output_root.path_join(category_slug).path_join(faction_slug).path_join(
		weapon_slug
	)

	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)

	# Save Resource
	var resource_path = target_dir.path_join(weapon_slug + ".tres")
	ResourceSaver.save(weapon_data, resource_path)
	weapon_data.take_over_path(resource_path)
	print("Saved weapon resource to: " + resource_path)

	# Create Scene - determine weapon type correctly
	var root_node: Node3D
	
	if weapon_data.is_beam:
		root_node = BeamWeapon.new()
		root_node.name = "BeamWeapon"
	elif weapon_data.flak_config != null:
		root_node = FlakWeapon.new()
		root_node.name = "FlakWeapon"
	elif weapon_data.homing_type > 0:
		root_node = Missile.new()
		root_node.name = "MissileWeapon"
	else:
		root_node = Projectile.new()
		root_node.name = "ProjectileWeapon"

	root_node.weapon_data = weapon_data

	# Add collision area for projectile detection
	var collision_area = Area3D.new()
	collision_area.name = "HitArea"
	collision_area.collision_layer = 0 # Will be set at runtime based on team
	collision_area.collision_mask = 0 # Will be set at runtime
	collision_area.monitorable = true
	collision_area.monitoring = true
	root_node.add_child(collision_area)
	collision_area.owner = root_node
	
	# Add collision shape to the area
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	
	# Size based on weapon radius or default
	var sphere_shape = SphereShape3D.new()
	if weapon_data.collision_radius > 0:
		sphere_shape.radius = weapon_data.collision_radius
	else:
		sphere_shape.radius = 0.5 # Default projectile radius
	collision_shape.shape = sphere_shape
	
	collision_area.add_child(collision_shape)
	collision_shape.owner = root_node

	# Instantiate Visuals from model if available
	if (
		not weapon_data.projectile_model.is_empty()
		and weapon_data.projectile_model.ends_with(".glb")
	):
		var model_path = target_dir.path_join(weapon_data.projectile_model)
		if FileAccess.file_exists(model_path):
			var model_scene = load(model_path)
			if model_scene:
				var model_instance = model_scene.instantiate()
				root_node.add_child(model_instance)
				model_instance.owner = root_node
				model_instance.name = "Visuals"
		else:
			print("Warning: Model file not found at " + model_path)

	# Pack and Save Scene
	var packed_scene = PackedScene.new()
	packed_scene.pack(root_node)

	var scene_path = target_dir.path_join(weapon_slug + ".tscn")
	ResourceSaver.save(packed_scene, scene_path)
	print("Saved weapon scene to: " + scene_path)

	root_node.free()
