class_name WCSMaterialSystem
extends Node

## Material management system integrating with EPIC-002 MaterialData assets
## Provides efficient material loading, caching, and WCS-specific enhancements

signal material_loaded(material_name: String, material: StandardMaterial3D)
signal material_created(material_data: MaterialData)
signal material_cache_updated(cache_size: int, memory_usage: int)
signal material_properties_changed(material_name: String)
signal material_validation_failed(material_name: String, errors: Array[String])

var material_cache: MaterialCache
var material_enhancement_rules: Dictionary = {}
var cache_size_limit: int = 100  # Maximum cached materials
var memory_usage_limit: int = 256 * 1024 * 1024  # 256 MB

# Default material for fallback
var default_material: StandardMaterial3D

func _ready() -> void:
	material_cache = MaterialCache.new(cache_size_limit, memory_usage_limit)
	material_cache.cache_updated.connect(_on_cache_updated)
	material_cache.material_evicted.connect(_on_material_evicted)
	material_cache.cache_full.connect(_on_cache_full)
	
	load_material_enhancement_rules()
	_create_default_material()
	print("WCSMaterialSystem: Initialized with EPIC-002 MaterialData integration")

func _create_default_material() -> void:
	default_material = StandardMaterial3D.new()
	default_material.resource_name = "WCS_Default_Material"
	default_material.albedo_color = Color.GRAY
	default_material.roughness = 0.5
	default_material.metallic = 0.0

func load_material_enhancement_rules() -> void:
	# Load enhancement rules for different material types
	material_enhancement_rules = {
		MaterialData.MaterialType.HULL: {
			"metallic_boost": 0.1,
			"roughness_adjustment": 0.0,
			"supports_damage": true,
			"rim_enhancement": true
		},
		MaterialData.MaterialType.COCKPIT: {
			"metallic_boost": 0.0,
			"roughness_adjustment": -0.1,
			"transparency_enabled": true,
			"fresnel_enabled": true,
			"clearcoat_enhancement": true
		},
		MaterialData.MaterialType.ENGINE: {
			"metallic_boost": 0.2,
			"roughness_adjustment": -0.2,
			"emission_boost": 0.5,
			"supports_animation": true,
			"heat_distortion": true
		},
		MaterialData.MaterialType.WEAPON: {
			"metallic_boost": 0.15,
			"roughness_adjustment": -0.1,
			"supports_damage": true,
			"metallic_enhancement": true
		},
		MaterialData.MaterialType.SHIELD: {
			"metallic_boost": 0.0,
			"roughness_adjustment": -0.3,
			"transparency_enabled": true,
			"emission_boost": 1.0,
			"supports_animation": true,
			"energy_effects": true
		},
		MaterialData.MaterialType.SPACE: {
			"metallic_boost": 0.0,
			"roughness_adjustment": 0.1,
			"unshaded": true,
			"background_optimization": true
		},
		MaterialData.MaterialType.EFFECT: {
			"metallic_boost": 0.0,
			"roughness_adjustment": -0.5,
			"transparency_enabled": true,
			"emission_boost": 2.0,
			"supports_animation": true,
			"unshaded": true,
			"additive_blending": true
		},
		MaterialData.MaterialType.GENERIC: {
			"metallic_boost": 0.0,
			"roughness_adjustment": 0.0,
			"balanced_settings": true
		}
	}

func load_material_from_asset(material_path: String) -> StandardMaterial3D:
	# Check cache first
	var cached_material: StandardMaterial3D = material_cache.get_material(material_path)
	if cached_material:
		return cached_material
	
	# Load MaterialData through EPIC-002 asset system
	var material_data: MaterialData = WCSAssetLoader.load_asset(material_path)
	if not material_data:
		push_error("Failed to load MaterialData: " + material_path)
		return _get_fallback_material()
	
	# Validate MaterialData
	if not material_data.is_valid():
		var errors: Array[String] = material_data.get_validation_errors()
		material_validation_failed.emit(material_data.material_name, errors)
		push_warning("MaterialData validation failed for: " + material_path)
		return _get_fallback_material()
	
	# Create Godot material using MaterialData.create_standard_material()
	var godot_material: StandardMaterial3D = material_data.create_standard_material()
	if not godot_material:
		push_error("Failed to create StandardMaterial3D from MaterialData: " + material_path)
		return _get_fallback_material()
	
	# Apply WCS-specific enhancements based on material type
	_apply_wcs_material_enhancements(godot_material, material_data)
	
	# Cache the material
	material_cache.store_material(material_path, godot_material)
	
	material_created.emit(material_data)
	material_loaded.emit(material_data.material_name, godot_material)
	
	return godot_material

func create_material_for_ship_component(ship_class: String, component_type: String) -> StandardMaterial3D:
	# Construct material path based on ship class and component
	var material_path: String = "ships/%s/materials/%s_material.tres" % [ship_class, component_type]
	return load_material_from_asset(material_path)

