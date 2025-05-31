@tool
class_name AssetPerformanceTracker
extends RefCounted

## Asset performance tracker for GFRED2 Performance Profiling and Optimization Tools.
## Shows polygon counts, texture usage, and memory impact of mission assets.

signal tracking_started()
signal tracking_progress(percentage: float, current_asset: String)
signal tracking_completed(results: Dictionary)
signal asset_performance_issue(asset_name: String, issue_type: String, severity: String, details: String)

# Performance thresholds
const MAX_POLYGON_COUNT_PER_SHIP: int = 5000
const MAX_TEXTURE_SIZE_MB: float = 4.0
const MAX_TOTAL_TEXTURE_MEMORY_MB: float = 256.0
const MAX_ASSET_LOAD_TIME_MS: float = 100.0

# Asset categories for tracking
enum AssetCategory {
	SHIPS,
	WEAPONS,
	TEXTURES,
	MODELS,
	AUDIO,
	EFFECTS
}

# Core dependencies
var asset_registry: WCSAssetRegistry
var asset_loader: WCSAssetLoader
var mission_data: MissionData

# Tracking state
var is_tracking: bool = false
var tracked_assets: Dictionary = {}
var performance_metrics: Dictionary = {}
var memory_usage: Dictionary = {}

func _init() -> void:
	asset_registry = WCSAssetRegistry
	asset_loader = WCSAssetLoader
	_initialize_tracking()

## Initializes asset performance tracking
func _initialize_tracking() -> void:
	tracked_assets.clear()
	performance_metrics = {
		"ships": {
			"total_polygons": 0,
			"average_polygons": 0.0,
			"max_polygons": 0,
			"total_assets": 0,
			"load_times": []
		},
		"textures": {
			"total_memory_mb": 0.0,
			"average_size_mb": 0.0,
			"largest_texture_mb": 0.0,
			"texture_count": 0,
			"compression_efficiency": 0.0
		},
		"models": {
			"total_vertices": 0,
			"total_triangles": 0,
			"lod_levels_available": 0,
			"model_count": 0
		},
		"memory": {
			"total_memory_mb": 0.0,
			"gpu_memory_mb": 0.0,
			"cpu_memory_mb": 0.0,
			"streaming_potential_mb": 0.0
		}
	}

## Tracks asset performance for entire mission
func track_mission_asset_performance(mission: MissionData) -> Dictionary:
	if is_tracking:
		push_warning("Asset tracking already in progress")
		return {}
	
	mission_data = mission
	is_tracking = true
	_initialize_tracking()
	
	tracking_started.emit()
	print("Starting asset performance tracking...")
	
	var start_time: float = Time.get_ticks_msec()
	
	# Collect unique assets from mission
	var unique_assets: Dictionary = _collect_unique_assets(mission)
	var total_assets: int = unique_assets.size()
	var processed_assets: int = 0
	
	# Track each asset category
	for asset_name in unique_assets.keys():
		var asset_type: String = unique_assets[asset_name]
		_track_asset_performance(asset_name, asset_type)
		
		processed_assets += 1
		tracking_progress.emit(float(processed_assets) / total_assets * 100.0, asset_name)
	
	# Analyze overall performance
	_analyze_overall_performance()
	
	var tracking_time: float = Time.get_ticks_msec() - start_time
	
	# Generate results
	var results: Dictionary = _generate_tracking_results(tracking_time)
	
	is_tracking = false
	tracking_completed.emit(results)
	
	print("Asset tracking completed in %.2f ms" % tracking_time)
	return results

## Collects unique assets referenced in mission
func _collect_unique_assets(mission: MissionData) -> Dictionary:
	var unique_assets: Dictionary = {}
	
	# Collect ship assets
	for obj in mission.objects.values():
		if obj.has_method("get_ship_class"):
			var ship_class: String = obj.get_ship_class()
			if not ship_class.is_empty():
				unique_assets[ship_class] = "ship"
	
	# Collect weapon assets (from ship loadouts)
	var ship_paths: Array[String] = asset_registry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
	for ship_path in ship_paths:
		var ship_data: ShipData = asset_loader.load_asset(ship_path)
		if ship_data:
			# Collect weapons from ship loadouts
			for weapon_slot in ship_data.weapon_slots:
				if weapon_slot.has("default_weapon") and not weapon_slot.default_weapon.is_empty():
					unique_assets[weapon_slot.default_weapon] = "weapon"
	
	# Collect texture assets (from ship and weapon references)
	# This would require more detailed asset inspection
	
	print("Collected %d unique assets for tracking" % unique_assets.size())
	return unique_assets

