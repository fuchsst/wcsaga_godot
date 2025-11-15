# WCSResourceManager - Enhanced Centralized Resource Management System
# Manages loading, validation, and cross-reference resolution for WCS Resource classes
# Provides caching, dependency tracking, and comprehensive performance optimization

@tool
class_name WCSResourceManager
extends Node

# Configuration
@export var resource_cache_size: int = 500  # Maximum cached resources
@export var preload_critical_resources: bool = true
@export var enable_background_loading: bool = true
@export var validation_on_load: bool = true
@export var memory_usage_limit_mb: int = 1024

# Resource directories
@export var resources_base_path: String = "res://data/converted/"
@export var ships_path: String = "ships/"
@export var weapons_path: String = "weapons/"
@export var species_path: String = "species/"
@export var environment_path: String = "environment/"

# Resource registries - Map by primary identifier
var species_registry: Dictionary = {}           # species_mnemonic -> SpeciesData
var ship_registry: Dictionary = {}              # ship_class -> ShipStats
var weapon_registry: Dictionary = {}            # weapon_class -> WeaponData
var environmental_registry: Dictionary = {}     # environment_name -> AsteroidData/NebulaData
var effect_registry: Dictionary = {}            # effect_name -> Effect resource
var audio_registry: Dictionary = {}             # audio_name -> Audio resource

# Cross-reference tracking
var cross_reference_map: Dictionary = {}        # dependency -> dependents
var resource_dependencies: Dictionary = {}      # resource_path -> dependencies
var unresolved_references: Array[String] = []   # Pending reference resolution

# Caching system
var resource_cache: Dictionary = {}
var cache_hit_statistics: Dictionary = {}
var cache_miss_statistics: Dictionary = {}
var cache_entry_count: int = 0

# Performance monitoring
var load_time_metrics: Dictionary = {}
var memory_usage_metrics: Dictionary = {}
var performance_warnings: Array[String] = []
var resources_loaded_total: int = 0

# Validation tracking
var validation_errors_log: Array[Dictionary] = []
var validation_warnings_log: Array[Dictionary] = []
var resource_validation_states: Dictionary = {} # resource_path -> validation_state

# Background loading
var loading_queue: Array = []
var active_loads: Dictionary = {}
var queue_process_rate: int = 5  # Resources per frame

signals:
signal resource_loaded(resource_type: String, resource_id: String, resource: Resource)
signal resource_validation_complete(resource_type: String, resource_id: String, is_valid: bool)
signal cross_reference_resolved(dependency: String, dependent: String)
signal cache_hit(resource_id: String)
signal cache_miss(resource_id: String)
signal resource_loading_error(resource_path: String, error_message: String)
signal memory_warning(current_usage: int, limit: int)
signal performance_warning_issued(warning_message: String)

func _ready():
	print("Initializing WCS Resource Manager...")
	initialize_resource_system()
	print("WCS Resource Manager ready - Total resources: %d" % get_total_resource_count())

func initialize_resource_system():
	# Initialize core systems
	initialize_critical_resources()
	initialize_cache_system()

	# Load all WCS resources
	load_all_wcs_resources()

	# Validate and resolve cross-references
	if validation_on_load:
		validate_all_resources()
	resolve_all_cross_references()

	# Setup performance monitoring
	if enable_background_loading:
		setup_background_loading()

func get_total_resource_count() -> int:
	return (species_registry.size() + ship_registry.size() +
			weapon_registry.size() + environmental_registry.size() +
			effect_registry.size() + audio_registry.size())

# ================== RESOURCE LOADING SYSTEM ==================

func load_all_wcs_resources() -> void:
	print("Loading WCS resources from: %s" % resources_base_path)

	load_species_resources()
	load_ship_resources()
	load_weapon_resources()
	load_environmental_resources()
	load_effect_resources()
	load_audio_resources()

	print("Resource loading complete. Total: %d resources" % get_total_resource_count())

