class_name AsteroidGenerator
extends RefCounted

## Generates Asteroid Scenes from parsed TBL data
## Handles creation of AsteroidData resources, AsteroidBehavior nodes, and GLTF model instantiation.

const AsteroidData = preload("res://scripts/resources/asteroids/asteroid_data.gd")
const Asteroid = preload("res://scripts/entities/asteroid/asteroid.gd")


func generate(data: Dictionary, output_dir: String, source_root: String) -> bool:
	var asteroid_id = data.get("resource_identifier", "unknown")
	var asteroid_name = data.get("asteroid_name", "Unknown Asteroid")

	print("Generating asteroid: ", asteroid_name, " (", asteroid_id, ")")

	# Create specific output directory for assets
	var asset_dir = output_dir.path_join(asteroid_id)
	if not DirAccess.dir_exists_absolute(asset_dir):
		DirAccess.make_dir_recursive_absolute(asset_dir)

	# Convert POFs first
	var pof_keys = ["pof_file_lod0", "pof_file_lod1", "pof_file_lod2"]
	for key in pof_keys:
		if data.has(key):
			var pof_file = data[key]
			if not pof_file.is_empty() and pof_file != "none":
				var source_file = _find_source_asset(source_root, pof_file)
				if not source_file.is_empty():
					_convert_asset(source_file, asset_dir, "model")
				else:
					print("Warning: Could not find source for asteroid POF: " + pof_file)

	# 1. Create Data Resource
	var resource = AsteroidData.new()
	resource.asteroid_name = asteroid_name
	resource.resource_identifier = asteroid_id

	# Map properties
	if data.has("lod_distances"):
		resource.lod_distances = data["lod_distances"]
	if data.has("max_speed"):
		resource.max_speed = data["max_speed"]
	if data.has("hitpoints"):
		resource.hitpoints = data["hitpoints"]
	if data.has("explosion_inner_radius"):
		resource.explosion_inner_radius = data["explosion_inner_radius"]
	if data.has("explosion_outer_radius"):
		resource.explosion_outer_radius = data["explosion_outer_radius"]
	if data.has("explosion_damage"):
		resource.explosion_damage = data["explosion_damage"]
	if data.has("explosion_blast"):
		resource.explosion_blast = data["explosion_blast"]
	if data.has("impact_explosion_effect"):
		resource.impact_explosion_effect = data["impact_explosion_effect"]
	if data.has("impact_explosion_radius"):
		resource.impact_explosion_radius = data["impact_explosion_radius"]

	# Save Resource
	var tres_path = asset_dir.path_join(asteroid_id + ".tres")
	var err = ResourceSaver.save(resource, tres_path)
	if err != OK:
		print("ERROR: Failed to save resource: ", tres_path)
		return false
	print("Saved TRES: ", tres_path)

	# 2. Create Scene
	var root = RigidBody3D.new()
	root.name = asteroid_name

	# Attach behavior script
	root.set_script(Asteroid)
	root.asteroid_data = resource

	# Add Collision Shape (Placeholder - Sphere)
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 10.0  # Default
	collision.shape = shape
	collision.name = "CollisionShape3D"
	root.add_child(collision)
	collision.owner = root

	# Add variations
	var variation_nodes: Array[Node3D] = []

	for i in range(pof_keys.size()):
		var key = pof_keys[i]
		if not data.has(key):
			continue

		var pof_file = data[key]
		if pof_file.is_empty() or pof_file == "none":
			continue

		var pof_basename = pof_file.get_basename()
		var gltf_path = asset_dir.path_join(pof_basename + ".gltf")

		# Load GLTF scene using GLTFDocument (bypasses need for editor import)
		if not FileAccess.file_exists(gltf_path):
			print("WARNING: Model file not found: ", gltf_path)
			continue

		var gltf = GLTFDocument.new()
		var state = GLTFState.new()
		var gltf_err = gltf.append_from_file(gltf_path, state)

		if gltf_err == OK:
			var instance = gltf.generate_scene(state)
			instance.name = "Variation_" + str(i)
			root.add_child(instance)
			instance.owner = root
			variation_nodes.append(instance)

			# Update collision radius from first variation
			if i == 0:
				shape.radius = 20.0  # Placeholder - ideally calculated from AABB

			# Hide by default (except first one)
			instance.visible = (i == 0)
		else:
			print("ERROR: Failed to load GLTF: ", gltf_path, " Error code: ", gltf_err)

	# Assign variation nodes to script property
	root.variations = variation_nodes

	# Pack scene
	var scene = PackedScene.new()
	var pack_result = scene.pack(root)
	if pack_result == OK:
		var tscn_path = asset_dir.path_join(asteroid_id + ".tscn")
		var save_err = ResourceSaver.save(scene, tscn_path)
		if save_err != OK:
			print("ERROR saving TSCN ", tscn_path, ": ", save_err)
			root.free()
			return false
		else:
			print("Saved TSCN: ", tscn_path)
	else:
		print("ERROR packing scene for ", asteroid_id)
		root.free()
		return false

	root.free()
	return true


func _find_source_asset(root_path: String, filename: String, extensions: Array = []) -> String:
	var found = _find_file_recursive(root_path, filename)
	if found.is_empty() and not extensions.is_empty():
		var basename = filename.get_basename()
		for ext in extensions:
			found = _find_file_recursive(root_path, basename + ext)
			if not found.is_empty():
				break
	return found


func _find_file_recursive(dir_path: String, filename: String) -> String:
	if not DirAccess.dir_exists_absolute(dir_path):
		return ""

	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					var sub_path = dir_path.path_join(file_name)
					var found = _find_file_recursive(sub_path, filename)
					if not found.is_empty():
						return found
			else:
				if file_name.to_lower() == filename.to_lower():
					return dir_path.path_join(file_name)
			file_name = dir.get_next()
	return ""


func _convert_asset(source_path: String, target_dir: String, type: String) -> bool:
	var global_source = ProjectSettings.globalize_path(source_path)
	var global_target = ProjectSettings.globalize_path(target_dir)

	var args = [
		"run", "python", "-m", "converter", "convert", global_source, global_target, "--type", type
	]

	var output = []
	var exit_code = OS.execute("uv", args, output, true)

	if exit_code != 0:
		print("Conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false

	return true
