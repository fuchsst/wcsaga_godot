@tool
class_name AssetPerformanceProfiler
extends RefCounted

## Asset performance profiler for GFRED2 Performance Profiling Tools.
## Analyzes asset resource usage and identifies performance-intensive assets.

signal expensive_asset_detected(asset_path: String, memory_usage: float)
signal memory_threshold_exceeded(category: String, usage: float, threshold: float)
signal optimization_recommendation(asset_path: String, recommendation: String)

# Profiling configuration
var profiling_enabled: bool = false
var memory_threshold_mb: float = 50.0  # 50MB threshold for expensive assets
var texture_memory_budget_mb: float = 256.0
var mesh_memory_budget_mb: float = 128.0

# Asset tracking
var tracked_assets: Dictionary = {}  # String path -> AssetProfileData
var texture_memory_usage: float = 0.0
var mesh_memory_usage: float = 0.0
var shader_count: int = 0
var expensive_assets: Array[ExpensiveAssetData] = []

# Mission data being profiled
var mission_data: MissionData = null

func start_profiling(target_mission: MissionData) -> void:
	"""Starts asset performance profiling for the given mission."""
	profiling_enabled = true
	mission_data = target_mission
	
	# Reset profiling data
	tracked_assets.clear()
	expensive_assets.clear()
	texture_memory_usage = 0.0
	mesh_memory_usage = 0.0
	shader_count = 0
	
	# Analyze mission assets
	_analyze_mission_assets()
	
	print("AssetPerformanceProfiler: Started profiling mission assets")

func stop_profiling() -> void:
	"""Stops asset performance profiling and generates final analysis."""
	profiling_enabled = false
	
	# Generate optimization recommendations
	_generate_optimization_recommendations()
	
	print("AssetPerformanceProfiler: Asset profiling complete")

func _analyze_mission_assets() -> void:
	"""Analyzes all assets used in the mission."""
	if not mission_data:
		return
	
	# Analyze ship assets
	for obj in mission_data.objects:
		if not obj.ship_class.is_empty():
			_analyze_ship_assets(obj.ship_class)
	
	# Analyze background assets
	if mission_data.background:
		_analyze_background_assets(mission_data.background)
	
	# Analyze briefing assets
	if mission_data.briefing:
		_analyze_briefing_assets(mission_data.briefing)
	
	# Calculate total memory usage
	_calculate_memory_usage()

func _analyze_ship_assets(ship_class: String) -> void:
	"""Analyzes assets for a specific ship class."""
	# This would integrate with the asset registry to get ship data
	var ship_data: Dictionary = _get_ship_class_data(ship_class)
	if ship_data.is_empty():
		return
	
	# Analyze ship model
	if ship_data.has("model_path"):
		_analyze_model_asset(ship_data.model_path)
	
	# Analyze ship textures
	if ship_data.has("textures"):
		for texture_path in ship_data.textures:
			_analyze_texture_asset(texture_path)
	
	# Analyze weapon models and textures
	if ship_data.has("weapons"):
		for weapon in ship_data.weapons:
			_analyze_weapon_assets(weapon)

func _analyze_background_assets(background_data) -> void:
	"""Analyzes background-related assets."""
	# Analyze skybox textures
	# Analyze nebula effects
	# Analyze environment maps
	# This would be implemented with actual background system integration
	pass

func _analyze_briefing_assets(briefing_data) -> void:
	"""Analyzes briefing-related assets."""
	# Analyze briefing images
	# Analyze briefing animations
	# Analyze briefing audio
	# This would be implemented with actual briefing system integration
	pass

func _analyze_model_asset(model_path: String) -> void:
	"""Analyzes a 3D model asset for performance characteristics."""
	if tracked_assets.has(model_path):
		tracked_assets[model_path].reference_count += 1
		return
	
	var asset_data: AssetProfileData = AssetProfileData.new()
	asset_data.asset_path = model_path
	asset_data.asset_type = AssetProfileData.AssetType.MODEL
	asset_data.reference_count = 1
	
	# Get model statistics (this would integrate with actual asset loading)
	var model_stats: Dictionary = _get_model_statistics(model_path)
	asset_data.memory_usage_mb = model_stats.get("memory_mb", 0.0)
	asset_data.polygon_count = model_stats.get("polygon_count", 0)
	asset_data.vertex_count = model_stats.get("vertex_count", 0)
	asset_data.texture_count = model_stats.get("texture_count", 0)
	
	tracked_assets[model_path] = asset_data
	mesh_memory_usage += asset_data.memory_usage_mb
	
	# Check if this is an expensive asset
	if asset_data.memory_usage_mb > memory_threshold_mb:
		_record_expensive_asset(asset_data)

