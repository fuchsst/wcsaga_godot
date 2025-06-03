class_name MaterialCache
extends RefCounted

## Advanced LRU material cache with memory management
## Provides efficient storage and retrieval of converted materials

signal cache_updated(cache_size: int, memory_usage: int)
signal material_evicted(material_name: String)
signal cache_full()

# Cache storage
var materials: Dictionary = {}
var access_order: Array[String] = []
var memory_usage: int = 0

# Cache configuration
var size_limit: int = 100
var memory_limit: int = 256 * 1024 * 1024  # 256 MB
var enable_lru: bool = true

# Statistics
var cache_hits: int = 0
var cache_misses: int = 0
var total_requests: int = 0

func _init(max_size: int = 100, max_memory: int = 256 * 1024 * 1024) -> void:
	size_limit = max_size
	memory_limit = max_memory

func store_material(material_name: String, material: StandardMaterial3D) -> bool:
	# Check if material already exists
	if material_name in materials:
		_update_access_order(material_name)
		return true
	
	var material_memory: int = _estimate_material_memory(material)
	
	# Check memory limit
	if memory_usage + material_memory > memory_limit:
		if not _free_memory_for_material(material_memory):
			cache_full.emit()
			return false
	
	# Check size limit
	if materials.size() >= size_limit:
		if not _evict_lru_material():
			return false
	
	# Store the material
	materials[material_name] = material
	memory_usage += material_memory
	_add_to_access_order(material_name)
	
	cache_updated.emit(materials.size(), memory_usage)
	return true

func get_material(material_name: String) -> StandardMaterial3D:
	total_requests += 1
	
	if material_name in materials:
		cache_hits += 1
		_update_access_order(material_name)
		return materials[material_name]
	else:
		cache_misses += 1
		return null

func has_material(material_name: String) -> bool:
	return material_name in materials

func remove_material(material_name: String) -> bool:
	if material_name in materials:
		var material: StandardMaterial3D = materials[material_name]
		memory_usage -= _estimate_material_memory(material)
		materials.erase(material_name)
		_remove_from_access_order(material_name)
		cache_updated.emit(materials.size(), memory_usage)
		return true
	return false

func clear() -> void:
	materials.clear()
	access_order.clear()
	memory_usage = 0
	cache_hits = 0
	cache_misses = 0
	total_requests = 0
	cache_updated.emit(0, 0)

func _update_access_order(material_name: String) -> void:
	if not enable_lru:
		return
	
	# Move to end (most recently used)
	var index: int = access_order.find(material_name)
	if index != -1:
		access_order.remove_at(index)
		access_order.append(material_name)

func _add_to_access_order(material_name: String) -> void:
	if not enable_lru:
		return
	
	access_order.append(material_name)

func _remove_from_access_order(material_name: String) -> void:
	if not enable_lru:
		return
	
	var index: int = access_order.find(material_name)
	if index != -1:
		access_order.remove_at(index)

func _evict_lru_material() -> bool:
	if access_order.is_empty():
		return false
	
	# Remove least recently used (first in array)
	var lru_material: String = access_order[0]
	material_evicted.emit(lru_material)
	return remove_material(lru_material)

func _free_memory_for_material(required_memory: int) -> bool:
	# Try to free enough memory by evicting materials
	var freed_memory: int = 0
	var materials_to_evict: Array[String] = []
	
	# Calculate which materials to evict
	for material_name in access_order:
		if freed_memory >= required_memory:
			break
		
		var material: StandardMaterial3D = materials[material_name]
		freed_memory += _estimate_material_memory(material)
		materials_to_evict.append(material_name)
	
	# Evict the materials
	for material_name in materials_to_evict:
		remove_material(material_name)
		material_evicted.emit(material_name)
	
	return freed_memory >= required_memory

func _estimate_material_memory(material: StandardMaterial3D) -> int:
	# Estimate memory usage of a material
	var base_size: int = 1024  # Base material size
	var texture_memory: int = 0
	
	# Estimate texture memory (rough approximation)
	if material.albedo_texture:
		texture_memory += _estimate_texture_memory(material.albedo_texture)
	if material.normal_texture:
		texture_memory += _estimate_texture_memory(material.normal_texture)
	if material.metallic_texture:
		texture_memory += _estimate_texture_memory(material.metallic_texture)
	if material.roughness_texture:
		texture_memory += _estimate_texture_memory(material.roughness_texture)
	if material.emission_texture:
		texture_memory += _estimate_texture_memory(material.emission_texture)
	if material.detail_albedo:
		texture_memory += _estimate_texture_memory(material.detail_albedo)
	if material.detail_normal:
		texture_memory += _estimate_texture_memory(material.detail_normal)
	
	return base_size + texture_memory

func _estimate_texture_memory(texture: Texture2D) -> int:
	if not texture:
		return 0
	
	# Rough estimation based on texture size
	var width: int = texture.get_width()
	var height: int = texture.get_height()
	
	# Assume 4 bytes per pixel (RGBA) as average
	return width * height * 4

func get_cache_stats() -> Dictionary:
	var hit_rate: float = 0.0
	if total_requests > 0:
		hit_rate = float(cache_hits) / float(total_requests)
	
	return {
		"size": materials.size(),
		"size_limit": size_limit,
		"memory_usage": memory_usage,
		"memory_limit": memory_limit,
		"cache_hits": cache_hits,
		"cache_misses": cache_misses,
		"total_requests": total_requests,
		"hit_rate": hit_rate,
		"memory_usage_mb": memory_usage / (1024.0 * 1024.0),
		"memory_limit_mb": memory_limit / (1024.0 * 1024.0)
	}

func get_material_list() -> Array[String]:
	return materials.keys()

func get_memory_usage_breakdown() -> Dictionary:
	var breakdown: Dictionary = {}
	
	for material_name in materials.keys():
		var material: StandardMaterial3D = materials[material_name]
		breakdown[material_name] = _estimate_material_memory(material)
	
	return breakdown

func optimize_cache() -> void:
	# Force garbage collection of unused materials
	if access_order.size() != materials.size():
		# Rebuild access order
		access_order.clear()
		for material_name in materials.keys():
			access_order.append(material_name)
	
	# Recalculate memory usage
	var new_memory_usage: int = 0
	for material_name in materials.keys():
		var material: StandardMaterial3D = materials[material_name]
		new_memory_usage += _estimate_material_memory(material)
	
	if new_memory_usage != memory_usage:
		memory_usage = new_memory_usage
		cache_updated.emit(materials.size(), memory_usage)

func set_cache_limits(new_size_limit: int, new_memory_limit: int) -> void:
	size_limit = new_size_limit
	memory_limit = new_memory_limit
	
	# Evict materials if over new limits
	while materials.size() > size_limit:
		if not _evict_lru_material():
			break
	
	while memory_usage > memory_limit:
		if not _evict_lru_material():
			break

func preload_materials(material_list: Array[StandardMaterial3D]) -> void:
	# Preload materials without affecting LRU order much
	var original_lru_setting: bool = enable_lru
	enable_lru = false
	
	for material in material_list:
		if material and material.resource_name:
			store_material(material.resource_name, material)
	
	enable_lru = original_lru_setting