func load_species_resources() -> void:
	var species_paths = [
		resources_base_path.path_join(species_path).path_join("terran_species.tres"),
		resources_base_path.path_join(species_path).path_join("kilrathi_species.tres"),
		"res://target/scripts/resources/species_data.gd"  # Template for validation
	]

	for path in species_paths:
		if ResourceLoader.exists(path):
			_load_single_species_resource(path)

func _load_single_species_resource(resource_path: String) -> void:
	var resource = load_resource_by_path(resource_path, "species_data")
	if resource is SpeciesData:
		species_registry[resource.species_mnemonic] = resource
		resource_loaded.emit("species", resource.species_mnemonic, resource)
		record_performance_metric("species_load", Time.get_ticks_msec())

func load_ship_resources() -> void:
	var ship_classes = [
		"F-86C Hellcat V", "F-27B Arrow", "F-66A Thunderbolt VII",
		"F-44A Rapier II", "P-64C Ferret", "F-57B Sabre"
	]

	for ship_class in ship_classes:
		var resource_path = get_ship_stats_path(ship_class)
		if ResourceLoader.exists(resource_path):
			_load_single_ship_resource(resource_path, ship_class)

func _load_single_ship_resource(resource_path: String, ship_class: String) -> void:
	var resource = load_resource_by_path(resource_path, "ship_stats")
	if resource is ShipStats:
		ship_registry[ship_class] = resource
		resource_loaded.emit("ship", ship_class, resource)
		record_performance_metric("ship_load", Time.get_ticks_msec())

func load_weapon_resources() -> void:
	var weapon_classes = [
		"@Ion", "@Neutron", "@Laser", "@Particle", "@Mass Driver",
		"@Meson", "@Photon", "@Plasma", "@Tachyon", "@Reaper"
	]

	for weapon_class in weapon_classes:
		var resource_path = get_weapon_data_path(weapon_class)
		if ResourceLoader.exists(resource_path):
			_load_single_weapon_resource(resource_path, weapon_class)

func _load_single_weapon_resource(resource_path: String, weapon_class: String) -> void:
	var resource = load_resource_by_path(resource_path, "weapon_data")
	if resource is WeaponData:
		weapon_registry[weapon_class] = resource
		resource_loaded.emit("weapon", weapon_class, resource)
		record_performance_metric("weapon_load", Time.get_ticks_msec())

func load_environmental_resources() -> void:
	var asteroid_fields = ["Alpha Belt", "Kilrah Debris Field", "Nexus Asteroid Cluster"]
	var nebulae = ["Tiger's Claw Nebula", "Ion Storm Alpha", "Dust Cloud Beta"]

	for field_name in asteroid_fields:
		var resource_path = get_environment_path(field_name, "asteroid")
		if ResourceLoader.exists(resource_path):
			_load_single_environmental_resource(resource_path, field_name, "asteroid")

	for nebula_name in nebulae:
		var resource_path = get_environment_path(nebula_name, "nebula")
		if ResourceLoader.exists(resource_path):
			_load_single_environmental_resource(resource_path, nebula_name, "nebula")

func _load_single_environmental_resource(resource_path: String, env_name: String, env_type: String) -> void:
	var resource = load_resource_by_path(resource_path, env_type + "_data")
	if resource:
		environmental_registry[env_name] = resource
		resource_loaded.emit(env_type, env_name, resource)
		record_performance_metric("environment_load", Time.get_ticks_msec())

func load_effect_resources() -> void:
	var effect_paths = [
		"res://effects/muzzle_flash_ion.tres",
		"res://effects/explosion_medium.tres",
		"res://effects/shield_impact.tres"
	]

	for path in effect_paths:
		if ResourceLoader.exists(path):
			var resource = load(path)
			effect_registry[path] = resource
			resource_loaded.emit("effect", path, resource)

func load_audio_resources() -> void:
	var audio_paths = [
		"res://audio/weapons/ion_fire.ogg",
		"res://audio/ambient/engine_idle.ogg",
		"res://audio/ui/alert_general.ogg"
	]

	for path in audio_paths:
		if ResourceLoader.exists(path):
			var resource = load(path)
			audio_registry[path] = resource
			resource_loaded.emit("audio", path, resource)

# ================== ENHANCED RESOURCE ACCESS ==================