func _analyze_texture_asset(texture_path: String) -> void:
	"""Analyzes a texture asset for performance characteristics."""
	if tracked_assets.has(texture_path):
		tracked_assets[texture_path].reference_count += 1
		return
	
	var asset_data: AssetProfileData = AssetProfileData.new()
	asset_data.asset_path = texture_path
	asset_data.asset_type = AssetProfileData.AssetType.TEXTURE
	asset_data.reference_count = 1
	
	# Get texture statistics (this would integrate with actual asset loading)
	var texture_stats: Dictionary = _get_texture_statistics(texture_path)
	asset_data.memory_usage_mb = texture_stats.get("memory_mb", 0.0)
	asset_data.texture_width = texture_stats.get("width", 0)
	asset_data.texture_height = texture_stats.get("height", 0)
	asset_data.texture_format = texture_stats.get("format", "Unknown")
	asset_data.has_mipmaps = texture_stats.get("mipmaps", false)
	
	tracked_assets[texture_path] = asset_data
	texture_memory_usage += asset_data.memory_usage_mb
	
	# Check if this is an expensive asset
	if asset_data.memory_usage_mb > memory_threshold_mb:
		_record_expensive_asset(asset_data)

func _analyze_weapon_assets(weapon_data: Dictionary) -> void:
	"""Analyzes assets for a weapon system."""
	# Analyze weapon model
	if weapon_data.has("model_path"):
		_analyze_model_asset(weapon_data.model_path)
	
	# Analyze weapon textures
	if weapon_data.has("textures"):
		for texture_path in weapon_data.textures:
			_analyze_texture_asset(texture_path)
	
	# Analyze weapon effects
	if weapon_data.has("effects"):
		for effect in weapon_data.effects:
			_analyze_effect_assets(effect)

func _analyze_effect_assets(effect_data: Dictionary) -> void:
	"""Analyzes assets for visual effects."""
	# Analyze particle textures
	# Analyze effect shaders
	# Analyze effect models
	# This would be implemented with actual effect system integration
	pass

func _get_ship_class_data(ship_class: String) -> Dictionary:
	"""Gets ship class data from asset registry."""
	# This would integrate with the actual asset registry
	# For now, return mock data
	return {
		"model_path": "ships/%s.glb" % ship_class,
		"textures": ["ships/%s_diffuse.png" % ship_class, "ships/%s_normal.png" % ship_class],
		"weapons": []
	}

func _get_model_statistics(model_path: String) -> Dictionary:
	"""Gets statistics for a 3D model asset."""
	# This would integrate with actual asset loading to get real statistics
	# For now, return estimated values based on file size
	var file_size: int = _get_file_size(model_path)
	return {
		"memory_mb": file_size / (1024.0 * 1024.0) * 2.0,  # Estimate memory as 2x file size
		"polygon_count": file_size * 10,  # Rough estimate
		"vertex_count": file_size * 15,   # Rough estimate
		"texture_count": 2
	}

func _get_texture_statistics(texture_path: String) -> Dictionary:
	"""Gets statistics for a texture asset."""
	# This would integrate with actual texture loading to get real statistics
	# For now, return estimated values
	var file_size: int = _get_file_size(texture_path)
	var estimated_width: int = 1024  # Default assumption
	var estimated_height: int = 1024
	
	# Estimate memory usage (RGBA8 format)
	var memory_mb: float = (estimated_width * estimated_height * 4) / (1024.0 * 1024.0)
	
	return {
		"memory_mb": memory_mb,
		"width": estimated_width,
		"height": estimated_height,
		"format": "RGBA8",
		"mipmaps": true
	}

