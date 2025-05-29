class_name AssetUtils
extends RefCounted

## Utility functions for the WCS Asset Core addon.
## Provides helper functions for asset operations, migration, and integration.

## Asset Migration Utilities

static func migrate_legacy_asset_manager() -> Dictionary:
	"""Migrate from the existing AssetManager to the new addon system.
	Returns:
		Migration report with statistics"""
	
	var report: Dictionary = {
		"assets_migrated": 0,
		"errors": [],
		"warnings": [],
		"start_time": Time.get_unix_time_from_system()
	}
	
	# Check if legacy AssetManager exists
	if not has_node("/root/AssetManager"):
		report["warnings"].append("Legacy AssetManager not found - no migration needed")
		return report
	
	var legacy_manager: Node = get_node("/root/AssetManager")
	
	# Migrate cached assets if possible
	if legacy_manager.has_method("get_cache_stats"):
		var cache_stats: Dictionary = legacy_manager.get_cache_stats()
		report["legacy_cache_size"] = cache_stats.get("cached_assets", 0)
	
	# Clear legacy cache to free memory
	if legacy_manager.has_method("clear_cache"):
		legacy_manager.clear_cache()
		report["warnings"].append("Legacy AssetManager cache cleared")
	
	report["end_time"] = Time.get_unix_time_from_system()
	report["duration_seconds"] = report["end_time"] - report["start_time"]
	
	return report

static func create_migration_mapping() -> Dictionary:
	"""Create mapping from legacy asset paths to new addon paths.
	Returns:
		Dictionary mapping old paths to new paths"""
	
	return {
		# Legacy script paths to addon structure paths
		"scripts/resources/ship_weapon/ship_data.gd": "addons/wcs_asset_core/structures/ship_data.gd",
		"scripts/resources/ship_weapon/weapon_data.gd": "addons/wcs_asset_core/structures/weapon_data.gd",
		"scripts/resources/ship_weapon/armor_data.gd": "addons/wcs_asset_core/structures/armor_data.gd",
		"autoload/AssetManager.gd": "addons/wcs_asset_core/loaders/asset_loader.gd",
		
		# Legacy resource paths to standardized paths
		"res://assets/ships/": "res://assets/ships/",
		"res://assets/weapons/": "res://assets/weapons/",
		"res://assets/armor/": "res://assets/armor/"
	}

static func update_script_references(script_path: String) -> bool:
	"""Update script references to use the new addon system.
	Args:
		script_path: Path to script file to update
	Returns:
		true if script was updated successfully"""
	
	if not FileAccess.file_exists(script_path):
		return false
	
	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return false
	
	var content: String = file.get_as_text()
	file.close()
	
	var updated: bool = false
	var mapping: Dictionary = create_migration_mapping()
	
	# Replace legacy references with addon references
	for old_path in mapping.keys():
		var new_path: String = mapping[old_path]
		if content.contains(old_path):
			content = content.replace(old_path, new_path)
			updated = true
	
	# Update common legacy patterns
	if content.contains("AssetManager.load_asset"):
		content = content.replace("AssetManager.load_asset", "WCSAssetLoader.load_asset")
		updated = true
	
	if content.contains("AssetManager.get_cache_stats"):
		content = content.replace("AssetManager.get_cache_stats", "WCSAssetLoader.get_cache_stats")
		updated = true
	
	# Save updated content if changes were made
	if updated:
		var output_file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
		if output_file != null:
			output_file.store_string(content)
			output_file.close()
			return true
	
	return false

## Asset Conversion Utilities

static func convert_legacy_ship_data(legacy_path: String, output_path: String) -> bool:
	"""Convert legacy ShipData to new addon format.
	Args:
		legacy_path: Path to legacy ship data file
		output_path: Path for converted ship data
	Returns:
		true if conversion successful"""
	
	var legacy_resource: Resource = load(legacy_path)
	if legacy_resource == null:
		return false
	
	# Create new ship data using addon structure
	var new_ship: ShipData = ShipData.new()
	
	# Convert from legacy format
	new_ship.convert_from_legacy_ship_data(legacy_resource)
	
	# Set conversion metadata
	new_ship.source_file = legacy_path
	new_ship.conversion_notes = "Converted from legacy ShipData format"
	new_ship.asset_version = "1.0.0"
	
	# Save new format
	var save_result: int = ResourceSaver.save(new_ship, output_path)
	return save_result == OK