func _apply_wcs_material_enhancements(material: StandardMaterial3D, material_data: MaterialData) -> void:
	# Apply WCS-specific rendering properties based on material type
	var material_type: MaterialData.MaterialType = material_data.material_type
	var enhancement_rules: Dictionary = material_enhancement_rules.get(material_type, {})
	
	# Apply enhancement rules
	if "metallic_boost" in enhancement_rules:
		material.metallic = clamp(material.metallic + enhancement_rules.metallic_boost, 0.0, 1.0)
	
	if "roughness_adjustment" in enhancement_rules:
		material.roughness = clamp(material.roughness + enhancement_rules.roughness_adjustment, 0.0, 1.0)
	
	if "emission_boost" in enhancement_rules and material.emission_enabled:
		material.emission_energy *= enhancement_rules.emission_boost
	
	# Apply space-appropriate material settings for metallic surfaces
	if material_type in [MaterialData.MaterialType.HULL, MaterialData.MaterialType.WEAPON, MaterialData.MaterialType.ENGINE]:
		if not material.rim_enabled and enhancement_rules.get("rim_enhancement", false):
			material.rim_enabled = true
			material.rim_tint = 0.3
			material.rim = 0.8
		
		# Enhance metallic surfaces for space environment
		if material_data.metallic > 0.5 and enhancement_rules.get("clearcoat_enhancement", false):
			material.clearcoat_enabled = true
			material.clearcoat = 0.2
	
	# Apply material type-specific rules
	match material_type:
		MaterialData.MaterialType.HULL:
			_apply_hull_material_enhancements(material, material_data)
		MaterialData.MaterialType.COCKPIT:
			_apply_cockpit_material_enhancements(material, material_data)
		MaterialData.MaterialType.ENGINE:
			_apply_engine_material_enhancements(material, material_data)
		MaterialData.MaterialType.SHIELD:
			_apply_shield_material_enhancements(material, material_data)
		MaterialData.MaterialType.EFFECT:
			_apply_effect_material_enhancements(material, material_data)

func _apply_hull_material_enhancements(material: StandardMaterial3D, material_data: MaterialData) -> void:
	# Hull materials need enhanced metal reflection and space-appropriate settings
	if material_data.metallic > 0.3:
		# Enhance metallic appearance for space environment
		material.metallic = clamp(material_data.metallic * 1.2, 0.0, 1.0)
		material.roughness = clamp(material_data.roughness * 0.8, 0.1, 1.0)
	
	# Hull materials benefit from subtle rim lighting
	if not material.rim_enabled:
		material.rim_enabled = true
		material.rim = 0.4
		material.rim_tint = 0.2

func _apply_cockpit_material_enhancements(material: StandardMaterial3D, material_data: MaterialData) -> void:
	# Cockpit materials should have glass-like properties
	if not material_data.is_transparent():
		# Make slightly transparent for glass effect
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.85
	
	# Enable fresnel for realistic glass appearance
	if not material.rim_enabled:
		material.rim_enabled = true
		material.rim = 0.6
		material.rim_tint = 0.8
	
	# Add subtle clearcoat for glass polish
	if not material.clearcoat_enabled:
		material.clearcoat_enabled = true
		material.clearcoat = 0.3
		material.clearcoat_roughness = 0.1

func _apply_engine_material_enhancements(material: StandardMaterial3D, material_data: MaterialData) -> void:
	# Engine materials should emit light and heat
	if material_data.has_emission():
		material.emission_energy = max(material_data.emission_energy * 2.0, 1.0)
		if material_data.emission_color != Color.BLACK:
			material.emission = material_data.emission_color
		else:
			material.emission = Color(0.0, 0.7, 1.0)  # Default engine glow
	
	# Engine materials are typically more metallic
	material.metallic = clamp(material_data.metallic + 0.2, 0.0, 1.0)
	material.roughness = clamp(material_data.roughness - 0.1, 0.0, 1.0)

func _apply_shield_material_enhancements(material: StandardMaterial3D, material_data: MaterialData) -> void:
	# Shield materials are energy-based and translucent
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.3
	
	# Shields emit energy
	material.emission_enabled = true
	if material_data.emission_color != Color.BLACK:
		material.emission = material_data.emission_color
	else:
		material.emission = Color(0.0, 0.5, 1.0)  # Default shield energy
	material.emission_energy = max(material_data.emission_energy, 1.5)
	
	# Shields are unshaded for energy effect
	material.flags_unshaded = true
	
	# Strong rim lighting for energy field effect
	material.rim_enabled = true
	material.rim = 1.0
	material.rim_tint = 1.0