func load_resource_by_path(resource_path: String, expected_type: String) -> Resource:
	"""Core function to load any resource with comprehensive validation"""

	# Check cache first
	if resource_path in resource_cache:
		cache_hit_statistics[resource_path] = cache_hit_statistics.get(resource_path, 0) + 1
		var cached_resource = resource_cache[resource_path]
		if is_instance_valid(cached_resource):
			cache_hit.emit(resource_path)
			return cached_resource

	# Track cache miss
	cache_miss_statistics[resource_path] = cache_miss_statistics.get(resource_path, 0) + 1
	cache_miss.emit(resource_path)

	# Load from filesystem
	var start_time = Time.get_ticks_msec()
	var resource = _load_from_filesystem(resource_path, expected_type)

	if not resource:
		resource_loading_error.emit(resource_path, "Failed to load resource from filesystem")
		return null

	# Validate if required
	if validation_on_load and resource is WCSBaseResource:
		if not _validate_loaded_resource(resource, resource_path):
			return null

	# Add to cache
	_add_to_cache(resource_path, resource)

	# Update metrics
	var load_time = Time.get_ticks_msec() - start_time
	record_performance_metric("load_" + expected_type, load_time)
	resources_loaded_total += 1

	return resource

func _load_from_filesystem(resource_path: String, expected_type: String) -> Resource:
	"""Load resource directly from filesystem with error handling"""
	try:
		if not ResourceLoader.exists(resource_path):
			return null

		var resource = load(resource_path)
		if not resource:
			return null

		# Type validation
		var type_matches = false
		match expected_type:
			"species_data": type_matches = resource is SpeciesData
			"ship_stats": type_matches = resource is ShipStats
			"weapon_data": type_matches = resource is WeaponData
			"asteroid_data": type_matches = resource is AsteroidData
			"nebula_data": type_matches = resource is NebulaData
			_: type_matches = resource is Resource

		if not type_matches:
			return null

		return resource

	except:
		resource_loading_error.emit(resource_path, "Exception during resource loading")
		return null

func _validate_loaded_resource(resource: WCSBaseResource, resource_path: String) -> bool:
	"""Validate newly loaded resource"""
	var start_time = Time.get_ticks_msec()
	var is_valid = resource.validate()
	var validation_time = Time.get_ticks_msec() - start_time

	resource_validation_states[resource_path] = {
		"is_valid": is_valid,
		"validation_time": validation_time,
		"timestamp": Time.get_unix_time_from_system()
	}

	var resource_type = resource.get_resource_type()
	var resource_id = resource.wcs_resource_id if hasattr(resource, "wcs_resource_id") else resource_path

	resource_validation_complete.emit(resource_type, resource_id, is_valid)

	# Log validation issues
	if not is_valid and resource.validation_errors.size() > 0:
		for error in resource.validation_errors:
			validation_errors_log.append({
				"resource_path": resource_path,
				"resource_type": resource_type,
				"error": error,
				"timestamp": Time.get_unix_time_from_system()
			})

	# Log warnings
	if resource.validation_warnings.size() > 0:
		for warning in resource.validation_warnings:
			validation_warnings_log.append({
				"resource_path": resource_path,
				"resource_type": resource_type,
				"warning": warning,
				"timestamp": Time.get_unix_time_from_system()
			})

	return is_valid

# ================== RESOURCE ACCESS API ==================

func get_species_by_mnemonic(mnemonic: String) -> SpeciesData:
	return species_registry.get(mnemonic, null)

func get_ship_by_class(ship_class: String) -> ShipStats:
	return ship_registry.get(ship_class, null)

func get_weapon_by_class(weapon_class: String) -> WeaponData:
	return weapon_registry.get(weapon_class, null)

func get_environmental_by_name(env_name: String) -> Resource:
	return environmental_registry.get(env_name, null)

func get_effect_resource(effect_name: String) -> Resource:
	return effect_registry.get(effect_name, null)

func get_audio_resource(audio_name: String) -> Resource:
	return audio_registry.get(audio_name, null)

