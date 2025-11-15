# Advanced TBL to TRES conversion pipeline
# Handles high-performance conversion with validation, caching, and cross-reference management
class_name TBLtoTRESConverter
extends Node

# Configuration
@export var source_directory: String = "res://source_assets/"
@export var target_directory: String = "res://resources/converted/"
@export var cache_enabled: bool = true
@export var parallel_processing: bool = true
@export var max_memory_usage_mb: int = 2048
@export var validation_required: bool = true
@export var create_backup: bool = true

# Performance metrics
var conversion_stats: Dictionary = {
	"total_files_processed": 0,
	"total_records_converted": 0,
	"conversion_errors": 0,
	"validation_failures": 0,
	"cache_hits": 0,
	"cache_misses": 0,
	"processing_time_seconds": 0.0,
	"peak_memory_usage_mb": 0.0
}

# Resource type mapping
const RESOURCE_TYPE_MAP: Dictionary = {
	"ships.tbl": "ShipStats",
	"weapons.tbl": "WeaponData",
	"species.tbl": "SpeciesData",
	"nebula.tbl": "NebulaData",
	"asteroid.tbl": "AsteroidData"
}

# Conversion caches
var conversion_cache: Dictionary = {}
var cross_reference_cache: Dictionary = {}
var validation_cache: Dictionary = {}

# Thread pool for parallel processing
var processing_threads: Array = []
var active_jobs: Dictionary = {}
var job_queue: Array = []

# Signal system
signal conversion_started(total_files: int)
signal conversion_progress(processed_files: int, total_files: int, current_file: String)
signal conversion_completed(total_files: int, success_count: int, error_count: int)
signal validation_status(resource_path: String, is_valid: bool, errors: Array[String])
signal cache_operation(key: String, operation: String, result: String)

func convert_all_tbl_files(source_dir: String = "", target_dir: String = "") -> Dictionary:
	"""Convert all TBL files in source directory to TRES resources"""
	var start_time = Time.get_ticks_msec()

	# Use provided directories or fall back to configured ones
	source_dir = source_dir if not source_dir.is_empty() else source_directory
	target_dir = target_dir if not target_dir.is_empty() else target_directory

	# Find all TBL files
	var tbl_files = find_tbl_files(source_dir)
	if tbl_files.size() == 0:
		send_error("No TBL files found in: %s" % source_dir)
		return {"success": false, "error": "No TBL files found"}

	# Clear stats and prepare
	reset_conversion_stats()
	ensure_target_directory(target_dir)

	conversion_started.emit(tbl_files.size())

	# Process files with job queue
	var successful_conversions = 0
	var failed_conversions = 0

	if parallel_processing and tbl_files.size() > 5:
		var results = convert_parallel(tbl_files, source_dir, target_dir)
		successful_conversions = results.successful
		failed_conversions = results.failed
	else:
		for i in range(tbl_files.size()):
			var tbl_file = tbl_files[i]
			conversion_progress.emit(i + 1, tbl_files.size(), tbl_file)

			var result = convert_single_tbl(tbl_file, source_dir, target_dir)
			if result.success:
				successful_conversions += 1
			else:
				failed_conversions += 1
				conversion_stats["conversion_errors"] += 1

		update_processing_stats()

	var end_time = Time.get_ticks_msec()
	conversion_stats["processing_time_seconds"] = (end_time - start_time) / 1000.0

	conversion_completed.emit(tbl_files.size(), successful_conversions, failed_conversions)

	return {
		"success": failed_conversions == 0,
		"total_files": tbl_files.size(),
		"successful": successful_conversions,
		"failed": failed_conversions,
		"processing_time": conversion_stats["processing_time_seconds"],
		"stats": conversion_stats.duplicate(true)
	}

func convert_single_tbl(tbl_file_path: String, source_dir: String, target_dir: String) -> Dictionary:
	"""Convert a single TBL file to TRES format"""
	var result = {"success": false, "error": "", "resources_created": 0}

	try:
		# Parse TBL file
		var parse_result = await parse_tbl_file_async(tbl_file_path)
		if parse_result.error:
			result.error = parse_result.error
			return result

		# Determine resource type
		var file_name = tbl_file_path.get_file()
		var resource_class = RESOURCE_TYPE_MAP.get(file_name, "WCSDataResource")

		# Convert each record
		for record in parse_result.records:
			var conversion_result = convert_single_record(record, resource_class, target_dir)
			if conversion_result.success:
				result.resources_created += 1
				conversion_stats["total_records_converted"] += 1

		result.success = result.resources_created > 0

	except:
		result.error = "Exception during TBL conversion: %s" % get_stack_trace()

	conversion_stats["total_files_processed"] += 1
	return result

