class_name FireballGenerator
extends RefCounted

## Generates Fireball Scenes from parsed TBL data
## Creates a scene with an AnimatedSprite3D using the converted spritesheet.

const FireballResource = preload("res://scripts/resources/effects/fireball_resource.gd")
const FireballScript = preload("res://scripts/entities/effects/fireball.gd")


func generate(resource: FireballResource, output_dir: String, source_root: String) -> bool:
	var fireball_name = resource.name
	if fireball_name.is_empty():
		fireball_name = "unknown"

	print("Generating fireball: ", fireball_name)

	# Create specific output directory for assets
	var asset_dir = output_dir.path_join(fireball_name)
	if not DirAccess.dir_exists_absolute(asset_dir):
		DirAccess.make_dir_recursive_absolute(asset_dir)

	# Convert animation
	var source_file = _find_source_asset(source_root, fireball_name, [".ani", ".eff"])
	if not source_file.is_empty():
		if fireball_name == "empty":
			print("Using shared empty resource for fireball: empty")
		else:
			_convert_asset(source_file, asset_dir, "animation")
	else:
		print("Warning: Could not find source for fireball: " + fireball_name)

	# 1. Save Data Resource
	# We already have the resource, just save it

	# Save Resource
	# Use _data suffix to avoid collision with the spritesheet resource which might be named <name>.tres
	var tres_path = asset_dir.path_join(fireball_name + "_data.tres")
	var err = ResourceSaver.save(resource, tres_path)
	if err != OK:
		print("ERROR: Failed to save resource: ", tres_path)
		return false

	# Manual .tscn generation to avoid load() issues
	var sequence_path = asset_dir.path_join(fireball_name + ".tres")
	if fireball_name == "empty":
		sequence_path = "res://assets/shared/empty.tres"

	# Convert absolute path to res:// path
	var res_path = sequence_path
	var project_root = ProjectSettings.globalize_path("res://")
	if sequence_path.begins_with(project_root):
		res_path = sequence_path.replace(project_root, "res://")
	elif sequence_path.find("/target/") != -1:
		var idx = sequence_path.find("/target/")
		res_path = "res://" + sequence_path.substr(idx + 8)

	var uid = _get_uid(sequence_path)
	var uid_str = ""
	if not uid.is_empty():
		uid_str = ' uid="uid://' + uid + '"'

	var tscn_content = (
		"""[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/entities/effects/fireball.gd" id="1_script"]
[ext_resource type="SpriteFrames"%s path="%s" id="2_frames"]

[node name="%s" type="Node3D"]
script = ExtResource("1_script")

[node name="AnimatedSprite3D" type="AnimatedSprite3D" parent="."]
sprite_frames = ExtResource("2_frames")
pixel_size = 0.1
billboard = 1
"""
		% [uid_str, res_path, fireball_name]
	)

	var tscn_path = asset_dir.path_join(fireball_name + ".tscn")
	var file = FileAccess.open(tscn_path, FileAccess.WRITE)
	if file:
		file.store_string(tscn_content)
		file.close()
		print("Saved TSCN: ", tscn_path)
	else:
		print("ERROR: Failed to write TSCN: ", tscn_path)
		return false

	return true


func _get_uid(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var line = file.get_line()
		# [gd_resource type="SpriteFrames" load_steps=39 format=3 uid="uid://a9912ea9691d"]
		var regex = RegEx.new()
		regex.compile('uid="uid://([^"]+)"')
		var result = regex.search(line)
		if result:
			return result.get_string(1)
	return ""


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
		"run", "--directory", "..", "python", "-m", "converter", global_source, global_target, "--type", type
	]

	var output = []
	var exit_code = OS.execute("uv", args, output, true)

	if exit_code != 0:
		print("Conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false

	return true
