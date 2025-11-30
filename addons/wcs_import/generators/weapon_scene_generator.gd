class_name WeaponSceneGenerator
extends RefCounted

const WCSWeaponData = preload("res://scripts/resources/weapons/weapon_data.gd")
const Weapon = preload("res://scripts/entities/weapon.gd")
const Missile = preload("res://scripts/entities/missile.gd")
const BeamWeapon = preload("res://scripts/entities/beam_weapon.gd")
const FlakWeapon = preload("res://scripts/entities/flak_weapon.gd")


func generate_scene(weapon_data: WCSWeaponData, output_root: String) -> void:
	# Determine folder structure: target/assets/weapons/<category>/<faction>/<weapon>/
	# The parser now populates category and manufacturer_species based on path mapping rules
	var category_slug = weapon_data.category.to_lower().replace(" ", "_")
	var faction_slug = weapon_data.manufacturer_species.to_lower()

	if faction_slug.is_empty() or faction_slug == "unknown":
		faction_slug = "common"

	var weapon_slug = weapon_data.weapon_class.to_lower().replace(" ", "_")

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

	# Create Scene
	var root_node: Node3D

	if weapon_data.is_beam:
		root_node = BeamWeapon.new()
		root_node.name = "BeamWeapon"
	elif weapon_data.flak_config != null:
		root_node = FlakWeapon.new()
		root_node.name = "FlakWeapon"
	elif weapon_data.homing_type > 0:
		root_node = Missile.new()
		root_node.name = "Missile"
	else:
		root_node = Weapon.new()
		root_node.name = "Weapon"

	root_node.weapon_data = weapon_data

	# 5. Instantiate Visuals
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