func get_random_species() -> SpeciesData:
	if species_registry.is_empty():
		return null
	var keys = species_registry.keys()
	return species_registry[keys[randi() % keys.size()]]

func get_random_ship() -> ShipStats:
	if ship_registry.is_empty():
		return null
	var keys = ship_registry.keys()
	return ship_registry[ keys[randi() % keys.size()]]

func get_random_weapon() -> WeaponData:
	if weapon_registry.is_empty():
		return null
	var keys = weapon_registry.keys()
	return weapon_registry[keys[randi() % keys.size()]]

# ================== CROSS-REFERENCE RESOLUTION ==================

func resolve_all_cross_references() -> void:
	"""Resolve all cross-references between resources"""
	print("Resolving cross-references...")

	unresolved_references.clear()

	resolve_species_cross_references()
	resolve_ship_cross_references()
	resolve_weapon_cross_references()
	resolve_environmental_cross_references()
	establish_cross_reference_dependencies()

	print("Cross-reference resolution complete. %d unresolved references" % unresolved_references.size())

func resolve_species_cross_references() -> void:
	for species_mnemonic in species_registry.keys():
		var species = species_registry[species_mnemonic]
		if species is SpeciesData:
			var resolved_count = resolve_single_resource_references(species, species_mnemonic, "species")
			if resolved_count < species.cross_reference_dependencies.size():
				unresolved_references.append("Species: %s" % species_mnemonic)

func resolve_ship_cross_references() -> void:
	for ship_class in ship_registry.keys():
		var ship = ship_registry[ship_class]
		if ship is ShipStats:
			var resolved_count = resolve_single_resource_references(ship, ship_class, "ship")
			if resolved_count < ship.cross_reference_dependencies.size():
				unresolved_references.append("Ship: %s" % ship_class)

func resolve_weapon_cross_references() -> void:
	for weapon_class in weapon_registry.keys():
		var weapon = weapon_registry[weapon_class]
		if weapon is WeaponData:
			var resolved_count = resolve_single_resource_references(weapon, weapon_class, "weapon")
			if resolved_count < weapon.cross_reference_dependencies.size():
				unresolved_references.append("Weapon: %s" % weapon_class)

func resolve_environmental_cross_references() -> void:
	for env_name in environmental_registry.keys():
		var env = environmental_registry[env_name]
		if env is AsteroidData or env is NebulaData:
			var resolved_count = resolve_single_resource_references(env, env_name, "environment")
			if resolved_count < env.cross_reference_dependencies.size():
				unresolved_references.append("Environment: %s" % env_name)

func resolve_single_resource_references(resource: WCSBaseResource, identifier: String, resource_type: String) -> int:
	"""Resolve cross-references for a single resource"""
	var available_resources = get_all_available_references()
	var resolved_count = resource.resolve_cross_references(available_resources)

	if resolved_count > 0:
		cross_reference_resolved.emit(str(identifier), str(resource_type))

	return resolved_count

func get_all_available_references() -> Array[String]:
	"""Get all available resource references for cross-resolution"""
	var available_refs = []

	available_refs.append_array(species_registry.keys())
	available_refs.append_array(ship_registry.keys())
	available_refs.append_array(weapon_registry.keys())
	available_refs.append_array(environmental_registry.keys())
	available_refs.append_array(effect_registry.keys())
	available_refs.append_array(audio_registry.keys())

	# Add resource IDs from structured resources
	for species in species_registry.values():
		if species is SpeciesData and species.wcs_resource_id:
			available_refs.append(species.wcs_resource_id)

	for ship in ship_registry.values():
		if ship is ShipStats and ship.wcs_resource_id:
			available_refs.append(ship.wcs_resource_id)

	for weapon in weapon_registry.values():
		if weapon is WeaponData and weapon.wcs_resource_id:
			available_refs.append(weapon.wcs_resource_id)

	return available_refs

# ================== VALIDATION SYSTEM ==================

func validate_all_resources() -> void:
	"""Validate all loaded resources"""
	print("Validating all WCS resources...")

	validation_errors_log.clear()
	validation_warnings_log.clear()
	resource_validation_states.clear()

	validate_species_resources()
	validate_ship_resources()
	validate_weapon_resources()
	validate_environmental_resources()

	print("Validation complete. %d errors, %d warnings" %
		  [validation_errors_log.size(), validation_warnings_log.size()])

	if validation_errors_log.size() > 0:
		log_validation_summary()

