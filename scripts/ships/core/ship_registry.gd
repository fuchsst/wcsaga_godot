class_name ShipRegistry
extends RefCounted

## Ship registry for efficient ship class and template lookup
## Manages ship definitions, variants, and template configurations
## Supports WCS naming conventions and fast lookup operations

# Registry storage
var ship_classes: Dictionary = {}           # String -> ShipClass
var ship_templates: Dictionary = {}         # String -> ShipTemplate
var name_to_path_map: Dictionary = {}       # String -> String (resource path)
var variant_map: Dictionary = {}            # String -> Array[String] (base -> variants)
var faction_ships: Dictionary = {}          # String -> Array[String] (faction -> ship names)
var type_indices: Dictionary = {}           # ShipTypes.Type -> Array[String]

# Registry configuration
var auto_scan_enabled: bool = true
var scan_directories: Array[String] = [
	"res://resources/ships/",
	"res://addons/wcs_asset_core/resources/ship/"
]
var cache_enabled: bool = true
var last_scan_time: float = 0.0
var scan_interval: float = 5.0  # Rescan every 5 seconds in editor

# Performance tracking
var lookup_count: int = 0
var cache_hits: int = 0
var cache_misses: int = 0

func _init() -> void:
	if auto_scan_enabled:
		scan_ship_resources()

## Scan ship resources and build registry
func scan_ship_resources() -> void:
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	print("ShipRegistry: Scanning ship resources...")
	
	# Clear existing registry
	_clear_registry()
	
	# Scan each directory
	for directory in scan_directories:
		_scan_directory_recursive(directory)
	
	# Build indices
	_build_type_indices()
	_build_variant_map()
	_build_faction_map()
	
	var end_time: float = Time.get_ticks_msec() / 1000.0
	last_scan_time = end_time
	
	print("ShipRegistry: Scan completed in %.3f seconds. Found %d classes, %d templates" % [
		end_time - start_time,
		ship_classes.size(),
		ship_templates.size()
	])

## Get ship class by name
func get_ship_class(class_name: String) -> ShipClass:
	lookup_count += 1
	
	# Check cache first
	if ship_classes.has(class_name):
		cache_hits += 1
		return ship_classes[class_name]
	
	# Try to load from path
	if name_to_path_map.has(class_name):
		var resource_path: String = name_to_path_map[class_name]
		var ship_class: ShipClass = load(resource_path) as ShipClass
		
		if ship_class != null:
			if cache_enabled:
				ship_classes[class_name] = ship_class
			cache_hits += 1
			return ship_class
	
	cache_misses += 1
	return null

## Get ship template by name (including variant suffix)
func get_ship_template(template_name: String) -> ShipTemplate:
	lookup_count += 1
	
	# Check cache first
	if ship_templates.has(template_name):
		cache_hits += 1
		return ship_templates[template_name]
	
	# Try to load from path
	if name_to_path_map.has(template_name):
		var resource_path: String = name_to_path_map[template_name]
		var template: ShipTemplate = load(resource_path) as ShipTemplate
		
		if template != null:
			if cache_enabled:
				ship_templates[template_name] = template
			cache_hits += 1
			return template
	
	cache_misses += 1
	return null

## Get all ship classes of a specific type
func get_ships_by_type(ship_type: ShipTypes.Type) -> Array[String]:
	if type_indices.has(ship_type):
		return type_indices[ship_type].duplicate()
	return []

## Get all variants of a base ship
func get_ship_variants(base_ship_name: String) -> Array[String]:
	if variant_map.has(base_ship_name):
		return variant_map[base_ship_name].duplicate()
	return []

## Get all ships from a specific faction
func get_ships_by_faction(faction: String) -> Array[String]:
	if faction_ships.has(faction):
		return faction_ships[faction].duplicate()
	return []

## Check if ship class exists
func has_ship_class(class_name: String) -> bool:
	return ship_classes.has(class_name) or name_to_path_map.has(class_name)

## Check if ship template exists
func has_ship_template(template_name: String) -> bool:
	return ship_templates.has(template_name) or name_to_path_map.has(template_name)

## Register a ship class manually
func register_ship_class(ship_class: ShipClass, resource_path: String = "") -> bool:
	if ship_class == null or ship_class.class_name.is_empty():
		push_error("ShipRegistry: Invalid ship class for registration")
		return false
	
	ship_classes[ship_class.class_name] = ship_class
	
	if not resource_path.is_empty():
		name_to_path_map[ship_class.class_name] = resource_path
	
	# Update indices
	_add_to_type_index(ship_class.class_name, ship_class.ship_type)
	_add_to_faction_map(ship_class.class_name, ship_class.species)
	
	return true

## Register a ship template manually
func register_ship_template(template: ShipTemplate, resource_path: String = "") -> bool:
	if template == null or template.template_name.is_empty():
		push_error("ShipRegistry: Invalid ship template for registration")
		return false
	
	var full_name: String = template.get_full_name()
	ship_templates[full_name] = template
	
	if not resource_path.is_empty():
		name_to_path_map[full_name] = resource_path
	
	# Update variant map
	_add_to_variant_map(template.template_name, full_name)
	
	return true

## Search ships by pattern
func search_ships(pattern: String, include_templates: bool = true) -> Array[String]:
	var results: Array[String] = []
	var pattern_lower: String = pattern.to_lower()
	
	# Search ship classes
	for class_name in ship_classes.keys():
		if class_name.to_lower().contains(pattern_lower):
			results.append(class_name)
	
	# Search ship templates
	if include_templates:
		for template_name in ship_templates.keys():
			if template_name.to_lower().contains(pattern_lower):
				results.append(template_name)
	
	return results

