@tool
extends RefCounted

## Reimport Manager
## Handles automatic reimport functionality with dependency tracking for WCS assets

class_name ReimportManager

signal asset_changed(asset_path: String)
signal reimport_started(asset_path: String)
signal reimport_completed(asset_path: String, success: bool)

var file_watcher: FileSystemWatcher
var dependency_graph: Dictionary = {}
var asset_metadata: Dictionary = {}
var reimport_queue: Array[String] = []
var processing_reimport: bool = false

func _init() -> void:
	file_watcher = FileSystemWatcher.new()
	file_watcher.file_changed.connect(_on_file_changed)
	_load_dependency_cache()

func start_watching() -> void:
	"""Start watching for file changes"""
	print("Starting WCS asset file watching...")
	file_watcher.start_watching()

func stop_watching() -> void:
	"""Stop watching for file changes"""
	print("Stopping WCS asset file watching...")
	file_watcher.stop_watching()

func register_asset_dependencies(asset_path: String, dependencies: Array[String]) -> void:
	"""Register dependencies for an asset to enable automatic reimport"""
	
	dependency_graph[asset_path] = {
		"dependencies": dependencies,
		"dependents": [],
		"last_modified": FileAccess.get_modified_time(asset_path),
		"asset_type": _detect_asset_type(asset_path)
	}
	
	# Update reverse dependencies
	for dep_path in dependencies:
		if not dependency_graph.has(dep_path):
			dependency_graph[dep_path] = {
				"dependencies": [],
				"dependents": [],
				"last_modified": 0,
				"asset_type": "dependency"
			}
		
		var dependents: Array = dependency_graph[dep_path]["dependents"]
		if asset_path not in dependents:
			dependents.append(asset_path)
	
	# Add to file watcher
	file_watcher.add_file(asset_path)
	for dep_path in dependencies:
		file_watcher.add_file(dep_path)
	
	_save_dependency_cache()

func _detect_asset_type(asset_path: String) -> String:
	"""Detect the type of WCS asset based on file extension"""
	var extension: String = asset_path.get_extension().to_lower()
	
	match extension:
		"vp":
			return "vp_archive"
		"pof":
			return "pof_model"
		"fs2", "fc2":
			return "mission_file"
		"pcx", "tga", "dds", "png", "jpg":
			return "texture"
		"tbl":
			return "table_data"
		_:
			return "unknown"

func _on_file_changed(file_path: String) -> void:
	"""Handle file change notification"""
	
	print("File changed detected: ", file_path)
	asset_changed.emit(file_path)
	
	# Check if this file affects any WCS assets
	var affected_assets: Array[String] = _find_affected_assets(file_path)
	
	for asset_path in affected_assets:
		if asset_path not in reimport_queue:
			reimport_queue.append(asset_path)
	
	# Process reimport queue
	if not processing_reimport and reimport_queue.size() > 0:
		_process_reimport_queue()

func _find_affected_assets(changed_file: String) -> Array[String]:
	"""Find all assets that depend on the changed file"""
	
	var affected: Array[String] = []
	
	# Direct dependency check
	if dependency_graph.has(changed_file):
		var dependents: Array = dependency_graph[changed_file].get("dependents", [])
		for dependent in dependents:
			if dependent not in affected:
				affected.append(dependent)
	
	# Check if the changed file is a WCS asset itself
	if _is_wcs_asset(changed_file):
		affected.append(changed_file)
	
	return affected

func _is_wcs_asset(file_path: String) -> bool:
	"""Check if a file is a WCS asset that should be reimported"""
	var asset_type: String = _detect_asset_type(file_path)
	return asset_type in ["vp_archive", "pof_model", "mission_file"]

func _process_reimport_queue() -> void:
	"""Process the reimport queue"""
	
	if processing_reimport or reimport_queue.is_empty():
		return
	
	processing_reimport = true
	
	while not reimport_queue.is_empty():
		var asset_path: String = reimport_queue.pop_front()
		await _reimport_asset(asset_path)
	
	processing_reimport = false

func _reimport_asset(asset_path: String) -> void:
	"""Reimport a specific asset"""
	
	print("Reimporting WCS asset: ", asset_path)
	reimport_started.emit(asset_path)
	
	# Check if file still exists
	if not FileAccess.file_exists(asset_path):
		print("Asset file no longer exists: ", asset_path)
		_remove_asset_from_tracking(asset_path)
		reimport_completed.emit(asset_path, false)
		return
	
	# Check if file was actually modified
	var current_modified: int = FileAccess.get_modified_time(asset_path)
	var last_modified: int = dependency_graph.get(asset_path, {}).get("last_modified", 0)
	
	if current_modified <= last_modified:
		print("Asset not actually modified, skipping: ", asset_path)
		reimport_completed.emit(asset_path, true)
		return
	
	# Update modification time
	if dependency_graph.has(asset_path):
		dependency_graph[asset_path]["last_modified"] = current_modified
	
	# Trigger Godot's import system
	EditorInterface.get_resource_filesystem().update_file(asset_path)
	
	# Wait for import to complete
	await EditorInterface.get_resource_filesystem().filesystem_changed
	
	# Validate import result
	var import_successful: bool = _validate_import_result(asset_path)
	
	if import_successful:
		print("Successfully reimported: ", asset_path)
		_update_asset_metadata(asset_path)
	else:
		print("Failed to reimport: ", asset_path)
	
	reimport_completed.emit(asset_path, import_successful)
	_save_dependency_cache()

