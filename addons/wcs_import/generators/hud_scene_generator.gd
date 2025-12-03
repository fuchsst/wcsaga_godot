class_name HudSceneGenerator
extends RefCounted

const HudGaugeResource = preload("res://scripts/resources/ui/hud/hud_gauge_resource.gd")


func create_custom_gauges_scene(gauges: Array[HudGaugeResource], output_dir: String) -> void:
	_create_scene(gauges, output_dir.path_join("cockpits/custom_gauges.tscn"), "CustomGauges")


func create_main_gauges_scene(gauges: Array[HudGaugeResource], output_dir: String) -> void:
	_create_scene(gauges, output_dir.path_join("cockpits/main_gauges.tscn"), "MainGauges")


func create_gauges_scene(gauges: Array[HudGaugeResource], output_dir: String) -> void:
	_create_scene(gauges, output_dir.path_join("cockpits/gauges.tscn"), "Gauges")


func create_ship_scenes(ship_gauges: Dictionary, output_dir: String, is_main: bool) -> void:
	for ship_name in ship_gauges:
		var gauges = ship_gauges[ship_name]
		var safe_ship_name = ship_name.to_lower().replace(" ", "_").replace(".", "_")
		var subfolder = "main_gauges.tscn" if is_main else "gauges.tscn"
		var path = output_dir.path_join("cockpits/ship_gauges").path_join(safe_ship_name).path_join(
			subfolder
		)
		var root_name = "ShipMainGauges" if is_main else "ShipGauges"
		_create_scene(gauges, path, root_name)


func _create_scene(gauges: Array[HudGaugeResource], path: String, root_name: String) -> void:
	var root = Node2D.new()
	root.name = root_name

	# Map names to nodes for parenting
	var node_map = {}
	var nodes_to_add = []

	# First pass: Create all nodes
	for gauge in gauges:
		var node = Node2D.new()
		node.name = gauge.name if not gauge.name.is_empty() else "Gauge"
		node.position = Vector2(gauge.position)

		# Store metadata/properties if needed, or attach a script/resource
		# For now, we just create the hierarchy and position
		# We could attach the resource as metadata
		node.set_meta("gauge_resource", gauge)

		node_map[gauge.name] = node
		nodes_to_add.append({"node": node, "parent": gauge.parent})

		# Handle sub-gauges recursively (simplified for 1 level)
		for sub in gauge.sub_gauges:
			var sub_node = Node2D.new()
			sub_node.name = sub.name
			sub_node.position = Vector2(sub.position)
			sub_node.set_meta("gauge_resource", sub)
			node.add_child(sub_node)

	# Second pass: Build hierarchy
	for item in nodes_to_add:
		var node = item.node
		var parent_name = item.parent

		if not parent_name.is_empty() and node_map.has(parent_name):
			node_map[parent_name].add_child(node)
		else:
			root.add_child(node)

	# Set owner for all nodes to root (required for PackedScene)
	_set_owner_recursive(root, root)

	# Save scene
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(root)
	if result == OK:
		var dir = path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)

		var err = ResourceSaver.save(packed_scene, path)
		if err == OK:
			print("Saved scene: " + path)
		else:
			print("Failed to save scene: " + path)
	else:
		print("Failed to pack scene: " + root_name)

	root.free()


func generate(gauges: Array[HudGaugeResource], output_dir: String, source_root: String) -> bool:
	var assets_dir = output_dir
	if not DirAccess.dir_exists_absolute(assets_dir):
		DirAccess.make_dir_recursive_absolute(assets_dir)

	# Group gauges by section
	var sections = {
		"Custom Gauges": [] as Array[HudGaugeResource],
		"Main Gauges": [] as Array[HudGaugeResource],
		"Gauges": [] as Array[HudGaugeResource],
		"Ship Main Gauges": {},
		"Ship Gauges": {}
	}

	for gauge in gauges:
		# Convert assets first
		_convert_hud_gauge_assets(gauge, source_root, assets_dir)

		if gauge.section == "Custom Gauges":
			sections["Custom Gauges"].append(gauge)
		elif gauge.section == "Main Gauges":
			sections["Main Gauges"].append(gauge)
		elif gauge.section == "Gauges":
			sections["Gauges"].append(gauge)
		elif gauge.section == "Ship Main Gauges":
			var ship = gauge.ship_name
			if ship.is_empty():
				ship = "generic"
			if not sections["Ship Main Gauges"].has(ship):
				sections["Ship Main Gauges"][ship] = [] as Array[HudGaugeResource]
			sections["Ship Main Gauges"][ship].append(gauge)
		elif gauge.section == "Ship Gauges":
			var ship = gauge.ship_name
			if ship.is_empty():
				ship = "generic"
			if not sections["Ship Gauges"].has(ship):
				sections["Ship Gauges"][ship] = [] as Array[HudGaugeResource]
			sections["Ship Gauges"][ship].append(gauge)

	create_custom_gauges_scene(sections["Custom Gauges"], output_dir)
	create_main_gauges_scene(sections["Main Gauges"], output_dir)
	create_gauges_scene(sections["Gauges"], output_dir)

	create_ship_scenes(sections["Ship Main Gauges"], output_dir, true)
	create_ship_scenes(sections["Ship Gauges"], output_dir, false)

	print("Generated HUD scenes.")
	return true


func _convert_hud_gauge_assets(gauge: Resource, source_root: String, output_dir: String) -> void:
	if not gauge.image.is_empty():
		var source_file = _find_source_asset(
			source_root, gauge.image, [".pcx", ".dds", ".png", ".ani", ".eff"]
		)
		if not source_file.is_empty():
			var type = "texture"
			if source_file.ends_with(".ani") or source_file.ends_with(".eff"):
				type = "animation"

			_convert_asset(source_file, output_dir, type)

			# Update image path to converted file (basename + .png for textures/animations)
			gauge.image = source_file.get_file().get_basename() + ".png"
		else:
			print("Warning: Could not find source for HUD gauge image: " + gauge.image)

	for sub in gauge.sub_gauges:
		_convert_hud_gauge_assets(sub, source_root, output_dir)


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


func _set_owner_recursive(node: Node, root: Node) -> void:
	if node != root:
		node.owner = root
	for child in node.get_children():
		_set_owner_recursive(child, root)