## Tracks performance for individual asset
func _track_asset_performance(asset_name: String, asset_type: String) -> void:
	var start_time: float = Time.get_ticks_msec()
	
	var asset_data: Dictionary = {
		"name": asset_name,
		"type": asset_type,
		"load_time_ms": 0.0,
		"memory_usage_mb": 0.0,
		"polygon_count": 0,
		"vertex_count": 0,
		"texture_memory_mb": 0.0,
		"optimization_score": 0.0,
		"issues": []
	}
	
	# Track based on asset type
	match asset_type:
		"ship":
			_track_ship_asset(asset_name, asset_data)
		"weapon":
			_track_weapon_asset(asset_name, asset_data)
		"texture":
			_track_texture_asset(asset_name, asset_data)
		"model":
			_track_model_asset(asset_name, asset_data)
	
	asset_data.load_time_ms = Time.get_ticks_msec() - start_time
	
	# Check for performance issues
	_check_asset_performance_issues(asset_data)
	
	# Store tracking data
	tracked_assets[asset_name] = asset_data
	
	# Update performance metrics
	_update_performance_metrics(asset_data)

## Tracks ship asset performance
func _track_ship_asset(asset_name: String, asset_data: Dictionary) -> void:
	# Try to load ship data
	var ship_paths: Array[String] = asset_registry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
	var ship_data: ShipData = null
	
	for ship_path in ship_paths:
		var test_data: ShipData = asset_loader.load_asset(ship_path)
		if test_data and test_data.ship_name == asset_name:
			ship_data = test_data
			break
	
	if not ship_data:
		asset_data.issues.append("Ship data not found")
		return
	
	# Analyze ship model complexity
	asset_data.polygon_count = _estimate_polygon_count(ship_data.model_path)
	asset_data.vertex_count = asset_data.polygon_count * 3  # Rough estimate
	
	# Analyze texture usage
	asset_data.texture_memory_mb = _estimate_texture_memory(ship_data.texture_paths)
	
	# Calculate memory usage
	asset_data.memory_usage_mb = (asset_data.vertex_count * 32) / (1024 * 1024)  # Rough vertex data estimate
	asset_data.memory_usage_mb += asset_data.texture_memory_mb
	
	# Calculate optimization score
	asset_data.optimization_score = _calculate_ship_optimization_score(asset_data, ship_data)

## Tracks weapon asset performance
func _track_weapon_asset(asset_name: String, asset_data: Dictionary) -> void:
	# Try to load weapon data
	var weapon_paths: Array[String] = asset_registry.get_asset_paths_by_type(AssetTypes.Type.WEAPON)
	var weapon_data: WeaponData = null
	
	for weapon_path in weapon_paths:
		var test_data: WeaponData = asset_loader.load_asset(weapon_path)
		if test_data and test_data.weapon_name == asset_name:
			weapon_data = test_data
			break
	
	if not weapon_data:
		asset_data.issues.append("Weapon data not found")
		return
	
	# Analyze weapon model (if has 3D model)
	if weapon_data.has("model_path") and not weapon_data.model_path.is_empty():
		asset_data.polygon_count = _estimate_polygon_count(weapon_data.model_path)
		asset_data.vertex_count = asset_data.polygon_count * 3
	
	# Weapon memory usage is typically smaller
	asset_data.memory_usage_mb = 0.1  # Base weapon data
	
	if weapon_data.has("texture_paths"):
		asset_data.texture_memory_mb = _estimate_texture_memory(weapon_data.texture_paths)
		asset_data.memory_usage_mb += asset_data.texture_memory_mb
	
	# Calculate optimization score
	asset_data.optimization_score = _calculate_weapon_optimization_score(asset_data, weapon_data)

