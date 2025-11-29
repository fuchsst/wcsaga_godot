extends Node3D

class_name Lightning

@export var resource: LightningResource
@export var volume_size: Vector3 = Vector3(500, 500, 500) # Default storm volume
@export var auto_start: bool = true

var _timer: float = 0.0
var _next_spawn_time: float = 0.0
var _is_running: bool = false

# Cache for loaded bolt resources
var _bolt_cache: Dictionary = {}

func _ready():
	if auto_start and resource:
		start()

func start():
	_is_running = true
	if resource.type == LightningResource.LightningType.STORM:
		_schedule_next_bolt()
	elif resource.type == LightningResource.LightningType.BOLT:
		# If it's a single bolt resource, just spawn one immediately
		# For a standalone bolt, we might need start/end points defined externally
		# For now, just spawn one random one in the volume or at origin
		spawn_bolt(resource.name, global_position, global_position + Vector3(0, -50, 0))

func stop():
	_is_running = false

func _process(delta):
	if not _is_running:
		return
		
	if resource.type == LightningResource.LightningType.STORM:
		_process_storm(delta)

func _process_storm(delta):
	_timer += delta
	if _timer >= _next_spawn_time:
		_timer = 0.0
		_schedule_next_bolt()
		_spawn_storm_bolts()

func _schedule_next_bolt():
	var min_time = resource.s_random_freq_min
	var max_time = resource.s_random_freq_max
	_next_spawn_time = randf_range(min_time, max_time)

func _spawn_storm_bolts():
	var count = randi_range(resource.s_random_count_min, resource.s_random_count_max)
	
	for i in range(count):
		if resource.s_bolt_types.is_empty():
			continue
			
		var type_idx = randi() % resource.s_bolt_types.size()
		var bolt_name = resource.s_bolt_types[type_idx]
		
		# Generate random start/end points within volume
		var start = _get_random_point_in_volume()
		var end = _get_random_point_in_volume()
		
		# Apply flavor (wing sauce)
		if resource.s_flavor != Vector3.ZERO:
			# This logic mimics the C++ flavor addition roughly
			var dir = (end - start).normalized()
			var flavor = resource.s_flavor
			if randf() < 0.5:
				flavor = - flavor
			
			# Bias the end point
			end += flavor * randf_range(0.5, 1.5)
			
		spawn_bolt(bolt_name, start, end)

func _get_random_point_in_volume() -> Vector3:
	var half = volume_size * 0.5
	return global_position + Vector3(
		randf_range(-half.x, half.x),
		randf_range(-half.y, half.y),
		randf_range(-half.z, half.z)
	)

func spawn_bolt(bolt_name: String, start: Vector3, end: Vector3):
	var bolt_res = _get_bolt_resource(bolt_name)
	if not bolt_res:
		push_warning("Lightning: Could not find bolt resource: " + bolt_name)
		return
		
	var bolt = LightningBolt.new()
	add_child(bolt)
	bolt.setup(start, end, bolt_res)

func _get_bolt_resource(bolt_name: String) -> LightningResource:
	if _bolt_cache.has(bolt_name):
		return _bolt_cache[bolt_name]
		
	# Try to load from standard path
	# Assuming bolts are in effects/lightning/bolts/
	var path = "res://assets/effects/lightning/bolts/" + bolt_name + ".tres"
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is LightningResource:
			_bolt_cache[bolt_name] = res
			return res
			
	return null