func _apply_effect_material_enhancements(material: StandardMaterial3D, material_data: MaterialData) -> void:
	# Effect materials are typically additive and bright
	if material_data.blend_mode == "ADD":
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	
	# Effects are usually unshaded
	material.flags_unshaded = true
	
	# High emission for visibility
	material.emission_enabled = true
	material.emission_energy = max(material_data.emission_energy * 2.0, 2.0)
	
	# Effects benefit from transparency
	if not material_data.is_transparent():
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func get_material(material_name: String) -> StandardMaterial3D:
	# Try loading from cache first by name
	var cached_materials: Array[String] = material_cache.get_material_list()
	for cached_path in cached_materials:
		var cached_material: StandardMaterial3D = material_cache.get_material(cached_path)
		if cached_material and cached_material.resource_name == material_name:
			return cached_material
	
	# Try discovering material by name through asset registry
	var material_paths: Array[String] = WCSAssetRegistry.search_assets(material_name, AssetTypes.Type.MATERIAL)
	if not material_paths.is_empty():
		return load_material_from_asset(material_paths[0])
	
	push_warning("Material not found: " + material_name)
	return _get_fallback_material()

func preload_ship_materials(ship_class: String) -> void:
	# Preload all materials for a specific ship class
	var material_filters: Dictionary = {
		"path_contains": "ships/" + ship_class + "/materials/",
		"type": "MaterialData"
	}
	var ship_material_paths: Array[String] = WCSAssetRegistry.filter_assets(material_filters)
	
	for material_path in ship_material_paths:
		load_material_from_asset(material_path)
	
	print("WCSMaterialSystem: Preloaded %d materials for ship class: %s" % [ship_material_paths.size(), ship_class])

func load_materials_by_type(material_type: MaterialData.MaterialType) -> Array[StandardMaterial3D]:
	# Load all materials of a specific type
	var materials: Array[StandardMaterial3D] = []
	var material_paths: Array[String] = WCSAssetRegistry.discover_assets_by_type("MaterialData")
	
	for material_path in material_paths:
		var material_data: MaterialData = WCSAssetLoader.load_asset(material_path)
		if material_data and material_data.material_type == material_type:
			var godot_material: StandardMaterial3D = load_material_from_asset(material_path)
			materials.append(godot_material)
	
	return materials

func create_fallback_material(material_type: MaterialData.MaterialType) -> StandardMaterial3D:
	# Create appropriate fallback material based on type
	var fallback: StandardMaterial3D = StandardMaterial3D.new()
	fallback.resource_name = "fallback_" + MaterialData.MaterialType.keys()[material_type].to_lower()
	
	match material_type:
		MaterialData.MaterialType.HULL:
			fallback.albedo_color = Color.GRAY
			fallback.metallic = 0.7
			fallback.roughness = 0.3
		MaterialData.MaterialType.COCKPIT:
			fallback.albedo_color = Color(0.8, 0.9, 1.0, 0.7)
			fallback.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fallback.rim_enabled = true
		MaterialData.MaterialType.ENGINE:
			fallback.albedo_color = Color.BLUE
			fallback.emission_enabled = true
			fallback.emission = Color.CYAN
			fallback.emission_energy = 2.0
		MaterialData.MaterialType.SHIELD:
			fallback.albedo_color = Color(0.0, 0.5, 1.0, 0.3)
			fallback.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fallback.emission_enabled = true
			fallback.emission = Color.CYAN
			fallback.flags_unshaded = true
		MaterialData.MaterialType.EFFECT:
			fallback.albedo_color = Color.WHITE
			fallback.emission_enabled = true
			fallback.emission = Color.WHITE
			fallback.emission_energy = 3.0
			fallback.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			fallback.flags_unshaded = true
		_:
			fallback.albedo_color = Color.MAGENTA  # Obvious error material
	
	return fallback

func _get_fallback_material() -> StandardMaterial3D:
	# Return default fallback material
	return default_material


func _on_cache_updated(cache_size: int, memory_usage: int) -> void:
	material_cache_updated.emit(cache_size, memory_usage)

func _on_material_evicted(material_name: String) -> void:
	print("WCSMaterialSystem: Evicted material from cache: ", material_name)

func _on_cache_full() -> void:
	push_warning("WCSMaterialSystem: Material cache is full, cannot store more materials")

func get_cache_stats() -> Dictionary:
	return material_cache.get_cache_stats()

func clear_cache() -> void:
	material_cache.clear()

func preload_materials(material_paths: Array[String]) -> void:
	# Preload frequently used materials
	for material_path in material_paths:
		if not material_cache.has_material(material_path):
			load_material_from_asset(material_path)

func invalidate_material_cache(material_path: String = "") -> void:
	# Invalidate specific material or entire cache
	if material_path.is_empty():
		clear_cache()
	else:
		material_cache.remove_material(material_path)

func get_material_by_type_and_name(material_type: MaterialData.MaterialType, material_name: String) -> StandardMaterial3D:
	# Search for material by type and name
	var material_paths: Array[String] = WCSAssetRegistry.discover_assets_by_type("MaterialData")
	
	for material_path in material_paths:
		var material_data: MaterialData = WCSAssetLoader.load_asset(material_path)
		if material_data and material_data.material_type == material_type and material_data.material_name == material_name:
			return load_material_from_asset(material_path)
	
	push_warning("Material not found: %s (%s)" % [material_name, MaterialData.MaterialType.keys()[material_type]])
	return create_fallback_material(material_type)