## Tracks texture asset performance
func _track_texture_asset(asset_name: String, asset_data: Dictionary) -> void:
	# This would require actual texture file analysis
	# For now, provide estimates based on typical texture sizes
	
	var texture_size_mb: float = 1.0  # Default estimate
	
	# Estimate based on texture name patterns
	if "diffuse" in asset_name.to_lower() or "color" in asset_name.to_lower():
		texture_size_mb = 2.0  # Diffuse textures typically larger
	elif "normal" in asset_name.to_lower() or "bump" in asset_name.to_lower():
		texture_size_mb = 1.5  # Normal maps
	elif "specular" in asset_name.to_lower() or "gloss" in asset_name.to_lower():
		texture_size_mb = 1.0  # Specular maps
	
	asset_data.texture_memory_mb = texture_size_mb
	asset_data.memory_usage_mb = texture_size_mb
	
	# Basic optimization score for textures
	asset_data.optimization_score = 80.0  # Assume reasonable compression

## Tracks model asset performance
func _track_model_asset(asset_name: String, asset_data: Dictionary) -> void:
	asset_data.polygon_count = _estimate_polygon_count(asset_name)
	asset_data.vertex_count = asset_data.polygon_count * 3
	asset_data.memory_usage_mb = (asset_data.vertex_count * 32) / (1024 * 1024)
	asset_data.optimization_score = _calculate_model_optimization_score(asset_data)

## Estimates polygon count for model
func _estimate_polygon_count(model_path: String) -> int:
	# This would require actual model file analysis
	# For now, provide estimates based on typical model complexity
	
	if model_path.is_empty():
		return 0
	
	# Estimate based on model name patterns
	var model_name: String = model_path.to_lower()
	
	if "fighter" in model_name or "interceptor" in model_name:
		return 2000  # Fighter ships
	elif "bomber" in model_name or "heavy" in model_name:
		return 3500  # Bomber ships
	elif "cruiser" in model_name or "destroyer" in model_name:
		return 6000  # Capital ships
	elif "weapon" in model_name or "missile" in model_name:
		return 200   # Weapons
	else:
		return 1500  # Default estimate

## Estimates texture memory usage
func _estimate_texture_memory(texture_paths: Array[String]) -> float:
	var total_memory: float = 0.0
	
	for texture_path in texture_paths:
		# Estimate based on typical texture sizes
		var texture_memory: float = 1.0  # Default 1MB
		
		var texture_name: String = texture_path.to_lower()
		
		# Larger textures for main surfaces
		if "diffuse" in texture_name or "color" in texture_name:
			texture_memory = 2.0
		elif "normal" in texture_name:
			texture_memory = 1.5
		elif "detail" in texture_name or "spec" in texture_name:
			texture_memory = 0.5
		
		total_memory += texture_memory
	
	return total_memory

## Calculates ship optimization score
func _calculate_ship_optimization_score(asset_data: Dictionary, ship_data: ShipData) -> float:
	var score: float = 100.0
	
	# Polygon count efficiency
	var polygon_count: int = asset_data.polygon_count
	if polygon_count > MAX_POLYGON_COUNT_PER_SHIP:
		var excess_ratio: float = float(polygon_count) / MAX_POLYGON_COUNT_PER_SHIP
		score -= min(30.0, (excess_ratio - 1.0) * 50.0)
	
	# Texture memory efficiency
	var texture_memory: float = asset_data.texture_memory_mb
	if texture_memory > MAX_TEXTURE_SIZE_MB:
		var excess_ratio: float = texture_memory / MAX_TEXTURE_SIZE_MB
		score -= min(25.0, (excess_ratio - 1.0) * 40.0)
	
	# LOD availability (would need actual asset inspection)
	# Assume no LOD for now
	score -= 15.0  # Penalty for no LOD
	
	# Model efficiency (vertex/polygon ratio)
	if asset_data.vertex_count > 0 and asset_data.polygon_count > 0:
		var vertex_efficiency: float = float(asset_data.polygon_count) / asset_data.vertex_count
		if vertex_efficiency < 0.3:  # Poor vertex reuse
			score -= 10.0
	
	return max(0.0, score)

## Calculates weapon optimization score
func _calculate_weapon_optimization_score(asset_data: Dictionary, weapon_data: WeaponData) -> float:
	var score: float = 100.0
	
	# Weapons should be low-poly
	var polygon_count: int = asset_data.polygon_count
	if polygon_count > 500:  # Weapons should be simple
		score -= (polygon_count - 500) * 0.1
	
	# Texture memory should be minimal
	var texture_memory: float = asset_data.texture_memory_mb
	if texture_memory > 0.5:
		score -= (texture_memory - 0.5) * 20.0
	
	return max(0.0, score)

