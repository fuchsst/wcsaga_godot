extends Node

## Mock ObjectManager for performance testing

signal object_created(object: Object)
signal object_destroyed(object: Object)
signal space_object_created(object: Object, object_id: int)
signal space_object_destroyed(object: Object, object_id: int)

var active_object_count: int = 50
var space_object_count: int = 30
var pool_statistics: Dictionary = {
	"ship_pool": {
		"memory_usage_bytes": 1024 * 1024 * 5,  # 5MB
		"cache_hits": 80,
		"cache_misses": 20
	},
	"weapon_pool": {
		"memory_usage_bytes": 1024 * 1024 * 2,  # 2MB
		"cache_hits": 150,
		"cache_misses": 10
	}
}

func get_active_object_count() -> int:
	return active_object_count

func get_space_object_count() -> int:
	return space_object_count

func get_pool_statistics() -> Dictionary:
	return pool_statistics

func optimize_object_pools() -> void:
	print("MockObjectManager: Optimizing object pools")

func reduce_pool_sizes(factor: float) -> void:
	print("MockObjectManager: Reducing pool sizes by factor %.2f" % factor)

func cleanup_pool(pool_name: String, cleanup_ratio: float) -> void:
	print("MockObjectManager: Cleaning up pool %s by %.2f" % [pool_name, cleanup_ratio])

func get_all_active_objects() -> Array:
	var objects: Array = []
	for i in range(active_object_count):
		var obj: Node = Node.new()
		obj.name = "MockObject_%d" % i
		objects.append(obj)
	return objects