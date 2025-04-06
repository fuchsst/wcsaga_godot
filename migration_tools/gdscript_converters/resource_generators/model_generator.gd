@tool # Allows running from editor/command line
extends EditorScript

# Generates Model Scenes (.tscn) and ModelMetadata resources (.tres)
# from GLB models and JSON metadata.

# --- Configuration ---
const CONVERTED_MODEL_DIR = "res://assets/models" # Input dir (output from Python converters)
const OUTPUT_MODEL_META_RES_DIR = "res://resources/model_metadata" # Output dir for .tres files
const OUTPUT_MODEL_SCENE_DIR = "res://scenes/ships_weapons" # Output dir for .tscn files

# Preload necessary resource scripts/classes
const PackedScene = preload("PackedScene") # Built-in
const Node3D = preload("Node3D") # Built-in
const Marker3D = preload("Marker3D") # Built-in
const ModelMetadata = preload("res://scripts/resources/object/model_metadata.gd")
# TODO: Preload specific data resources if ModelMetadata uses them (e.g., DockPointData)
# const DockPointData = preload("res://scripts/resources/mission/dock_point_data.gd")
# const ThrusterData = preload("...") # Add other necessary data types

var force_overwrite: bool = false

# --- Main Execution ---
func _run():
	print("Generating Model Scenes and Metadata...")
	var args = OS.get_cmdline_args()
	if "--force" in args:
		force_overwrite = true
		print("  Force overwrite enabled.")

	var processed_count = 0
	var skipped_count = 0
	var error_count = 0

	var dir = DirAccess.open(CONVERTED_MODEL_DIR)
	if not dir:
		printerr(f"Error: Could not open model directory: {CONVERTED_MODEL_DIR}")
		return

	# Ensure output directories exist
	DirAccess.make_dir_recursive_absolute(OUTPUT_MODEL_META_RES_DIR)
	DirAccess.make_dir_recursive_absolute(OUTPUT_MODEL_SCENE_DIR)

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var json_path = CONVERTED_MODEL_DIR.path_join(file_name)
			var base_name = file_name.get_basename().replace(".json", "")
			var glb_path = base_name + ".glb" # Assumes GLB exists with same base name
			var glb_full_path = CONVERTED_MODEL_DIR.path_join(glb_path)

			if not FileAccess.file_exists(glb_full_path):
				printerr(f"Error: GLB model not found for JSON: {json_path} (Expected: {glb_full_path})")
				error_count += 1
				file_name = dir.get_next()
				continue

			var output_meta_path = OUTPUT_MODEL_META_RES_DIR.path_join(base_name + "_meta.tres")
			var output_scene_path = OUTPUT_MODEL_SCENE_DIR.path_join(base_name + ".tscn")

			if FileAccess.file_exists(output_meta_path) and FileAccess.file_exists(output_scene_path) and not force_overwrite:
				#print(f"Skipping existing model files: {output_meta_path} / {output_scene_path}")
				skipped_count += 1
				file_name = dir.get_next()
				continue

			print(f"  Processing: {file_name}")

			# --- 1. Read JSON Metadata ---
			var json_file = FileAccess.open(json_path, FileAccess.READ)
			if not json_file:
				printerr(f"Error: Could not open JSON metadata file: {json_path}")
				error_count += 1
				file_name = dir.get_next()
				continue
			var json_string = json_file.get_as_text()
			json_file.close()
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result != OK:
				printerr(f"Error: Could not parse JSON metadata file: {json_path} - {json.get_error_message()} at line {json.get_error_line()}")
				error_count += 1
				file_name = dir.get_next()
				continue
			var metadata_dict: Dictionary = json.get_data()

			# --- 2. Create and Populate ModelMetadata Resource ---
			var model_metadata = ModelMetadata.new()
			var populate_success = _populate_metadata_resource(model_metadata, metadata_dict)

			if not populate_success:
				printerr(f"Error: Failed to populate ModelMetadata resource from {json_path}")
				error_count += 1
				file_name = dir.get_next()
				continue

			# --- 3. Save ModelMetadata Resource ---
			var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
			var meta_save_result = ResourceSaver.save(model_metadata, output_meta_path, save_flags)
			if meta_save_result != OK:
				printerr(f"Error saving ModelMetadata resource '{output_meta_path}': {meta_save_result}")
				error_count += 1
				file_name = dir.get_next()
				continue
			print(f"    Saved Metadata: {output_meta_path}")

			# --- 4. Create PackedScene ---
			var scene = PackedScene.new()
			var root_node = Node3D.new()
			root_node.name = base_name # Set root node name to model name

			# --- 5. Load and Instance GLB ---
			var glb_resource = load(glb_full_path)
			if not glb_resource or not glb_resource is PackedScene:
				printerr(f"Error: Failed to load GLB as PackedScene: {glb_full_path}")
				error_count += 1
				file_name = dir.get_next()
				continue
			var glb_instance = glb_resource.instantiate()
			if not glb_instance:
				printerr(f"Error: Failed to instance GLB scene: {glb_full_path}")
				error_count += 1
				file_name = dir.get_next()
				continue
			root_node.add_child(glb_instance)
			# Set owner so it gets saved with the scene
			glb_instance.owner = root_node

			# --- 6. Attach/Embed Metadata ---
			# Option 1: Attach via script variable (requires script on root node)
			# root_node.set_script(load("res://path/to/model_root_script.gd")) # Example
			# root_node.set("metadata_resource_path", output_meta_path)
			# Option 2: Embed (cleaner if no extra script needed on root)
			# This requires the root node's script (if any) or the scene state
			# to handle the embedded resource directly. For simplicity, let's
			# assume metadata is accessed via a manager or loaded separately based on model name.
			# We'll add it as metadata on the root node for now.
			root_node.set_meta("model_metadata_path", output_meta_path)

			# --- 7. Add Marker3D Nodes ---
			_add_markers_from_metadata(root_node, metadata_dict)

			# --- 8. Pack Scene ---
			var pack_result = scene.pack(root_node)
			if pack_result != OK:
				printerr(f"Error packing scene for '{base_name}': {pack_result}")
				error_count += 1
				file_name = dir.get_next()
				continue

			# --- 9. Save PackedScene ---
			var scene_save_result = ResourceSaver.save(scene, output_scene_path, save_flags)
			if scene_save_result != OK:
				printerr(f"Error saving Scene resource '{output_scene_path}': {scene_save_result}")
				error_count += 1
			else:
				processed_count += 1
				print(f"    Saved Scene: {output_scene_path}")

		file_name = dir.get_next()

	dir.list_dir_end()
	print(f"Finished generating Model Scenes/Metadata. Processed: {processed_count}, Skipped: {skipped_count}, Errors: {error_count}.")