static func convert_legacy_weapon_data(legacy_path: String, output_path: String) -> bool:
	"""Convert legacy WeaponData to new addon format.
	Args:
		legacy_path: Path to legacy weapon data file
		output_path: Path for converted weapon data
	Returns:
		true if conversion successful"""
	
	var legacy_resource: Resource = load(legacy_path)
	if legacy_resource == null:
		return false
	
	# Create new weapon data using addon structure
	var new_weapon: WeaponData = WeaponData.new()
	
	# Convert from legacy format
	new_weapon.convert_from_legacy_weapon_data(legacy_resource)
	
	# Set conversion metadata
	new_weapon.source_file = legacy_path
	new_weapon.conversion_notes = "Converted from legacy WeaponData format"
	new_weapon.asset_version = "1.0.0"
	
	# Save new format
	var save_result: int = ResourceSaver.save(new_weapon, output_path)
	return save_result == OK

## Integration Utilities

static func setup_addon_integration() -> Dictionary:
	"""Set up integration between addon and existing systems.
	Returns:
		Integration report"""
	
	var report: Dictionary = {
		"success": true,
		"autoloads_configured": 0,
		"errors": [],
		"warnings": []
	}
	
	# Check if addon autoloads are properly configured
	var required_autoloads: Array[String] = [
		"WCSAssetLoader",
		"WCSAssetRegistry", 
		"WCSAssetValidator"
	]
	
	for autoload_name in required_autoloads:
		if has_node("/root/" + autoload_name):
			report["autoloads_configured"] += 1
		else:
			report["errors"].append("Autoload not found: " + autoload_name)
			report["success"] = false
	
	# Check addon plugin status
	if not ProjectSettings.has_setting("application/config/project_settings_override"):
		report["warnings"].append("Project settings may need manual configuration")
	
	return report

static func validate_integration() -> Dictionary:
	"""Validate that addon integration is working correctly.
	Returns:
		Validation report"""
	
	var report: Dictionary = {
		"valid": true,
		"tests_passed": 0,
		"tests_failed": 0,
		"errors": [],
		"warnings": []
	}
	
	# Test asset loader
	if has_node("/root/WCSAssetLoader"):
		var loader: Node = get_node("/root/WCSAssetLoader")
		if loader.has_method("get_cache_stats"):
			report["tests_passed"] += 1
		else:
			report["tests_failed"] += 1
			report["errors"].append("WCSAssetLoader missing expected methods")
	else:
		report["tests_failed"] += 1
		report["errors"].append("WCSAssetLoader autoload not found")
	
	# Test asset registry
	if has_node("/root/WCSAssetRegistry"):
		var registry: Node = get_node("/root/WCSAssetRegistry")
		if registry.has_method("get_asset_count"):
			report["tests_passed"] += 1
		else:
			report["tests_failed"] += 1
			report["errors"].append("WCSAssetRegistry missing expected methods")
	else:
		report["tests_failed"] += 1
		report["errors"].append("WCSAssetRegistry autoload not found")
	
	# Test asset validator
	if has_node("/root/WCSAssetValidator"):
		var validator: Node = get_node("/root/WCSAssetValidator")
		if validator.has_method("validate_asset"):
			report["tests_passed"] += 1
		else:
			report["tests_failed"] += 1
			report["errors"].append("WCSAssetValidator missing expected methods")
	else:
		report["tests_failed"] += 1
		report["errors"].append("WCSAssetValidator autoload not found")
	
	report["valid"] = report["tests_failed"] == 0
	
	return report

## Performance Utilities

static func benchmark_asset_loading(asset_paths: Array[String], iterations: int = 10) -> Dictionary:
	"""Benchmark asset loading performance.
	Args:
		asset_paths: Array of asset paths to test
		iterations: Number of iterations per asset
	Returns:
		Benchmark results"""
	
	var results: Dictionary = {
		"total_time_ms": 0,
		"average_time_ms": 0.0,
		"assets_tested": 0,
		"iterations": iterations,
		"cache_hit_ratio": 0.0,
		"errors": []
	}
	
	if not has_node("/root/WCSAssetLoader"):
		results["errors"].append("WCSAssetLoader not available")
		return results
	
	var loader: Node = get_node("/root/WCSAssetLoader")
	var total_time: int = 0
	var successful_loads: int = 0
	
	for asset_path in asset_paths:
		for i in range(iterations):
			var start_time: int = Time.get_ticks_msec()
			
			var asset: BaseAssetData = loader.load_asset(asset_path, i == 0)  # Force reload on first iteration
			
			var end_time: int = Time.get_ticks_msec()
			total_time += (end_time - start_time)
			
			if asset != null:
				successful_loads += 1
			else:
				results["errors"].append("Failed to load: " + asset_path)
	
	results["total_time_ms"] = total_time
	results["assets_tested"] = asset_paths.size()
	results["successful_loads"] = successful_loads
	
	if successful_loads > 0:
		results["average_time_ms"] = float(total_time) / successful_loads
	
	# Get cache statistics if available
	if loader.has_method("get_cache_stats"):
		var cache_stats: Dictionary = loader.get_cache_stats()
		results["cache_hit_ratio"] = cache_stats.get("hit_ratio", 0.0)
	
	return results

