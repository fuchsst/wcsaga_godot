class_name WeaponSceneGenerator
extends RefCounted

const WCSWeaponData = preload("res://scripts/resources/weapons/weapon_data.gd")
const Weapon = preload("res://scripts/entities/weapon.gd")
const Missile = preload("res://scripts/entities/missile.gd")
const BeamWeapon = preload("res://scripts/entities/beam_weapon.gd")

func generate_scene(weapon_data: WCSWeaponData, output_root: String) -> void:
	# Determine folder structure: target/assets/weapons/<category>/<faction>/<weapon>/
	var category_slug = weapon_data.category.to_lower().replace(" ", "_")
	var faction_slug = weapon_data.manufacturer_species.to_lower()
	if faction_slug.is_empty():
		faction_slug = "common"
	var weapon_slug = weapon_data.weapon_class
	
	var target_dir = output_root.path_join(category_slug).path_join(faction_slug).path_join(weapon_slug)
	
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
	elif weapon_data.homing_type > 0:
		root_node = Missile.new()
		root_node.name = "Missile"
	else:
		root_node = Weapon.new()
		root_node.name = "Weapon"
		
	root_node.weapon_data = weapon_data
	
	# Add visual placeholder (MeshInstance3D)
	# In a real scenario, we would load the GLB if available
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Visual"
	root_node.add_child(mesh_instance)
	mesh_instance.owner = root_node
	
	# Pack and Save Scene
	var packed_scene = PackedScene.new()
	packed_scene.pack(root_node)
	
	var scene_path = target_dir.path_join(weapon_slug + ".tscn")
	ResourceSaver.save(packed_scene, scene_path)
	print("Saved weapon scene to: " + scene_path)
	
	root_node.free()