# --- Helper Functions ---

func _populate_metadata_resource(metadata_res: ModelMetadata, data: Dictionary) -> bool:
	"""Populates a ModelMetadata resource from a parsed JSON dictionary."""
	if not metadata_res or not data:
		return false

	# Populate header info (adjust field names based on ModelMetadata.gd)
	var header = data.get("header", {})
	metadata_res.max_radius = header.get("max_radius", 0.0)
	metadata_res.mass = header.get("mass", 0.0)
	metadata_res.mass_center = Vector3(header.get("mass_center", [0,0,0])[0], header.get("mass_center", [0,0,0])[1], header.get("mass_center", [0,0,0])[2])
	# TODO: Populate moment_inertia if ModelMetadata stores it
	metadata_res.bounding_box_min = Vector3(header.get("bounding_box", {}).get("min", [0,0,0])[0], header.get("bounding_box", {}).get("min", [0,0,0])[1], header.get("bounding_box", {}).get("min", [0,0,0])[2])
	metadata_res.bounding_box_max = Vector3(header.get("bounding_box", {}).get("max", [0,0,0])[0], header.get("bounding_box", {}).get("max", [0,0,0])[1], header.get("bounding_box", {}).get("max", [0,0,0])[2])
	metadata_res.num_subobjects = header.get("num_subobjects", 0)
	# TODO: Populate detail_levels, debris_pieces, cross_sections if needed

	# Populate subobjects (assuming ModelMetadata stores an array of dictionaries or sub-resources)
	metadata_res.subobjects.clear() # Clear existing if any
	for subobj_dict in data.get("subobjects", []):
		# If ModelMetadata.subobjects expects a specific Resource type, create it here
		# Otherwise, just append the dictionary
		metadata_res.subobjects.append(subobj_dict)

	# Populate special points
	metadata_res.special_points.clear()
	for sp_dict in data.get("special_points", []):
		metadata_res.special_points.append(sp_dict) # Append dict or create sub-resource

	# Populate docking points
	metadata_res.docking_points.clear()
	for dock_dict in data.get("docking_points", []):
		# Example if ModelMetadata uses DockPointData resources:
		# var dock_res = DockPointData.new()
		# dock_res.properties = dock_dict.get("properties", "")
		# dock_res.path_indices = dock_dict.get("paths", [])
		# for p_dict in dock_dict.get("points", []):
		#     dock_res.positions.append(Vector3(p_dict.get("position", [0,0,0])[0], ...))
		#     dock_res.normals.append(Vector3(p_dict.get("normal", [0,0,1])[0], ...))
		# metadata_res.docking_points.append(dock_res)
		# --- OR --- Append dictionary directly if ModelMetadata expects that:
		metadata_res.docking_points.append(dock_dict)

	# Populate turrets (gun + missile)
	metadata_res.turrets.clear()
	for turret_dict in data.get("turrets", []):
		metadata_res.turrets.append(turret_dict) # Append dict or create sub-resource

	# Populate thrusters
	metadata_res.thrusters.clear()
	for thruster_dict in data.get("thrusters", []):
		metadata_res.thrusters.append(thruster_dict) # Append dict or create sub-resource

	# Populate glow arrays
	metadata_res.glow_arrays.clear()
	for glow_dict in data.get("glow_arrays", []):
		metadata_res.glow_arrays.append(glow_dict) # Append dict or create sub-resource

	# Populate shield mesh (might store simplified data or reference raw data)
	var shield_dict = data.get("shield", {})
	# Example: Store vertex count and face count, or just a flag indicating presence
	metadata_res.shield_face_count = shield_dict.get("faces", []).size()
	# metadata_res.shield_vertex_count = shield_dict.get("vertices", []).size() # Vertices are implicit in faces

	# Populate eye points
	metadata_res.eye_points.clear()
	for eye_dict in data.get("eye_points", []):
		metadata_res.eye_points.append(eye_dict) # Append dict or create sub-resource

	# Populate insignia (might just store count or basic info)
	metadata_res.insignia.clear()
	for ins_dict in data.get("insignia", []):
		metadata_res.insignia.append(ins_dict) # Append dict or create sub-resource

	# Populate paths
	metadata_res.paths.clear()
	for path_dict in data.get("paths", []):
		metadata_res.paths.append(path_dict) # Append dict or create sub-resource

	# Populate autocenter
	acen = data.get("autocenter")
	if acen and acen is Array and acen.size() == 3:
		metadata_res.autocenter = Vector3(acen[0], acen[1], acen[2])
	else:
		metadata_res.autocenter = Vector3.ZERO

	return true