## Calculates model optimization score
func _calculate_model_optimization_score(asset_data: Dictionary) -> float:
	var score: float = 100.0
	
	# General polygon efficiency
	var polygon_count: int = asset_data.polygon_count
	if polygon_count > 5000:
		score -= (polygon_count - 5000) * 0.01
	
	return max(0.0, score)

## Checks for asset performance issues
func _check_asset_performance_issues(asset_data: Dictionary) -> void:
	var asset_name: String = asset_data.name
	var issues: Array[String] = []
	
	# Check polygon count
	var polygon_count: int = asset_data.polygon_count
	if polygon_count > MAX_POLYGON_COUNT_PER_SHIP:
		var severity: String = "Medium" if polygon_count < MAX_POLYGON_COUNT_PER_SHIP * 1.5 else "High"
		issues.append("High polygon count: %d" % polygon_count)
		asset_performance_issue.emit(
			asset_name,
			"high_polygon_count",
			severity,
			"Polygon count %d exceeds recommended maximum of %d" % [polygon_count, MAX_POLYGON_COUNT_PER_SHIP]
		)
	
	# Check texture memory
	var texture_memory: float = asset_data.texture_memory_mb
	if texture_memory > MAX_TEXTURE_SIZE_MB:
		var severity: String = "Medium" if texture_memory < MAX_TEXTURE_SIZE_MB * 1.5 else "High"
		issues.append("Large texture memory: %.1f MB" % texture_memory)
		asset_performance_issue.emit(
			asset_name,
			"large_texture_memory",
			severity,
			"Texture memory %.1f MB exceeds recommended maximum of %.1f MB" % [texture_memory, MAX_TEXTURE_SIZE_MB]
		)
	
	# Check load time
	var load_time: float = asset_data.load_time_ms
	if load_time > MAX_ASSET_LOAD_TIME_MS:
		issues.append("Slow loading: %.1f ms" % load_time)
		asset_performance_issue.emit(
			asset_name,
			"slow_loading",
			"Medium",
			"Asset load time %.1f ms exceeds recommended maximum of %.1f ms" % [load_time, MAX_ASSET_LOAD_TIME_MS]
		)
	
	# Check optimization score
	var optimization_score: float = asset_data.optimization_score
	if optimization_score < 60.0:
		issues.append("Poor optimization: %.1f%%" % optimization_score)
		asset_performance_issue.emit(
			asset_name,
			"poor_optimization",
			"Medium",
			"Asset optimization score %.1f%% indicates room for improvement" % optimization_score
		)
	
	asset_data.issues = issues

## Updates overall performance metrics
func _update_performance_metrics(asset_data: Dictionary) -> void:
	var asset_type: String = asset_data.type
	
	match asset_type:
		"ship":
			var ship_metrics: Dictionary = performance_metrics.ships
			ship_metrics.total_polygons += asset_data.polygon_count
			ship_metrics.total_assets += 1
			ship_metrics.load_times.append(asset_data.load_time_ms)
			ship_metrics.max_polygons = max(ship_metrics.max_polygons, asset_data.polygon_count)
			
			if ship_metrics.total_assets > 0:
				ship_metrics.average_polygons = float(ship_metrics.total_polygons) / ship_metrics.total_assets
		
		"texture":
			var texture_metrics: Dictionary = performance_metrics.textures
			texture_metrics.total_memory_mb += asset_data.texture_memory_mb
			texture_metrics.texture_count += 1
			texture_metrics.largest_texture_mb = max(texture_metrics.largest_texture_mb, asset_data.texture_memory_mb)
			
			if texture_metrics.texture_count > 0:
				texture_metrics.average_size_mb = texture_metrics.total_memory_mb / texture_metrics.texture_count
	
	# Update overall memory usage
	memory_usage[asset_data.name] = asset_data.memory_usage_mb
	performance_metrics.memory.total_memory_mb += asset_data.memory_usage_mb

