class_name WCSDynamicLightPool
extends Node

## Efficient light pooling system for dynamic combat lighting
## Provides pre-allocated light instances to avoid runtime allocation overhead

signal pool_exhausted(light_type: int)
signal pool_capacity_changed(new_capacity: int)

# Light pools by type
var light_pools: Dictionary = {}
var pool_sizes: Dictionary = {}
var max_capacity: int
var total_lights_allocated: int = 0

func _init(capacity: int = 32) -> void:
	max_capacity = capacity
	_initialize_pools()

func _ready() -> void:
	name = "WCSDynamicLightPool"
	print("WCSDynamicLightPool: Initialized with capacity %d" % max_capacity)

func _initialize_pools() -> void:
	# Allocate pools based on expected usage patterns
	var pool_allocations: Dictionary = {
		WCSLightingController.DynamicLightType.WEAPON_MUZZLE_FLASH: max(max_capacity / 4, 8),  # 25% - frequent
		WCSLightingController.DynamicLightType.LASER_BEAM: max(max_capacity / 6, 5),           # 17% - common
		WCSLightingController.DynamicLightType.EXPLOSION: max(max_capacity / 8, 4),            # 12% - moderate
		WCSLightingController.DynamicLightType.ENGINE_GLOW: max(max_capacity / 4, 6),          # 25% - persistent
		WCSLightingController.DynamicLightType.THRUSTER: max(max_capacity / 8, 3),             # 12% - ships
		WCSLightingController.DynamicLightType.SHIELD_IMPACT: max(max_capacity / 12, 2)        # 8% - situational
	}
	
	# Initialize each pool
	for light_type in pool_allocations:
		var pool_size: int = pool_allocations[light_type]
		light_pools[light_type] = []
		pool_sizes[light_type] = pool_size
		
		# Pre-allocate lights for this type
		for i in range(pool_size):
			var light: Light3D = _create_light_for_type(light_type)
			light.visible = false
			light_pools[light_type].append(light)
			total_lights_allocated += 1
	
	print("WCSDynamicLightPool: Allocated %d lights across %d types" % [total_lights_allocated, light_pools.size()])

func _create_light_for_type(light_type: WCSLightingController.DynamicLightType) -> Light3D:
	var light: Light3D
	
	match light_type:
		WCSLightingController.DynamicLightType.WEAPON_MUZZLE_FLASH, \
		WCSLightingController.DynamicLightType.EXPLOSION, \
		WCSLightingController.DynamicLightType.ENGINE_GLOW, \
		WCSLightingController.DynamicLightType.SHIELD_IMPACT:
			# Use OmniLight3D for point-source lights
			light = OmniLight3D.new()
		
		WCSLightingController.DynamicLightType.LASER_BEAM, \
		WCSLightingController.DynamicLightType.THRUSTER:
			# Use SpotLight3D for directional lights
			light = SpotLight3D.new()
	
	# Basic configuration
	light.name = "PooledLight_" + WCSLightingController.DynamicLightType.keys()[light_type]
	light.visible = false
	light.light_energy = 0.0
	
	return light

func get_light(light_type: WCSLightingController.DynamicLightType) -> Light3D:
	if light_type not in light_pools:
		push_error("Invalid light type: " + str(light_type))
		return null
	
	var pool: Array = light_pools[light_type]
	
	# Find an available light in the pool
	for i in range(pool.size()):
		var light: Light3D = pool[i]
		if not light.visible:  # Available light
			# Reset light to clean state
			_reset_light(light)
			light.visible = true
			return light
	
	# Pool exhausted - try to create emergency light if total capacity allows
	if total_lights_allocated < max_capacity * 1.2:  # Allow 20% overflow
		var emergency_light: Light3D = _create_light_for_type(light_type)
		total_lights_allocated += 1
		print("WCSDynamicLightPool: Created emergency light for type ", WCSLightingController.DynamicLightType.keys()[light_type])
		return emergency_light
	
	pool_exhausted.emit(light_type)
	push_warning("Light pool exhausted for type: " + WCSLightingController.DynamicLightType.keys()[light_type])
	return null

func return_light(light: Light3D, light_type: WCSLightingController.DynamicLightType) -> void:
	if not light or light_type not in light_pools:
		return
	
	# Reset light to pool state
	_reset_light(light)
	light.visible = false
	
	# Remove from scene tree if it was added
	if light.get_parent():
		light.get_parent().remove_child(light)
	
	# Return to appropriate pool if it belongs to one
	var pool: Array = light_pools[light_type]
	var light_name_prefix: String = "PooledLight_" + WCSLightingController.DynamicLightType.keys()[light_type]
	
	if light.name.begins_with(light_name_prefix):
		# This is a pooled light, it's already in the pool
		pass
	else:
		# This is an emergency light, add it to the pool if there's space
		if pool.size() < pool_sizes[light_type] * 1.5:  # Allow pool to grow slightly
			pool.append(light)
		else:
			# Pool is full, dispose of emergency light
			light.queue_free()
			total_lights_allocated -= 1