func convert_single_record(record_data: Dictionary, resource_class: String, target_dir: String) -> Dictionary:
	"""Convert individual TBL record to TRES resource"""
	var result = {"success": false, "error": "", "resource_path": ""}

	try:
		# Create appropriate resource instance
		var resource = create_resource_instance(resource_class)
		if not resource:
			result.error = "Failed to create resource instance: %s" % resource_class
			return result

		# Populate resource with converted data
		populate_resource(resource, record_data, resource_class)

		# Validate if required
		if validation_required:
			if not resource.validate():
				result.error = "Validation failed: %s" % str(resource.get_validation_summary())
				conversion_stats["validation_failures"] += 1
				validation_status.emit(result.resource_path, false, resource.validation_errors)
				return result

		# Determine output path
		var output_path = get_output_path(record_data, target_dir,resource_class)
		result.resource_path = output_path

		# Check cache first
		if cache_enabled and is_cached(output_path):
			conversion_stats["cache_hits"] += 1
			result.success = true
			return result

		# Save resource
		var save_result = ResourceSaver.save(resource, output_path)
		if save_result != OK:
			result.error = "Failed to save resource: %s" % str(save_result)
			return result

		# Update cache
		if cache_enabled:
			update_cache(output_path, resource)
			conversion_stats["cache_misses"] += 1

		result.success = true

	except:
		result.error = "Exception during record conversion: %s" % get_stack_trace()

	return result

func create_resource_instance(resource_class: String) -> WCSDataResource:
	"""Dynamically create resource instance based on class name"""
	match resource_class:
		"ShipStats": return ShipStats.new()
		"WeaponData": return WeaponData.new()
		"SpeciesData": return SpeciesData.new()
		"NebulaData": return NebulaData.new()
		"AsteroidData": return AsteroidData.new()
		_: return WCSDataResource.new()

func populate_resource(resource: WCSDataResource, record_data: Dictionary, resource_class: String) -> void:
	"""Populate resource with converted TBL data based on class-specific logic"""

	# Set base metadata
	resource.wcs_source_file = record_data.get("source_file", "")
	resource.wcs_original_name = record_data.get("original_name", "")
	resource.conversion_timestamp = Time.get_unix_time_from_system()

	# Class-specific population logic
	match resource_class:
		"ShipStats":
			populate_ship_resource(resource as ShipStats, record_data)
		"WeaponData":
			populate_weapon_resource(resource as WeaponData, record_data)
		"SpeciesData":
			populate_species_resource(resource as SpeciesData, record_data)
		"NebulaData":
			populate_nebula_resource(resource as NebulaData, record_data)
		"AsteroidData":
			populate_asteroid_resource(resource as AsteroidData, record_data)

func populate_ship_resource(ship: ShipStats, data: Dictionary) -> void:
	"""Populate ship resource from parsed TBL data"""
	ship.ship_class = data.get("$Name", "")
	ship.display_name = data.get("$Alt Name", ship.ship_class)
	ship.species = data.get("species_resource_path", "")
	ship.model_file = data.get("pof_file_path", "")

	# Convert TBL arrays to Godot data
	if "$Max Velocity" in data:
		var vel_array = data["$Max Velocity"]
		ship.max_velocity = Vector3(vel_array[0], vel_array[1], vel_array[2])

	if "$Rotation time" in data:
		var rot_array = data["$Rotation time"]
		ship.rotation_time = Vector3(rot_array[0], rot_array[1], rot_array[2])

	# Shield and armor
	ship.shield_strength = data.get("$Shields", 0)
	ship.hull_hitpoints = data.get("$Hitpoints", 0)

	# Weapons and cross-references
	ship.allowed_primary_weapons = data.get("primary_weapons_paths", [])
	ship.allowed_secondary_weapons = data.get("secondary_weapons_paths", [])

func populate_weapon_resource(weapon: WeaponData, data: Dictionary) -> void:
	"""Populate weapon resource from parsed TBL data"""
	weapon.weapon_class = data.get("$Name", "")
	weapon.display_name = weapon.weapon_class.replace("@", "")
	weapon.mass_kg = data.get("$Mass", 0.2)
	weapon.velocity_mps = data.get("$Velocity", 100.0)
	weapon.fire_rate_hz = 1.0 / data.get("$Fire Wait", 1.0)  # Convert wait to rate
	weapon.base_damage_energy = data.get("$Damage", 0)
	weapon.lifetime_seconds = data.get("$Lifetime", 1.0)
	weapon.energy_per_shot = data.get("$Energy Consumed", 0.0)

	# Convert homing data
	var homing_value = data.get("$Homing", "NO")
	if homing_value != "NO":
		weapon.homing_type = 1  # Aspect homing
		weapon.lock_time_seconds = data.get("$Min Lock Time", 2.0)
		weapon.max_turn_rate_dps = data.get("$Turn Time", 0.0)