func _add_markers_from_metadata(root_node: Node3D, metadata: Dictionary):
	"""Adds Marker3D nodes to the scene based on metadata points."""

	# Helper to find subobject node by name
	func find_subobject_node(start_node: Node, name: String) -> Node3D:
		for child in start_node.get_children():
			if child is Node3D and child.name == name:
				return child
			var found = find_subobject_node(child, name)
			if found:
				return found
		return null

	# Helper to add a marker
	func add_marker(parent_node: Node3D, marker_name: String, position: Vector3, normal: Vector3 = Vector3.FORWARD):
		var marker = Marker3D.new()
		marker.name = marker_name
		marker.position = position
		# Set rotation based on normal (point -Z along the normal)
		marker.look_at(position - normal, Vector3.UP) # Point -Z along normal
		parent_node.add_child(marker)
		marker.owner = root_node # Ensure it gets saved

	# Find the main mesh instance node (assuming it's the first Node3D child)
	var mesh_instance_parent = root_node
	for child in root_node.get_children():
		if child is Node3D: # Or check for MeshInstance3D if GLB structure is consistent
			# mesh_instance_parent = child # Add markers relative to the mesh instance? Or root? Let's use root for now.
			break

	# Add Gun Points (GPNT)
	var gp_idx = 0
	for bank in metadata.get("gun_points", []):
		var slot_idx = 0
		for point in bank.get("points", []):
			var pos = Vector3(point["position"][0], point["position"][1], point["position"][2])
			var norm = Vector3(point["normal"][0], point["normal"][1], point["normal"][2])
			add_marker(mesh_instance_parent, f"GP_{gp_idx}_{slot_idx}", pos, norm)
			slot_idx += 1
		gp_idx += 1

	# Add Missile Points (MPNT)
	var mp_idx = 0
	for bank in metadata.get("missile_points", []):
		var slot_idx = 0
		for point in bank.get("points", []):
			var pos = Vector3(point["position"][0], point["position"][1], point["position"][2])
			var norm = Vector3(point["normal"][0], point["normal"][1], point["normal"][2])
			add_marker(mesh_instance_parent, f"MP_{mp_idx}_{slot_idx}", pos, norm)
			slot_idx += 1
		mp_idx += 1

	# Add Docking Points (DOCK)
	var dock_idx = 0
	for dock in metadata.get("docking_points", []):
		var slot_idx = 0
		for point in dock.get("points", []):
			var pos = Vector3(point["position"][0], point["position"][1], point["position"][2])
			var norm = Vector3(point["normal"][0], point["normal"][1], point["normal"][2])
			add_marker(mesh_instance_parent, f"DOCK_{dock_idx}_{slot_idx}", pos, norm)
			slot_idx += 1
		dock_idx += 1

	# Add Eye Points (EYE)
	var eye_idx = 0
	for eye in metadata.get("eye_points", []):
		var pos = Vector3(eye["position"][0], eye["position"][1], eye["position"][2])
		var norm = Vector3(eye["normal"][0], eye["normal"][1], eye["normal"][2])
		# Find parent subobject node if specified
		parent_node = mesh_instance_parent
		if eye.get("parent", -1) >= 0:
			# Need to map parent index to subobject name first from metadata['subobjects']
			parent_subobj_name = ""
			for subobj in metadata.get("subobjects", []):
				if subobj.get("number") == eye.get("parent"):
					parent_subobj_name = subobj.get("name")
					break
			if parent_subobj_name:
				found_parent = find_subobject_node(glb_instance, parent_subobj_name)
				if found_parent:
					parent_node = found_parent
				else:
					print(f"Warning: Could not find parent node '{parent_subobj_name}' for eye point {eye_idx}")

		add_marker(parent_node, f"EYE_{eye_idx}", pos, norm)
		eye_idx += 1

	# Add Thruster Points (FUEL) - Optional, maybe just use metadata directly
	# Add Glow Points (GLOW) - Optional
	# Add Special Points (SPCL) - Optional, depends on usage