func validate_species_resources() -> void:
	for mnemonic in species_registry.keys():
		var species = species_registry[mnemonic]
		if species is SpeciesData:
			_validate_single_resource(species, mnemonic, "species")

func validate_ship_resources() -> void:
	for ship_class in ship_registry.keys():
		var ship = ship_registry[ship_class]
		if ship is ShipStats:
			_validate_single_resource(ship, ship_class, "ship")

func validate_weapon_resources() -> void:
	for weapon_class in weapon_registry.keys():
		var weapon = weapon_registry[weapon_class]
		if weapon is WeaponData:
			_validate_single_resource(weapon, weapon_class, "weapon")

func validate_environmental_resources() -> void:
	for env_name in environmental_registry.keys():
		var env = environmental_registry[env_name]
		if env is AsteroidData or env is NebulaData:
			_validate_single_resource(env, env_name, "environment")

func _validate_single_resource(resource: WCSBaseResource, identifier: String, resource_type: String) -> void:
	"""Validate a single resource and track results"""
	var start_time = Time.get_ticks_msec()
	var is_valid = resource.validate()
	var validation_time = Time.get_ticks_msec() - start_time

	var validation_summary = resource.get_validation_summary()
	var resource_id = resource.wcs_resource_id if hasattr(resource, "wcs_resource_id") else identifier

	resource_validation_states[identifier] = {
		"is_valid": is_valid,
		"validation_time": validation_time,
		"error_count": validation_summary["error_count"],
		"warning_count": validation_summary["warning_count"],
		"timestamp": Time.get_unix_time_from_system()
	}

	resource_validation_complete.emit(resource_type, resource_id, is_valid)

	# Log validation issues
	if validation_summary["error_count"] > 0:
		for error in validation_summary["errors"]:
			validation_errors_log.append({
				"identifier": identifier,
				"resource_type": resource_type,
				"error": error,
				"timestamp": Time.get_unix_time_from_system()
			})

	if validation_summary["warning_count"] > 0:
		for warning in validation_summary["warnings"]:
			validation_warnings_log.append({
				"identifier": identifier,
				"resource_type": resource_type,
				"warning": warning,
				"timestamp": Time.get_unix_time_from_system()
			})

	# Performance monitoring
	if validation_time > 1000:  # 1 second threshold
		var warning_msg = "Resource %s validation took %d ms" % [identifier, validation_time]
		performance_warnings.append(warning_msg)
		performance_warning_issued.emit(warning_msg)

func log_validation_summary():
	"""Log validation error summary"""
	print("=== VALIDATION ERROR SUMMARY ===")
	for error in validation_errors_log:
		print("[%s] %s: %s" % [error["resource_type"], error["identifier"], error["error"]])

	if validation_warnings_log.size() > 0:
		print("\n=== VALIDATION WARNING SUMMARY ===")
		for warning in validation_warnings_log[:10]:  # Show first 10 warnings
			print("[%s] %s: %s" % [warning["resource_type"], warning["identifier"], warning["warning"]])

# ================== BACKGROUND LOADING SYSTEM ==================

func setup_background_loading() -> void:
	"""Setup background loading for performance optimization"""
	var loading_timer = Timer.new()
	loading_timer.wait_time = 0.1  # Process every 0.1 seconds
	loading_timer.timeout.connect(_process_loading_queue)
	add_child(loading_timer)
	loading_timer.start()

func queue_resource_load(resource_path: String, priority: String = "normal") -> void:
	"""Queue a resource for background loading"""
	var load_request = {
		"path": resource_path,
		"priority": priority,
		"timestamp": Time.get_unix_time_from_system(),
		"status": "queued"
	}

	# Insert based on priority
	var insertion_index = loading_queue.size()
	for i in range(loading_queue.size()):
		if loading_queue[i].priority == "high_priority" and priority != "high_priority":
			insertion_index = i
			break

	loading_queue.insert(insertion_index, load_request)