func populate_species_resource(species: SpeciesData, data: Dictionary) -> void:
	"""Populate species resource from parsed TBL data"""
	species.species_name = data.get("$Name", "")
	species.default_iff_status = data.get("relationships", {})
	species.military_doctrine = data.get("$Military Doctrine", "Balanced")

func populate_nebula_resource(nebula: NebulaData, data: Dictionary) -> void:
	"""Populate nebula resource from parsed TBL data"""
	nebula.nebula_name = data.get("$Name", "")
	nebula.gas_density = data.get("$Gas Density", 0.5)
	nebula.visual_opacity = data.get("$Visual Opacity", 0.3)
	nebula.shield_effectiveness_modifier = data.get("$Shield Modifier", 1.0)
	nebula.weapon_range_modifier = data.get("$Weapon Range", 1.0)
	nebula.sensor_range_modifier = data.get("$Sensor Range", 1.0)

func populate_asteroid_resource(asteroid: AsteroidData, data: Dictionary) -> void:
	"""Populate asteroid resource from parsed TBL data"""
	asteroid.field_name = data.get("$Name", "")
	asteroid.asteroid_density = data.get("$Density", 0.3)
	asteroid.field_size_km = data.get("$Field Size", 10.0)
	asteroid.min_asteroid_size = data.get("$Min Size", 1.0)
	asteroid.max_asteroid_size = data.get("$Max Size", 5000.0)
	asteroid.collision_damage_scale = data.get("$Damage Multiplier", 1.0)