func _validate_import_result(asset_path: String) -> bool:
	"""Validate that the import was successful"""
	
	var asset_type: String = _detect_asset_type(asset_path)
	
	match asset_type:
		"vp_archive":
			# Check if .tres import resource was created
			var import_path: String = asset_path.get_basename() + ".tres"
			return FileAccess.file_exists(import_path)
		
		"pof_model":
			# Check if .scn scene was created
			var scene_path: String = asset_path.get_basename() + ".scn"
			return FileAccess.file_exists(scene_path)
		
		"mission_file":
			# Check if .tscn scene was created
			var scene_path: String = asset_path.get_basename() + ".tscn"
			return FileAccess.file_exists(scene_path)
		
		_:
			# For other types, assume success if no errors
			return true

func _update_asset_metadata(asset_path: String) -> void:
	"""Update metadata for successfully imported asset"""
	
	asset_metadata[asset_path] = {
		"last_import": Time.get_unix_time_from_system(),
		"import_count": asset_metadata.get(asset_path, {}).get("import_count", 0) + 1,
		"asset_type": _detect_asset_type(asset_path)
	}

func _remove_asset_from_tracking(asset_path: String) -> void:
	"""Remove asset from dependency tracking"""
	
	# Remove from dependency graph
	if dependency_graph.has(asset_path):
		var dependencies: Array = dependency_graph[asset_path].get("dependencies", [])
		
		# Remove from dependents lists
		for dep_path in dependencies:
			if dependency_graph.has(dep_path):
				var dependents: Array = dependency_graph[dep_path]["dependents"]
				var index: int = dependents.find(asset_path)
				if index >= 0:
					dependents.remove_at(index)
		
		dependency_graph.erase(asset_path)
	
	# Remove from file watcher
	file_watcher.remove_file(asset_path)
	
	# Remove from metadata
	asset_metadata.erase(asset_path)
	
	_save_dependency_cache()

func get_asset_dependencies(asset_path: String) -> Array[String]:
	"""Get the dependencies for an asset"""
	return dependency_graph.get(asset_path, {}).get("dependencies", [])

func get_asset_dependents(asset_path: String) -> Array[String]:
	"""Get the assets that depend on this asset"""
	return dependency_graph.get(asset_path, {}).get("dependents", [])

func get_import_statistics() -> Dictionary:
	"""Get statistics about import operations"""
	
	var total_assets: int = dependency_graph.size()
	var total_imports: int = 0
	var asset_types: Dictionary = {}
	
	for asset_path in asset_metadata.keys():
		var metadata: Dictionary = asset_metadata[asset_path]
		total_imports += metadata.get("import_count", 0)
		
		var asset_type: String = metadata.get("asset_type", "unknown")
		asset_types[asset_type] = asset_types.get(asset_type, 0) + 1
	
	return {
		"total_tracked_assets": total_assets,
		"total_import_operations": total_imports,
		"asset_types_count": asset_types,
		"queue_size": reimport_queue.size(),
		"processing": processing_reimport
	}

func _save_dependency_cache() -> void:
	"""Save dependency graph and metadata to cache file"""
	
	var cache_data: Dictionary = {
		"dependency_graph": dependency_graph,
		"asset_metadata": asset_metadata,
		"version": 1
	}
	
	var cache_path: String = "user://wcs_import_cache.json"
	var file: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(cache_data))
		file.close()

func _load_dependency_cache() -> void:
	"""Load dependency graph and metadata from cache file"""
	
	var cache_path: String = "user://wcs_import_cache.json"
	if not FileAccess.file_exists(cache_path):
		return
	
	var file: FileAccess = FileAccess.open(cache_path, FileAccess.READ)
	if file == null:
		return
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	
	if parse_result != OK:
		print("Failed to parse import cache: ", json.error_string)
		return
	
	var cache_data: Dictionary = json.data as Dictionary
	dependency_graph = cache_data.get("dependency_graph", {})
	asset_metadata = cache_data.get("asset_metadata", {})
	
	print("Loaded import cache: ", dependency_graph.size(), " tracked assets")

## File System Watcher Class
class_name FileSystemWatcher
extends RefCounted

signal file_changed(file_path: String)

var watched_files: Dictionary = {}
var check_timer: Timer
var check_interval: float = 2.0  # Check every 2 seconds

func _init() -> void:
	check_timer = Timer.new()
	check_timer.wait_time = check_interval
	check_timer.timeout.connect(_check_file_modifications)

func start_watching() -> void:
	"""Start watching for file modifications"""
	if not check_timer.is_inside_tree():
		# Need to add to scene tree to function
		Engine.get_main_loop().current_scene.add_child(check_timer)
	
	check_timer.start()

func stop_watching() -> void:
	"""Stop watching for file modifications"""
	check_timer.stop()

func add_file(file_path: String) -> void:
	"""Add a file to the watch list"""
	if FileAccess.file_exists(file_path):
		watched_files[file_path] = FileAccess.get_modified_time(file_path)

func remove_file(file_path: String) -> void:
	"""Remove a file from the watch list"""
	watched_files.erase(file_path)

func _check_file_modifications() -> void:
	"""Check all watched files for modifications"""
	
	for file_path in watched_files.keys():
		if not FileAccess.file_exists(file_path):
			# File was deleted
			watched_files.erase(file_path)
			file_changed.emit(file_path)
			continue
		
		var current_modified: int = FileAccess.get_modified_time(file_path)
		var last_modified: int = watched_files[file_path]
		
		if current_modified > last_modified:
			watched_files[file_path] = current_modified
			file_changed.emit(file_path)