func _get_file_size(file_path: String) -> int:
	"""Gets the file size of an asset."""
	if FileAccess.file_exists(file_path):
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var size: int = file.get_length()
			file.close()
			return size
	
	# Return estimated size if file doesn't exist
	return 1024 * 1024  # 1MB default

func _record_expensive_asset(asset_data: AssetProfileData) -> void:
	"""Records an expensive asset for optimization recommendations."""
	var expensive_data: ExpensiveAssetData = ExpensiveAssetData.new()
	expensive_data.asset_data = asset_data
	expensive_data.impact_score = _calculate_asset_impact(asset_data)
	expensive_data.optimization_potential = _estimate_optimization_potential(asset_data)
	
	expensive_assets.append(expensive_data)
	expensive_asset_detected.emit(asset_data.asset_path, asset_data.memory_usage_mb)

func _calculate_asset_impact(asset_data: AssetProfileData) -> float:
	"""Calculates the performance impact score of an asset."""
	var impact: float = 0.0
	
	# Memory usage impact (40% weight)
	impact += (asset_data.memory_usage_mb / memory_threshold_mb) * 0.4
	
	# Reference count impact (30% weight)
	impact += (asset_data.reference_count / 10.0) * 0.3
	
	# Complexity impact (30% weight)
	if asset_data.asset_type == AssetProfileData.AssetType.MODEL:
		impact += (asset_data.polygon_count / 50000.0) * 0.3
	elif asset_data.asset_type == AssetProfileData.AssetType.TEXTURE:
		var resolution_factor: float = (asset_data.texture_width * asset_data.texture_height) / (1024.0 * 1024.0)
		impact += resolution_factor * 0.3
	
	return min(impact, 1.0)

func _estimate_optimization_potential(asset_data: AssetProfileData) -> float:
	"""Estimates the optimization potential for an asset (0.0 - 1.0)."""
	var potential: float = 0.0
	
	if asset_data.asset_type == AssetProfileData.AssetType.TEXTURE:
		# High resolution textures have high optimization potential
		if asset_data.texture_width > 2048 or asset_data.texture_height > 2048:
			potential += 0.4
		
		# Uncompressed textures have optimization potential
		if asset_data.texture_format in ["RGBA8", "RGB8"]:
			potential += 0.3
		
		# Textures without mipmaps have optimization potential
		if not asset_data.has_mipmaps:
			potential += 0.2
	
	elif asset_data.asset_type == AssetProfileData.AssetType.MODEL:
		# High polygon models have optimization potential
		if asset_data.polygon_count > 20000:
			potential += 0.4
		
		# Models with many textures can be optimized
		if asset_data.texture_count > 4:
			potential += 0.3
	
	# Assets used frequently have higher optimization value
	if asset_data.reference_count > 5:
		potential += 0.1
	
	return min(potential, 1.0)

func _calculate_memory_usage() -> void:
	"""Calculates total memory usage and checks thresholds."""
	# Check texture memory budget
	if texture_memory_usage > texture_memory_budget_mb:
		memory_threshold_exceeded.emit("Texture Memory", texture_memory_usage, texture_memory_budget_mb)
	
	# Check mesh memory budget
	if mesh_memory_usage > mesh_memory_budget_mb:
		memory_threshold_exceeded.emit("Mesh Memory", mesh_memory_usage, mesh_memory_budget_mb)

func _generate_optimization_recommendations() -> void:
	"""Generates optimization recommendations for expensive assets."""
	for expensive_asset in expensive_assets:
		var asset_data: AssetProfileData = expensive_asset.asset_data
		var recommendations: Array[String] = []
		
		if asset_data.asset_type == AssetProfileData.AssetType.TEXTURE:
			recommendations.append_array(_generate_texture_recommendations(asset_data))
		elif asset_data.asset_type == AssetProfileData.AssetType.MODEL:
			recommendations.append_array(_generate_model_recommendations(asset_data))
		
		for recommendation in recommendations:
			optimization_recommendation.emit(asset_data.asset_path, recommendation)

