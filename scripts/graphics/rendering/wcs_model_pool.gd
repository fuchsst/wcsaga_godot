class_name WCSModelPool
extends Node

## Model instance pooling system for efficient ship spawning
## Pre-allocates model instances to avoid runtime allocation overhead

signal pool_expanded(new_size: int)
signal pool_utilization_changed(used: int, total: int)

var pool_type: String
var pool_instances: Array[Node3D] = []
var used_instances: Array[bool] = []
var max_pool_size: int
var current_pool_size: int = 0
var expansion_size: int = 5

func _init(type: String, initial_size: int) -> void:
	pool_type = type
	max_pool_size = initial_size * 3  # Allow 3x expansion
	name = "ModelPool_" + type
	
	# Initialize pool
	_allocate_pool_instances(initial_size)

func _allocate_pool_instances(size: int) -> void:
	for i in range(size):
		var placeholder: Node3D = Node3D.new()
		placeholder.name = "PooledInstance_%s_%d" % [pool_type, i]
		placeholder.visible = false
		
		pool_instances.append(placeholder)
		used_instances.append(false)
		add_child(placeholder)
	
	current_pool_size = size
	print("WCSModelPool (%s): Allocated %d instances" % [pool_type, size])

func acquire_instance() -> Node3D:
	# Find an unused instance
	for i in range(current_pool_size):
		if not used_instances[i]:
			used_instances[i] = true
			var instance: Node3D = pool_instances[i]
			instance.visible = true
			_update_utilization()
			return instance
	
	# No free instances, try to expand pool
	if current_pool_size < max_pool_size:
		_expand_pool()
		return acquire_instance()
	
	# Pool exhausted
	push_warning("Model pool (%s) exhausted - consider increasing pool size" % pool_type)
	return null

func release_instance(instance: Node3D) -> void:
	# Find and release the instance
	for i in range(current_pool_size):
		if pool_instances[i] == instance:
			if used_instances[i]:
				used_instances[i] = false
				instance.visible = false
				_reset_instance(instance)
				_update_utilization()
				return
	
	push_warning("Attempted to release instance not from this pool: " + str(instance))

func _expand_pool() -> void:
	var new_size: int = min(current_pool_size + expansion_size, max_pool_size)
	var instances_to_add: int = new_size - current_pool_size
	
	_allocate_pool_instances(instances_to_add)
	pool_expanded.emit(new_size)
	print("WCSModelPool (%s): Expanded to %d instances" % [pool_type, new_size])

func _reset_instance(instance: Node3D) -> void:
	# Reset instance to default state
	instance.position = Vector3.ZERO
	instance.rotation = Vector3.ZERO
	instance.scale = Vector3.ONE
	
	# Remove any children that were added during use
	for child in instance.get_children():
		child.queue_free()

func _update_utilization() -> void:
	var used_count: int = 0
	for used in used_instances:
		if used:
			used_count += 1
	
	pool_utilization_changed.emit(used_count, current_pool_size)

func get_pool_statistics() -> Dictionary:
	var used_count: int = 0
	for used in used_instances:
		if used:
			used_count += 1
	
	return {
		"pool_type": pool_type,
		"total_instances": current_pool_size,
		"used_instances": used_count,
		"available_instances": current_pool_size - used_count,
		"utilization_percent": float(used_count) / float(current_pool_size) * 100.0,
		"max_pool_size": max_pool_size,
		"can_expand": current_pool_size < max_pool_size
	}

func is_pool_available() -> bool:
	# Check if pool has available instances or can expand
	for used in used_instances:
		if not used:
			return true
	
	return current_pool_size < max_pool_size

func get_available_count() -> int:
	var available: int = 0
	for used in used_instances:
		if not used:
			available += 1
	
	return available

func cleanup_pool() -> void:
	# Clean up unused instances to free memory
	for i in range(current_pool_size):
		if not used_instances[i]:
			var instance: Node3D = pool_instances[i]
			_reset_instance(instance)

func resize_pool(new_size: int) -> void:
	new_size = clamp(new_size, 1, max_pool_size)
	
	if new_size > current_pool_size:
		# Expand pool
		_allocate_pool_instances(new_size - current_pool_size)
	elif new_size < current_pool_size:
		# Shrink pool (only remove unused instances)
		var instances_to_remove: int = current_pool_size - new_size
		var removed: int = 0
		
		for i in range(current_pool_size - 1, -1, -1):
			if removed >= instances_to_remove:
				break
			
			if not used_instances[i]:
				var instance: Node3D = pool_instances[i]
				instance.queue_free()
				pool_instances.remove_at(i)
				used_instances.remove_at(i)
				removed += 1
		
		current_pool_size = pool_instances.size()

func force_release_all() -> void:
	# Force release all instances (emergency cleanup)
	for i in range(current_pool_size):
		if used_instances[i]:
			used_instances[i] = false
			var instance: Node3D = pool_instances[i]
			instance.visible = false
			_reset_instance(instance)
	
	_update_utilization()
	print("WCSModelPool (%s): Force released all instances" % pool_type)

func _exit_tree() -> void:
	# Clean shutdown
	force_release_all()
	
	for instance in pool_instances:
		if is_instance_valid(instance):
			instance.queue_free()
	
	pool_instances.clear()
	used_instances.clear()