## Analyzes overall performance across all assets
func _analyze_overall_performance() -> void:
	print("Analyzing overall asset performance...")
	
	# Calculate memory totals
	var total_memory: float = 0.0
	for memory_usage_value in memory_usage.values():
		total_memory += memory_usage_value
	
	performance_metrics.memory.total_memory_mb = total_memory
	
	# Estimate GPU vs CPU memory split
	performance_metrics.memory.gpu_memory_mb = performance_metrics.textures.total_memory_mb * 0.8  # Most textures on GPU
	performance_metrics.memory.cpu_memory_mb = total_memory - performance_metrics.memory.gpu_memory_mb
	
	# Calculate streaming potential (assets that could be streamed)
	performance_metrics.memory.streaming_potential_mb = total_memory * 0.3  # Estimate 30% could be streamed
	
	# Check for overall memory issues
	if total_memory > MAX_TOTAL_TEXTURE_MEMORY_MB:
		asset_performance_issue.emit(
			"Total Mission Assets",
			"high_total_memory",
			"High",
			"Total asset memory %.1f MB exceeds recommended maximum of %.1f MB" % [total_memory, MAX_TOTAL_TEXTURE_MEMORY_MB]
		)

## Generates comprehensive tracking results
func _generate_tracking_results(tracking_time: float) -> Dictionary:
	var results: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"mission_name": mission_data.title if mission_data else "Unknown",
		"tracking_duration": tracking_time,
		"summary": {},
		"assets": tracked_assets,
		"metrics": performance_metrics,
		"memory_usage": memory_usage,
		"recommendations": []
	}
	
	# Generate summary
	results.summary = _generate_asset_summary()
	
	# Generate optimization recommendations
	results.recommendations = _generate_asset_recommendations()
	
	return results

## Generates asset performance summary
func _generate_asset_summary() -> Dictionary:
	var summary: Dictionary = {
		"total_assets": tracked_assets.size(),
		"total_memory_mb": performance_metrics.memory.total_memory_mb,
		"high_poly_assets": 0,
		"large_texture_assets": 0,
		"slow_loading_assets": 0,
		"optimization_score": 0.0
	}
	
	var total_optimization_score: float = 0.0
	var assets_with_scores: int = 0
	
	for asset_data in tracked_assets.values():
		# Count problematic assets
		if asset_data.polygon_count > MAX_POLYGON_COUNT_PER_SHIP:
			summary.high_poly_assets += 1
		
		if asset_data.texture_memory_mb > MAX_TEXTURE_SIZE_MB:
			summary.large_texture_assets += 1
		
		if asset_data.load_time_ms > MAX_ASSET_LOAD_TIME_MS:
			summary.slow_loading_assets += 1
		
		# Accumulate optimization scores
		if asset_data.optimization_score > 0.0:
			total_optimization_score += asset_data.optimization_score
			assets_with_scores += 1
	
	# Calculate average optimization score
	if assets_with_scores > 0:
		summary.optimization_score = total_optimization_score / assets_with_scores
	
	return summary

## Generates asset optimization recommendations
func _generate_asset_recommendations() -> Array[String]:
	var recommendations: Array[String] = []
	
	# Memory optimization recommendations
	if performance_metrics.memory.total_memory_mb > MAX_TOTAL_TEXTURE_MEMORY_MB:
		recommendations.append("Reduce overall texture memory usage - currently %.1f MB, target < %.1f MB" % [performance_metrics.memory.total_memory_mb, MAX_TOTAL_TEXTURE_MEMORY_MB])
		recommendations.append("Consider texture compression and mipmap optimization")
		recommendations.append("Implement asset streaming for large textures")
	
	# Polygon optimization recommendations
	if performance_metrics.ships.max_polygons > MAX_POLYGON_COUNT_PER_SHIP:
		recommendations.append("Optimize high-polygon ship models - maximum found: %d polygons" % performance_metrics.ships.max_polygons)
		recommendations.append("Create level-of-detail (LOD) models for complex ships")
	
	# Load time optimization
	var slow_assets: Array[String] = []
	for asset_name in tracked_assets.keys():
		var asset_data: Dictionary = tracked_assets[asset_name]
		if asset_data.load_time_ms > MAX_ASSET_LOAD_TIME_MS:
			slow_assets.append(asset_name)
	
	if slow_assets.size() > 0:
		recommendations.append("Optimize asset loading for %d slow-loading assets" % slow_assets.size())
		recommendations.append("Consider asset preloading or background streaming")
	
	# Specific asset recommendations
	for asset_name in tracked_assets.keys():
		var asset_data: Dictionary = tracked_assets[asset_name]
		if asset_data.optimization_score < 50.0:
			recommendations.append("Optimize %s (%s) - score: %.1f%%" % [asset_name, asset_data.type, asset_data.optimization_score])
	
	# General recommendations
	if recommendations.is_empty():
		recommendations.append("Asset performance is good - no major optimizations needed")
	else:
		recommendations.append("Consider implementing asset caching and streaming systems")
		recommendations.append("Monitor asset memory usage during gameplay")
	
	return recommendations