## Get all ship class names
func get_all_ship_class_names() -> Array[String]:
	var names: Array[String] = []
	names.append_array(ship_classes.keys())
	
	# Add names from path map that aren't loaded yet
	for name in name_to_path_map.keys():
		if not ship_classes.has(name) and _is_ship_class_path(name_to_path_map[name]):
			names.append(name)
	
	names.sort()
	return names

## Get all ship template names
func get_all_ship_template_names() -> Array[String]:
	var names: Array[String] = []
	names.append_array(ship_templates.keys())
	
	# Add names from path map that aren't loaded yet
	for name in name_to_path_map.keys():
		if not ship_templates.has(name) and _is_ship_template_path(name_to_path_map[name]):
			names.append(name)
	
	names.sort()
	return names

## Clear registry cache
func clear_cache() -> void:
	ship_classes.clear()
	ship_templates.clear()
	cache_hits = 0
	cache_misses = 0

## Clear entire registry
func _clear_registry() -> void:
	ship_classes.clear()
	ship_templates.clear()
	name_to_path_map.clear()
	variant_map.clear()
	faction_ships.clear()
	type_indices.clear()

## Scan directory recursively for ship resources
func _scan_directory_recursive(directory: String) -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			# Recurse into subdirectory
			_scan_directory_recursive(full_path)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			# Try to load and register resource
			_try_register_resource(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

## Try to register a resource file
func _try_register_resource(resource_path: String) -> void:
	var resource: Resource = load(resource_path)
	
	if resource is ShipClass:
		var ship_class: ShipClass = resource as ShipClass
		if not ship_class.class_name.is_empty():
			name_to_path_map[ship_class.class_name] = resource_path
			
			# Load immediately if cache is enabled
			if cache_enabled:
				ship_classes[ship_class.class_name] = ship_class
	
	elif resource is ShipTemplate:
		var template: ShipTemplate = resource as ShipTemplate
		if not template.template_name.is_empty():
			var full_name: String = template.get_full_name()
			name_to_path_map[full_name] = resource_path
			
			# Load immediately if cache is enabled
			if cache_enabled:
				ship_templates[full_name] = template

## Build type indices for fast lookup
func _build_type_indices() -> void:
	type_indices.clear()
	
	# Initialize arrays for each ship type
	for ship_type in ShipTypes.Type.values():
		type_indices[ship_type] = []
	
	# Categorize loaded ship classes
	for class_name in ship_classes.keys():
		var ship_class: ShipClass = ship_classes[class_name]
		_add_to_type_index(class_name, ship_class.ship_type)

## Build variant map for variant lookup
func _build_variant_map() -> void:
	variant_map.clear()
	
	# Process ship templates to find variants
	for template_name in ship_templates.keys():
		var template: ShipTemplate = ship_templates[template_name]
		if not template.variant_suffix.is_empty():
			_add_to_variant_map(template.template_name, template_name)

## Build faction map for faction-based lookup
func _build_faction_map() -> void:
	faction_ships.clear()
	
	# Categorize ship classes by faction
	for class_name in ship_classes.keys():
		var ship_class: ShipClass = ship_classes[class_name]
		_add_to_faction_map(class_name, ship_class.species)

## Add ship to type index
func _add_to_type_index(class_name: String, ship_type: int) -> void:
	if not type_indices.has(ship_type):
		type_indices[ship_type] = []
	
	if not type_indices[ship_type].has(class_name):
		type_indices[ship_type].append(class_name)

## Add ship to variant map
func _add_to_variant_map(base_name: String, variant_name: String) -> void:
	if not variant_map.has(base_name):
		variant_map[base_name] = []
	
	if not variant_map[base_name].has(variant_name):
		variant_map[base_name].append(variant_name)

## Add ship to faction map
func _add_to_faction_map(class_name: String, faction: String) -> void:
	if faction.is_empty():
		faction = "Unknown"
	
	if not faction_ships.has(faction):
		faction_ships[faction] = []
	
	if not faction_ships[faction].has(class_name):
		faction_ships[faction].append(class_name)

## Check if path is for a ship class
func _is_ship_class_path(path: String) -> bool:
	# This is a simple heuristic - could be improved
	return path.contains("ship") and not path.contains("template")

## Check if path is for a ship template
func _is_ship_template_path(path: String) -> bool:
	# This is a simple heuristic - could be improved
	return path.contains("template") or path.contains("variant")

## Get registry statistics
func get_registry_statistics() -> Dictionary:
	var cache_hit_rate: float = 0.0
	if lookup_count > 0:
		cache_hit_rate = float(cache_hits) / float(lookup_count) * 100.0
	
	return {
		"ship_classes_loaded": ship_classes.size(),
		"ship_templates_loaded": ship_templates.size(),
		"total_paths_mapped": name_to_path_map.size(),
		"lookup_count": lookup_count,
		"cache_hits": cache_hits,
		"cache_misses": cache_misses,
		"cache_hit_rate": cache_hit_rate,
		"last_scan_time": last_scan_time
	}

## Check if registry needs refresh
func needs_refresh() -> bool:
	if not auto_scan_enabled:
		return false
	
	var current_time: float = Time.get_ticks_msec() / 1000.0
	return (current_time - last_scan_time) > scan_interval

## Refresh registry if needed
func refresh_if_needed() -> void:
	if needs_refresh():
		scan_ship_resources()

## Get registry status for debugging
func get_registry_status() -> String:
	var stats: Dictionary = get_registry_statistics()
	return "ShipRegistry: %d classes, %d templates, %.1f%% cache hit rate" % [
		stats["ship_classes_loaded"],
		stats["ship_templates_loaded"],
		stats["cache_hit_rate"]
	]