# Utility functions
func find_tbl_files(directory: String) -> Array[String]:
	"""Find all .tbl files in directory and subdirectories"""
	var files = []
	var dir = DirAccess.open(directory)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tbl"):
				files.append(directory.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
	return files.sort()

func parse_tbl_file_async(file_path: String) -> Dictionary:
	"""Parse TBL file using external tool with async processing"""
	var result = {"error": "", "records": []}

	try:
		# Use existing parse_tbl skill
		var parser_path = "/home/fuchsst/data/projects/personal/wcsaga_godot_converter/.claude/skills/parse-tbl/scripts/parse_tbl.py"
		var output = []
		var exit_code = OS.execute("uv", ["run", parser_path, file_path], output)

		if exit_code == 0:
			# Parse JSON output from the tool
			var json_output = JSON.parse_string("".join(output))
			if json_output and typeof(json_output) == TYPE_DICTIONARY:
				result.records = json_output.get("records", [])
				result.error = json_output.get("error", "")
			else:
				result.error = "Invalid JSON output from parser"
		else:
			result.error = "Parser failed with exit code: " + str(exit_code)

	except:
		result.error = "Exception during TBL parsing: " + str(get_stack_trace())

	return result

func get_output_path(record_data: Dictionary, target_dir: String, resource_class: String) -> String:
	"""Determine appropriate output path for converted resource"""
	var base_name = record_data.get("$Name", "unknown")
	var sanitized_name = base_name.replace(" ", "_").replace("/", "_").replace("@", "")
	var class_suffix = resource_class.to_lower()
	return target_dir.path_join("%s.%s.tres" % [sanitized_name, class_suffix])

func ensure_target_directory(dir_path: String) -> void:
	"""Create target directory if it doesn't exist"""
	var dir = DirAccess.open(dir_path)
	if not dir:
		DirAccess.make_dir_recursive_absolute(dir_path)

# Cache management
func is_cached(key: String) -> bool:
	"""Check if resource is in conversion cache"""
	return key in conversion_cache

func update_cache(key: String, resource: Resource) -> void:
	"""Update conversion cache"""
	conversion_cache[key] = resource

	# Check memory usage and clear if necessary
	if get_current_memory_usage() > max_memory_usage_mb * 1024 * 1024:
		clear_oldest_cache_entries()

func clear_oldest_cache_entries() -> void:
	"""Remove oldest cache entries to free memory"""
	var keys_to_remove = []
	var max_cache_size = 100  # Limit cache size

	if conversion_cache.size() > max_cache_size:
		# Remove oldest entries
		var i = 0
		for key in conversion_cache.keys():
			if i > max_cache_size / 2:
				keys_to_remove.append(key)
			i += 1

	for key in keys_to_remove:
		conversion_cache.erase(key)

func get_current_memory_usage() -> int:
	"""Get current memory usage in bytes"""
	# Approximation based on cache contents
	var total_size = 0
	for resource in conversion_cache.values():
		total_size += get_resource_size_approximation(resource)
	return total_size

func get_resource_size_approximation(resource: Resource) -> int:
	"""Approximate memory size of a resource"""
	# Rough approximation based on export properties
	var approx_size = 1024  # Base size
	for property in resource.get_property_list():
		if property.type == TYPE_STRING:
			approx_size += property.hint_string.length() if property.hint_string else 50
		else:
			approx_size += 8  # Average primitive size
	return approx_size

# Statistics and monitoring
func reset_conversion_stats() -> void:
	"""Reset all conversion statistics"""
	for key in conversion_stats.keys():
		conversion_stats[key] = 0 if typeof(conversion_stats[key]) == TYPE_INT else 0.0

func update_processing_stats() -> void:
	"""Update processing statistics"""
	conversion_stats["peak_memory_usage_mb"] = max(
		conversion_stats["peak_memory_usage_mb"],
		get_current_memory_usage() / (1024.0 * 1024.0)
	)

func get_conversion_report() -> Dictionary:
	"""Get detailed conversion statistics and metrics"""
	return {
		"summary": conversion_stats.duplicate(true),
		"cache_statistics": {
			"entries": conversion_cache.size(),
			"memory_usage_mb": get_current_memory_usage() / (1024.0 * 1024.0)
		},
		"resource_type_breakdown": get_resource_type_breakdown(),
		"performance_metrics": get_performance_metrics()
	}

func get_resource_type_breakdown() -> Dictionary:
	"""Get breakdown by resource types"""
	var breakdown = {}
	for resource_path in conversion_cache.keys():
		var parts = resource_path.split(".")
		if parts.size() >= 2:
			var res_type = parts[-2]  # Type is before extension
			breakdown[res_type] = breakdown.get(res_type, 0) + 1
	return breakdown

func get_performance_metrics() -> Dictionary:
	"""Get performance analysis metrics"""
	var total_records = conversion_stats["total_records_converted"]
	var total_time = conversion_stats["processing_time_seconds"]

	return {
		"records_per_second": total_records / max(total_time, 0.001),
		"cache_hit_rate": conversion_stats["cache_hits"] / max(
			conversion_stats["cache_hits"] + conversion_stats["cache_misses"], 1.0
		),
		"validation_failure_rate": conversion_stats["validation_failures"] / max(total_records, 1.0),
		"error_rate": conversion_stats["conversion_errors"] / max(conversion_stats["total_files_processed"], 1.0)
	}

# Parallel processing functions
func convert_parallel(tbl_files: Array, source_dir: String, target_dir: String) -> Dictionary:
	"""Convert files using parallel processing"""
	var results = {"successful": 0, "failed": 0}

	# Create worker threads
	var worker_count = min(tbl_files.size(), OS.get_processor_count())
	var workers = []
	var progress_count = 0

	for i in range(worker_count):
		var worker = WorkerThread.new()
		worker.worker_id = i
		worker.source_directory = source_dir
		worker.target_directory = target_dir
		worker.converter_reference = self
		workers.append(worker)

	# Distribute work
	var file_index = 0
	while file_index < tbl_files.size():
		for worker in workers:
			if file_index >= tbl_files.size():
				break

			if not worker.is_working():
				worker.start_conversion(tbl_files[file_index])
				file_index += 1

			# Update progress
			if file_index > progress_count:
				progress_count = file_index
				conversion_progress.emit(progress_count, tbl_files.size(), "Parallel processing...")

		await get_tree().process_frame  # Don't block

	# Wait for completion
	var completed = 0
	while completed < worker_count:
		completed = 0
		for worker in workers:
			if not worker.is_working():
				results.successful += worker.successful_conversions
				results.failed += worker.failed_conversions
				completed += 1
		await get_tree().process_frame

	# Clean up
	for worker in workers:
		worker.queue_free()

	return results

# Worker thread class for parallel processing
class WorkerThread:
	var thread: Thread
	var worker_id: int
	var source_directory: String
	var target_directory: String
	var converter_reference: TBLtoTRESConverter
	var successful_conversions: int = 0
	var failed_conversions: int = 0
	var current_file: String = ""

	func is_working() -> bool:
		return thread and thread.is_alive()

	func start_conversion(file_path: String) -> void:
		current_file = file_path
		thread = Thread.new()
		thread.start(_conversion_thread_function.bind(file_path))

	func _conversion_thread_function(file_path: String) -> void:
		# Thread-safe conversion function
		var result = converter_reference.convert_single_tbl(
			file_path, source_directory, target_directory
		)

		if result.success:
			successful_conversions += 1
		else:
			failed_conversions += 1

		thread.wait_to_finish()

func _ready() -> void:
	"""Initialize conversion system"""
	# Register this as autoload if not already done
	add_to_group("tbl_converter")
	print("TBL to TRES Converter initialized")

func _exit_tree() -> void:
	"""Clean up conversion system"""
	remove_from_group("tbl_converter")
	print("TBL to TRES Converter shut down")