func _process_loading_queue() -> void:
	"""Process loading queue on timer"""
	if loading_queue.is_empty():
		return

	# Process up to the configured rate
	var processed_count = 0
	while loading_queue.size() > 0 and processed_count < queue_process_rate:
		var next_request = loading_queue.pop_front()
		_process_load_request(next_request)
		processed_count += 1

func _process_load_request(load_request: Dictionary) -> void:
	"""Process a single load request"""
	var resource_path = load_request["path"]
	var priority = load_request["priority"]

	# Skip if already loaded or active
	if resource_path in active_loads or resource_path in resource_cache:
		return

	# Mark as active load
	load_request["status"] = "loading"
	active_loads[resource_path] = load_request

	# Load with timing consideration
	var load_time_limit = 0.016 if priority == "high_priority" else 0.033  # 60fps vs 30fps
	var start_time = Time.get_ticks_usec()

	var resource = load_resource_by_path(resource_path, "unknown")  # Type will be determined by load

	if resource:
		load_request["status"] = "completed"
		load_request["resource"] = resource
	else:
		load_request["status"] = "failed"

	# Remove from active loads
	active_loads.erase(resource_path)

# ================== CACHING SYSTEM ==================

func _add_to_cache(resource_path: String, resource: Resource) -> void:
	"""Add resource to cache with memory management"""
	if not enable_advanced_caching:
		return

	# Check cache size limits
	if cache_entry_count >= resource_cache_size:
		_clear_oldest_cache_entries(50)

	# Add to cache
	resource_cache[resource_path] = resource
	cache_entry_count += 1

func clear_resource_cache() -> void:
	"""Completely clear resource cache"""
	resource_cache.clear()
	cache_entry_count = 0
	resource_dependencies.clear()
	resource_loading_error.emit("all", "Cache cleared")

func _clear_oldest_cache_entries(count: int) -> void:
	"""Remove oldest cache entries"""
	if cache_entry_count <= count:
		clear_resource_cache()
		return

	var keys_to_remove = []
	var all_keys = resource_cache.keys()

	for i in range(min(count, all_keys.size())):
		keys_to_remove.append(all_keys[i])

	for key in keys_to_remove:
		resource_cache.erase(key)
	cache_entry_count -= keys_to_remove.size()

# ================== PERFORMANCE MONITORING ==================

func record_performance_metric(operation_type: String, duration_ms: int) -> void:
	"""Record performance metrics for analysis"""
	if not load_time_metrics.has(operation_type):
		load_time_metrics[operation_type] = []

	load_time_metrics[operation_type].append(duration_ms)

func get_average_load_time(operation_type: String) -> float:
	"""Get average load time for operation type"""
	if not load_time_metrics.has(operation_type) or load_time_metrics[operation_type].is_empty():
		return 0.0

	var times = load_time_metrics[operation_type]
	var total = 0
	for time in times:
		total += time

	return float(total) / times.size()

func get_performance_summary() -> Dictionary:
	"""Get comprehensive performance summary"""
	return {
		"total_resources_loaded": resources_loaded_total,
		"cache_hit_rate": _calculate_cache_hit_rate(),
		"cache_entry_count": cache_entry_count,
		"average_load_times": {
			"species": get_average_load_time("species_load"),
			"ships": get_average_load_time("ship_load"),
			"weapons": get_average_load_time("weapon_load"),
			"environmental": get_average_load_time("environment_load")
		},
		"validation_summary": {
			"validation_errors": validation_errors_log.size(),
			"validation_warnings": validation_warnings_log.size()
		},
		"performance_warnings": performance_warnings.duplicate()
	}

func _calculate_cache_hit_rate() -> float:
	"""Calculate overall cache hit rate"""
	var total_hits = 0
	var total_misses = 0

	for count in cache_hit_statistics.values():
		total_hits += count
	for count in cache_miss_statistics.values():
		total_misses += count

	return float(total_hits) / max(total_hits + total_misses, 1)