func _generate_texture_recommendations(asset_data: AssetProfileData) -> Array[String]:
	"""Generates optimization recommendations for texture assets."""
	var recommendations: Array[String] = []
	
	if asset_data.texture_width > 2048 or asset_data.texture_height > 2048:
		recommendations.append("Consider reducing texture resolution to 2048x2048 or lower")
	
	if asset_data.texture_format in ["RGBA8", "RGB8"]:
		recommendations.append("Consider using compressed texture formats (DXT/ETC/ASTC)")
	
	if not asset_data.has_mipmaps:
		recommendations.append("Enable mipmaps for better performance at distance")
	
	if asset_data.reference_count > 1:
		recommendations.append("Consider texture atlasing to reduce draw calls")
	
	return recommendations

func _generate_model_recommendations(asset_data: AssetProfileData) -> Array[String]:
	"""Generates optimization recommendations for model assets."""
	var recommendations: Array[String] = []
	
	if asset_data.polygon_count > 20000:
		recommendations.append("Consider reducing polygon count with LOD models")
	
	if asset_data.texture_count > 4:
		recommendations.append("Consider texture atlasing to reduce material count")
	
	if asset_data.reference_count > 3:
		recommendations.append("Consider using MultiMeshInstance3D for instanced rendering")
	
	return recommendations

## Public API Methods

func get_texture_memory_usage() -> float:
	"""Gets total texture memory usage in MB."""
	return texture_memory_usage

func get_mesh_memory_usage() -> float:
	"""Gets total mesh memory usage in MB."""
	return mesh_memory_usage

func get_total_memory_usage() -> float:
	"""Gets total asset memory usage in MB."""
	return texture_memory_usage + mesh_memory_usage

func get_expensive_assets() -> Array[ExpensiveAssetData]:
	"""Gets all expensive assets detected."""
	return expensive_assets.duplicate()

func get_asset_statistics(asset_path: String) -> Dictionary:
	"""Gets statistics for a specific asset."""
	var asset_data: AssetProfileData = tracked_assets.get(asset_path)
	if not asset_data:
		return {}
	
	return {
		"path": asset_data.asset_path,
		"type": AssetProfileData.AssetType.keys()[asset_data.asset_type],
		"memory_usage_mb": asset_data.memory_usage_mb,
		"reference_count": asset_data.reference_count,
		"polygon_count": asset_data.polygon_count,
		"vertex_count": asset_data.vertex_count,
		"texture_width": asset_data.texture_width,
		"texture_height": asset_data.texture_height,
		"texture_format": asset_data.texture_format,
		"has_mipmaps": asset_data.has_mipmaps
	}

func get_memory_breakdown() -> Dictionary:
	"""Gets a breakdown of memory usage by asset type."""
	return {
		"texture_memory_mb": texture_memory_usage,
		"mesh_memory_mb": mesh_memory_usage,
		"total_memory_mb": get_total_memory_usage(),
		"texture_budget_mb": texture_memory_budget_mb,
		"mesh_budget_mb": mesh_memory_budget_mb,
		"texture_budget_used_percent": (texture_memory_usage / texture_memory_budget_mb) * 100.0,
		"mesh_budget_used_percent": (mesh_memory_usage / mesh_memory_budget_mb) * 100.0
	}

func get_asset_count_by_type() -> Dictionary:
	"""Gets count of assets by type."""
	var counts: Dictionary = {}
	for asset_path in tracked_assets.keys():
		var asset_data: AssetProfileData = tracked_assets[asset_path]
		var type_name: String = AssetProfileData.AssetType.keys()[asset_data.asset_type]
		counts[type_name] = counts.get(type_name, 0) + 1
	return counts

## Data Classes

class AssetProfileData:
	extends RefCounted
	
	enum AssetType {
		TEXTURE,
		MODEL,
		AUDIO,
		SHADER,
		ANIMATION
	}
	
	var asset_path: String = ""
	var asset_type: AssetType = AssetType.TEXTURE
	var memory_usage_mb: float = 0.0
	var reference_count: int = 0
	
	# Model-specific data
	var polygon_count: int = 0
	var vertex_count: int = 0
	var texture_count: int = 0
	
	# Texture-specific data
	var texture_width: int = 0
	var texture_height: int = 0
	var texture_format: String = ""
	var has_mipmaps: bool = false

class ExpensiveAssetData:
	extends RefCounted
	
	var asset_data: AssetProfileData
	var impact_score: float = 0.0
	var optimization_potential: float = 0.0