static func optimize_asset_loading() -> Dictionary:
	"""Optimize asset loading performance.
	Returns:
		Optimization report"""
	
	var report: Dictionary = {
		"optimizations_applied": 0,
		"recommendations": [],
		"warnings": []
	}
	
	if not has_node("/root/WCSAssetLoader"):
		report["warnings"].append("WCSAssetLoader not available for optimization")
		return report
	
	var loader: Node = get_node("/root/WCSAssetLoader")
	
	# Check cache settings
	if loader.has_method("get_cache_stats"):
		var cache_stats: Dictionary = loader.get_cache_stats()
		var hit_ratio: float = cache_stats.get("hit_ratio", 0.0)
		
		if hit_ratio < 0.5:
			report["recommendations"].append("Consider increasing cache size - current hit ratio: %.1f%%" % (hit_ratio * 100))
		
		var cached_assets: int = cache_stats.get("cached_assets", 0)
		if cached_assets == 0:
			report["recommendations"].append("Enable asset caching for better performance")
	
	# Check registry for preloading opportunities
	if has_node("/root/WCSAssetRegistry"):
		var registry: Node = get_node("/root/WCSAssetRegistry")
		if registry.has_method("get_asset_count"):
			var total_assets: int = registry.get_asset_count()
			if total_assets > 100:
				report["recommendations"].append("Consider creating asset groups for batch preloading")
	
	return report

## Debugging and Diagnostics

static func generate_diagnostic_report() -> Dictionary:
	"""Generate comprehensive diagnostic report for the addon system.
	Returns:
		Detailed diagnostic information"""
	
	var report: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"addon_version": "1.0.0",
		"godot_version": Engine.get_version_info(),
		"autoloads": {},
		"performance": {},
		"errors": [],
		"warnings": []
	}
	
	# Check autoload status
	var autoloads: Array[String] = ["WCSAssetLoader", "WCSAssetRegistry", "WCSAssetValidator"]
	for autoload_name in autoloads:
		var autoload_info: Dictionary = {
			"exists": has_node("/root/" + autoload_name),
			"ready": false,
			"methods": []
		}
		
		if autoload_info["exists"]:
			var node: Node = get_node("/root/" + autoload_name)
			autoload_info["ready"] = node.is_inside_tree()
			
			# Check for expected methods
			match autoload_name:
				"WCSAssetLoader":
					autoload_info["methods"] = _check_methods(node, ["load_asset", "get_cache_stats", "clear_cache"])
				"WCSAssetRegistry":
					autoload_info["methods"] = _check_methods(node, ["scan_asset_directories", "get_asset_count", "search_assets"])
				"WCSAssetValidator":
					autoload_info["methods"] = _check_methods(node, ["validate_asset", "get_validation_stats"])
		
		report["autoloads"][autoload_name] = autoload_info
	
	# Collect performance data
	if has_node("/root/WCSAssetLoader"):
		var loader: Node = get_node("/root/WCSAssetLoader")
		if loader.has_method("get_cache_stats"):
			report["performance"]["cache_stats"] = loader.get_cache_stats()
	
	if has_node("/root/WCSAssetRegistry"):
		var registry: Node = get_node("/root/WCSAssetRegistry")
		if registry.has_method("get_registry_stats"):
			report["performance"]["registry_stats"] = registry.get_registry_stats()
	
	if has_node("/root/WCSAssetValidator"):
		var validator: Node = get_node("/root/WCSAssetValidator")
		if validator.has_method("get_validation_stats"):
			report["performance"]["validation_stats"] = validator.get_validation_stats()
	
	return report

static func _check_methods(node: Node, expected_methods: Array[String]) -> Dictionary:
	"""Check if a node has expected methods.
	Args:
		node: Node to check
		expected_methods: Array of method names to check
	Returns:
		Dictionary mapping method names to existence"""
	
	var method_status: Dictionary = {}
	
	for method_name in expected_methods:
		method_status[method_name] = node.has_method(method_name)
	
	return method_status

static func has_node(path: String) -> bool:
	"""Check if a node exists at the given path.
	Args:
		path: Node path to check
	Returns:
		true if node exists"""
	
	# This is a simplified version - in real implementation would use Engine or SceneTree
	return Engine.has_singleton(path.get_file())

static func get_node(path: String) -> Node:
	"""Get a node at the given path.
	Args:
		path: Node path
	Returns:
		Node instance or null"""
	
	# This is a simplified version - in real implementation would use SceneTree
	return null