func get_validation_summary() -> Dictionary:
	"""Get validation status summary"""
	return {
		"total_errors": validation_errors_log.size(),
		"total_warnings": validation_warnings_log.size(),
		"resources_with_errors": _count_resources_with_validation_issues("error"),
		"resources_with_warnings": _count_resources_with_validation_issues("warning"),
		"validation_states": resource_validation_states.duplicate()
	}

func _count_resources_with_validation_issues(issue_type: String) -> int:
	"""Count resources with validation issues"""
	var log_to_check = validation_errors_log if issue_type == "error" else validation_warnings_log
	var affected_resources = []

	for entry in log_to_check:
		var identifier = entry.get("identifier", "")
		if identifier and not identifier in affected_resources:
			affected_resources.append(identifier)

	return affected_resources.size()

# ================== UTILITY METHODS ==================

func get_ship_stats_path(ship_class: String) -> String:
	"""Generate resource path for ship stats"""
	var sanitized = ship_class.replace(" ", "_").replace("/", "_").replace("-", "_")
	return resources_base_path.path_join(ships_path).path_join(sanitized + ".ship_stats.tres")

func get_weapon_data_path(weapon_class: String) -> String:
	"""Generate resource path for weapon data"""
	var sanitized = weapon_class.replace(" ", "_").replace("/", "_").replace("-", "_")
	return resources_base_path.path_join(weapons_path).path_join(sanitized + ".weapon_data.tres")

func get_species_data_path(species_name: String) -> String:
	"""Generate resource path for species data"""
	return resources_base_path.path_join(species_path).path_join(species_name + ".species_data.tres")

func get_environment_path(env_name: String, env_type: String) -> String:
	"""Generate resource path for environment data"""
	var suffix = "nebula_data.tres" if env_type == "nebula" else "asteroid_data.tres"
	var sanitized = env_name.replace(" ", "_").replace("/", "_").replace("-", "_")
	return resources_base_path.path_join(environment_path).path_join(sanitized + "." + suffix)

func get_full_registry_state() -> Dictionary:
	"""Get complete state of all registries"""
	return {
		"species_count": species_registry.size(),
		"ship_count": ship_registry.size(),
		"weapon_count": weapon_registry.size(),
		"environmental_count": environmental_registry.size(),
		"effect_count": effect_registry.size(),
		"audio_count": audio_registry.size(),
		"total_resources": get_total_resource_count()
	}

func generate_comprehensive_report() -> String:
	"""Generate comprehensive system report"""
	var report = "=== WCS Resource Manager Comprehensive Report ===\n\n"

	report += "Resource Statistics:\n"
	for category, count in get_full_registry_state().items():
		report += "  %s: %d\n" % [category.replace("_count", "").replace("_", " ").title(), count]

	report += "\nPerformance Summary:\n"
	for category, avg_time in load_time_metrics.items():
		if avg_time.size() > 0:
			report += "  %s: %.2f ms average\n" % [category.replace("_", " ").title(), get_average_load_time(category)]

	report += "\nCache Performance:\n"
	report += "  Hit Rate: %.1f%%\n" % (_calculate_cache_hit_rate() * 100)
	report += "  Cached Entries: %d\n" % cache_entry_count

	report += "\nValidation Statistics:\n"
	report += "  Total Errors: %d\n" % validation_errors_log.size()
	report += "  Total Warnings: %d\n" % validation_warnings_log.size()
	report += "  Resources with Errors: %d\n" % _count_resources_with_validation_issues("error")
	report += "  Resources with Warnings: %d\n" % _count_resources_with_validation_issues("warning")

	report += "\nSystem Status:\n"
	report += "  Background Loading: %s\n" % ("Enabled" if enable_background_loading else "Disabled")
	report += "  Advanced Caching: %s\n" % ("Enabled" if enable_advanced_caching else "Disabled")
	report += "  Validation on Load: %s\n" % ("Enabled" if validation_on_load else "Disabled")

	return report

func _exit_tree() -> void:
	"""Cleanup on exit"""
	print("Shutting down WCS Resource Manager...")
	print(generate_comprehensive_report())
	clear_resource_cache()
	print("WCS Resource Manager shutdown complete")