func _reset_light(light: Light3D) -> void:
	# Reset light to neutral state
	light.light_energy = 0.0
	light.light_color = Color.WHITE
	light.position = Vector3.ZERO
	light.rotation = Vector3.ZERO
	
	if light is OmniLight3D:
		var omni_light: OmniLight3D = light as OmniLight3D
		omni_light.omni_range = 10.0
		omni_light.omni_attenuation = 1.0
	elif light is SpotLight3D:
		var spot_light: SpotLight3D = light as SpotLight3D
		spot_light.spot_range = 10.0
		spot_light.spot_angle = 30.0
		spot_light.spot_attenuation = 1.0

func update_capacity(new_capacity: int) -> void:
	if new_capacity == max_capacity:
		return
	
	var old_capacity: int = max_capacity
	max_capacity = new_capacity
	
	if new_capacity > old_capacity:
		# Expand pools
		_expand_pools(new_capacity - old_capacity)
	else:
		# Shrink pools
		_shrink_pools(old_capacity - new_capacity)
	
	pool_capacity_changed.emit(new_capacity)
	print("WCSDynamicLightPool: Capacity updated from %d to %d" % [old_capacity, new_capacity])

func _expand_pools(additional_capacity: int) -> void:
	# Distribute additional capacity across pools proportionally
	var total_current_size: int = 0
	for light_type in pool_sizes:
		total_current_size += pool_sizes[light_type]
	
	for light_type in light_pools:
		var current_size: int = pool_sizes[light_type]
		var proportion: float = float(current_size) / float(total_current_size)
		var additional_lights: int = int(additional_capacity * proportion)
		
		# Add lights to this pool
		for i in range(additional_lights):
			var light: Light3D = _create_light_for_type(light_type)
			light.visible = false
			light_pools[light_type].append(light)
			total_lights_allocated += 1
		
		pool_sizes[light_type] += additional_lights

func _shrink_pools(capacity_reduction: int) -> void:
	# Remove lights from pools proportionally
	var lights_to_remove: int = capacity_reduction
	
	for light_type in light_pools:
		if lights_to_remove <= 0:
			break
		
		var pool: Array = light_pools[light_type]
		var current_size: int = pool.size()
		var target_reduction: int = min(lights_to_remove, current_size / 2)  # Don't remove more than half
		
		# Remove available (invisible) lights first
		for i in range(current_size - 1, -1, -1):
			if target_reduction <= 0:
				break
			
			var light: Light3D = pool[i]
			if not light.visible:  # Only remove available lights
				light.queue_free()
				pool.remove_at(i)
				total_lights_allocated -= 1
				lights_to_remove -= 1
				target_reduction -= 1
		
		pool_sizes[light_type] = pool.size()

func get_pool_statistics() -> Dictionary:
	var stats: Dictionary = {
		"max_capacity": max_capacity,
		"total_allocated": total_lights_allocated,
		"pool_utilization": {},
		"available_lights": {},
		"active_lights": {}
	}
	
	for light_type in light_pools:
		var pool: Array = light_pools[light_type]
		var available_count: int = 0
		var active_count: int = 0
		
		for light in pool:
			if light.visible:
				active_count += 1
			else:
				available_count += 1
		
		var type_name: String = WCSLightingController.DynamicLightType.keys()[light_type]
		stats.available_lights[type_name] = available_count
		stats.active_lights[type_name] = active_count
		stats.pool_utilization[type_name] = float(active_count) / float(pool.size()) if pool.size() > 0 else 0.0
	
	return stats

func cleanup_emergency_lights() -> void:
	# Clean up any emergency lights that are no longer needed
	for light_type in light_pools:
		var pool: Array = light_pools[light_type]
		var target_size: int = pool_sizes[light_type]
		
		# If pool is oversized, remove excess available lights
		while pool.size() > target_size:
			var removed: bool = false
			for i in range(pool.size() - 1, -1, -1):
				var light: Light3D = pool[i]
				if not light.visible:  # Available light
					light.queue_free()
					pool.remove_at(i)
					total_lights_allocated -= 1
					removed = true
					break
			
			if not removed:
				break  # No more available lights to remove

func force_cleanup_all_lights() -> void:
	# Emergency cleanup - force all lights to be available
	for light_type in light_pools:
		var pool: Array = light_pools[light_type]
		for light in pool:
			if light.visible:
				_reset_light(light)
				light.visible = false
				if light.get_parent():
					light.get_parent().remove_child(light)

func _exit_tree() -> void:
	# Clean up all allocated lights
	for light_type in light_pools:
		var pool: Array = light_pools[light_type]
		for light in pool:
			if is_instance_valid(light):
				light.queue_free()
	
	light_pools.clear()
	pool_sizes.clear()
	total_lights_allocated = 0