## Exports asset performance report
func export_asset_report(results: Dictionary, file_path: String) -> Error:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Cannot create asset performance report file: " + file_path)
		return ERR_FILE_CANT_WRITE
	
	var report: String = _generate_asset_report_text(results)
	file.store_string(report)
	file.close()
	
	print("Asset performance report exported to: " + file_path)
	return OK

## Generates formatted asset performance report
func _generate_asset_report_text(results: Dictionary) -> String:
	var report: String = ""
	
	report += "=".repeat(80) + "\n"
	report += "ASSET PERFORMANCE REPORT\n"
	report += "=".repeat(80) + "\n"
	report += "Mission: %s\n" % results.get("mission_name", "Unknown")
	report += "Tracking Time: %.2f ms\n" % results.get("tracking_duration", 0.0)
	report += "Timestamp: %s\n\n" % results.get("timestamp", "Unknown")
	
	# Summary section
	var summary: Dictionary = results.get("summary", {})
	report += "-".repeat(40) + "\n"
	report += "SUMMARY\n"
	report += "-".repeat(40) + "\n"
	report += "Total Assets: %d\n" % summary.get("total_assets", 0)
	report += "Total Memory: %.1f MB\n" % summary.get("total_memory_mb", 0.0)
	report += "High-Polygon Assets: %d\n" % summary.get("high_poly_assets", 0)
	report += "Large Texture Assets: %d\n" % summary.get("large_texture_assets", 0)
	report += "Slow-Loading Assets: %d\n" % summary.get("slow_loading_assets", 0)
	report += "Overall Optimization Score: %.1f%%\n\n" % summary.get("optimization_score", 0.0)
	
	# Performance metrics
	var metrics: Dictionary = results.get("metrics", {})
	report += "-".repeat(40) + "\n"
	report += "PERFORMANCE METRICS\n"
	report += "-".repeat(40) + "\n"
	
	if metrics.has("ships"):
		var ship_metrics: Dictionary = metrics.ships
		report += "Ships:\n"
		report += "  Total Polygons: %d\n" % ship_metrics.get("total_polygons", 0)
		report += "  Average Polygons: %.0f\n" % ship_metrics.get("average_polygons", 0.0)
		report += "  Maximum Polygons: %d\n" % ship_metrics.get("max_polygons", 0)
		report += "  Ship Count: %d\n\n" % ship_metrics.get("total_assets", 0)
	
	if metrics.has("textures"):
		var texture_metrics: Dictionary = metrics.textures
		report += "Textures:\n"
		report += "  Total Memory: %.1f MB\n" % texture_metrics.get("total_memory_mb", 0.0)
		report += "  Average Size: %.1f MB\n" % texture_metrics.get("average_size_mb", 0.0)
		report += "  Largest Texture: %.1f MB\n" % texture_metrics.get("largest_texture_mb", 0.0)
		report += "  Texture Count: %d\n\n" % texture_metrics.get("texture_count", 0)
	
	# Recommendations
	var recommendations: Array = results.get("recommendations", [])
	if recommendations.size() > 0:
		report += "-".repeat(40) + "\n"
		report += "OPTIMIZATION RECOMMENDATIONS\n"
		report += "-".repeat(40) + "\n"
		
		for i in range(recommendations.size()):
			report += "%d. %s\n" % [i + 1, recommendations[i]]
		
		report += "\n"
	
	report += "=".repeat(80) + "\n"
	report += "End of Asset Performance Report\n"
	report += "=".repeat(80) + "\n"
	
	return report

## Gets current tracking state
func get_tracking_state() -> Dictionary:
	return {
		"is_tracking": is_tracking,
		"tracked_assets": tracked_assets.size(),
		"total_memory_mb": performance_metrics.memory.total_memory_mb
	}

## Clears all tracking data
func clear_tracking_data() -> void:
	tracked_assets.clear()
	memory_usage.clear()
	_initialize_tracking()
	print("Asset tracking data cleared")