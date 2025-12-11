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
		resource.impact_effect = data["impact_explosion_effect"]

	# Save Resource
	var tres_path = asset_dir.path_join(asteroid_id + ".tres")
	print("DEBUG: Attempting to save TRES to: ", tres_path)
	var err = ResourceSaver.save(resource, tres_path)
	if err != OK:
		print("ERROR: Failed to save resource: ", tres_path, " - Error code: ", err)
		return false
	print("Saved TRES: ", tres_path, " - Error code: ", err)

	# 2. Create Scene using text-based generation for proper script attachment
	# This avoids issues with PackedScene.pack() not serializing scripts in headless mode

	# Build model references
	var model_paths: Array[String] = []
	for i in range(pof_keys.size()):
		var key = pof_keys[i]
		if not data.has(key):
			continue
		var pof_file = data[key]
		if pof_file.is_empty() or pof_file == "none":
			continue
		var pof_basename = pof_file.get_basename()
		var gltf_path = asset_dir.path_join(pof_basename + ".gltf")
		if FileAccess.file_exists(gltf_path):
			model_paths.append(gltf_path)

	# Generate scene text
	var tscn_content = _generate_asteroid_scene_text(
		asteroid_name, asteroid_id, tres_path, model_paths, asset_dir
	)

	# Write scene file
	var tscn_path = asset_dir.path_join(asteroid_id + ".tscn")
	var file = FileAccess.open(tscn_path, FileAccess.WRITE)
	if file:
		file.store_string(tscn_content)
		file.close()
		print("Saved TSCN: ", tscn_path)
	else:
		print("ERROR: Failed to write TSCN: ", tscn_path)
		return false

	return true


func _generate_asteroid_scene_text(
	asteroid_name: String,
	_asteroid_id: String,
	resource_path: String,
	model_paths: Array[String],
	asset_dir: String
) -> String:
	var lines: Array[String] = []

	# Calculate load steps: script + resource + shape + models
	var load_steps = 3 + model_paths.size()

	# Header
	lines.append("[gd_scene load_steps=%d format=3]" % load_steps)
	lines.append("")

	# External resources
	var ext_id = 1
	(
		lines
		.append(
			(
				'[ext_resource type="Script" path="res://scripts/entities/asteroid/asteroid.gd" id="script_%d"]'
				% ext_id
			)
		)
	)
	var script_id = "script_%d" % ext_id
	ext_id += 1

	# Resource path - convert to res://
	var res_resource_path = _to_res_path(resource_path, asset_dir)
	lines.append(
		(
			'[ext_resource type="Resource" path="%s" id="asteroid_data_%d"]'
			% [res_resource_path, ext_id]
		)
	)
	var data_id = "asteroid_data_%d" % ext_id
	ext_id += 1

	# Model resources
	var model_ids: Array[String] = []
	for model_path in model_paths:
		var res_model_path = _to_res_path(model_path, asset_dir)
		lines.append(
			'[ext_resource type="PackedScene" path="%s" id="model_%d"]' % [res_model_path, ext_id]
		)
		model_ids.append("model_%d" % ext_id)
		ext_id += 1

	lines.append("")

	# Sub-resources
	lines.append('[sub_resource type="SphereShape3D" id="SphereShape3D_collision"]')
	lines.append("radius = 10.0")
	lines.append("")

	# Root node
	lines.append('[node name="%s" type="RigidBody3D"]' % asteroid_name)
	lines.append('script = ExtResource("%s")' % script_id)
	lines.append('asteroid_data = ExtResource("%s")' % data_id)
	lines.append("")

	# Collision shape
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="."]')
	lines.append('shape = SubResource("SphereShape3D_collision")')
	lines.append("")

	# Model instances
	for i in range(model_ids.size()):
		var visible = "true" if i == 0 else "false"
		lines.append(
			'[node name="Variation_%d" parent="." instance=ExtResource("%s")]' % [i, model_ids[i]]
		)
		if i > 0:
			lines.append("visible = false")
		lines.append("")

	return "\n".join(lines)


func _to_res_path(abs_path: String, _asset_dir: String) -> String:
	var project_root = ProjectSettings.globalize_path("res://")
	if abs_path.begins_with(project_root):
		return abs_path.replace(project_root, "res://")
	# Fallback: find /target/ in path
	var idx = abs_path.find("/target/")
	if idx != -1:
		return "res://" + abs_path.substr(idx + 8)
	return abs_path


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
		"run",
		"--directory",
		"..",
		"python",
		"-m",
		"converter",
		global_source,
		global_target,
		"--type",
		type,
		"--no-model-data"
	]

	var output = []
	var exit_code = OS.execute("uv", args, output, true)

	if exit_code != 0:
		print("Conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false

	return true
