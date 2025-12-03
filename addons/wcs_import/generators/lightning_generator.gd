class_name LightningGenerator
extends RefCounted

## Generates Lightning Resources from parsed TBL data
## Handles saving resources to correct subfolders (bolts/storms).

const LightningResource = preload("res://scripts/resources/effects/lightning_resource.gd")


func generate(resource: LightningResource, output_dir: String, source_root: String) -> bool:
	var subfolder = "bolts"
	if resource.type == LightningResource.LightningType.STORM:
		subfolder = "storms"

	var target_dir = output_dir.path_join(subfolder)
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)

	var filename = resource.name
	if filename.is_empty():
		filename = "unknown_lightning"

	# Convert animation
	var source_file = _find_source_asset(source_root, resource.name, [".ani", ".eff"])
	if not source_file.is_empty():
		_convert_asset(source_file, target_dir, "animation")
	else:
		# Only warn if it's not a storm (storms might not have direct assets same way)
		# But usually they do.
		pass

	# 1. Save Resource (.tres)
	var tres_path = target_dir.path_join(filename + ".tres")
	var err = ResourceSaver.save(resource, tres_path)
	if err != OK:
		push_error("Failed to save lightning resource: " + tres_path)
		return false

	# 2. Generate Scene (.tscn)
	# We manually construct the TSCN content to ensure correct references without loading

	# Calculate res:// path for the resource
	var res_path = tres_path
	var project_root = ProjectSettings.globalize_path("res://")
	if tres_path.begins_with(project_root):
		res_path = tres_path.replace(project_root, "res://")
	elif tres_path.find("/target/") != -1:
		var idx = tres_path.find("/target/")
		res_path = "res://" + tres_path.substr(idx + 8)

	# Get UID if possible (optional, but good for references)
	var uid_str = ""
	# We can't easily get the UID of the just-saved resource without re-scanning or reading the file
	# For simplicity, we'll omit UID for now or try to read it
	var uid = _get_uid(tres_path)
	if not uid.is_empty():
		uid_str = ' uid="uid://' + uid + '"'

	var tscn_content = (
		"""[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/entities/effects/lightning.gd" id="1_script"]
[ext_resource type="Resource"%s path="%s" id="2_resource"]

[node name="%s" type="Node3D"]
script = ExtResource("1_script")
resource = ExtResource("2_resource")
"""
		% [uid_str, res_path, filename]
	)

	var tscn_path = target_dir.path_join(filename + ".tscn")
	var file = FileAccess.open(tscn_path, FileAccess.WRITE)
	if file:
		file.store_string(tscn_content)
		file.close()
	else:
		push_error("Failed to write TSCN: " + tscn_path)
		return false

	return true


func _get_uid(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		# Read first few lines to find uid
		for i in range(5):
			var line = file.get_line()
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
