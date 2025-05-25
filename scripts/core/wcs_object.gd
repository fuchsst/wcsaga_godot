class_name WCSObject
extends Node3D

## Base class for all WCS game objects.
## Provides common functionality for object lifecycle, update management, and physics integration.

signal object_updated()
signal object_destroyed()

enum ObjectType {
	SHIP,
	WEAPON,
	DEBRIS,
	ASTEROID,
	EFFECT,
	WAYPOINT,
	UNKNOWN
}

enum UpdateFrequency {
	EVERY_FRAME,    # Critical objects (player ship, nearby enemies)
	HIGH,           # 30 FPS update rate
	MEDIUM,         # 15 FPS update rate  
	LOW             # 5 FPS update rate
}

@export var object_type: ObjectType = ObjectType.UNKNOWN
@export var update_frequency: UpdateFrequency = UpdateFrequency.MEDIUM
@export var max_lifetime: float = -1.0  # -1 means infinite
@export var auto_cleanup: bool = true

var object_id: int = -1
var creation_time: float
var last_update_time: float
var is_active: bool = true
var is_pooled: bool = false
var pool_type: String = ""

# Performance tracking
var frame_time_accumulator: float = 0.0
var frame_count: int = 0

func _ready() -> void:
	creation_time = Time.get_time_dict_from_system()["unix"]
	last_update_time = creation_time
	
	# Register with ObjectManager
	if ObjectManager:
		ObjectManager.register_object(self)

func _exit_tree() -> void:
	# Unregister from ObjectManager
	if ObjectManager:
		ObjectManager.unregister_object(self)

## Called by ObjectManager for scheduled updates
func scheduled_update(delta: float) -> void:
	if not is_active:
		return
		
	var start_time: float = Time.get_time_dict_from_system()["unix"]
	
	# Perform object-specific update logic
	_update_object(delta)
	
	# Track performance
	var frame_time: float = Time.get_time_dict_from_system()["unix"] - start_time
	_track_performance(frame_time)
	
	last_update_time = Time.get_time_dict_from_system()["unix"]
	object_updated.emit()
	
	# Check lifetime
	if max_lifetime > 0.0 and get_age() > max_lifetime:
		destroy()

## Override this in derived classes for object-specific update logic
func _update_object(delta: float) -> void:
	pass

## Get object age in seconds
func get_age() -> float:
	return Time.get_time_dict_from_system()["unix"] - creation_time

## Get time since last update in seconds  
func get_time_since_update() -> float:
	return Time.get_time_dict_from_system()["unix"] - last_update_time

## Get average frame time for performance monitoring
func get_average_frame_time() -> float:
	if frame_count == 0:
		return 0.0
	return frame_time_accumulator / frame_count

## Activate object for updates
func activate() -> void:
	is_active = true
	if ObjectManager:
		ObjectManager.activate_object(self)

## Deactivate object (stops updates but keeps in scene)
func deactivate() -> void:
	is_active = false
	if ObjectManager:
		ObjectManager.deactivate_object(self)

## Destroy object and clean up resources
func destroy() -> void:
	is_active = false
	object_destroyed.emit()
	
	if ObjectManager:
		ObjectManager.destroy_object(self)
	
	if auto_cleanup:
		queue_free()

## Reset object to initial state (for pooling)
func reset_for_pooling() -> void:
	is_active = true
	creation_time = Time.get_time_dict_from_system()["unix"]
	last_update_time = creation_time
	frame_time_accumulator = 0.0
	frame_count = 0
	
	# Reset transform
	transform = Transform3D.IDENTITY
	
	# Override in derived classes for specific reset logic
	_reset_object_state()

## Override this in derived classes for pooling reset logic
func _reset_object_state() -> void:
	pass

## Track performance metrics
func _track_performance(frame_time: float) -> void:
	frame_time_accumulator += frame_time
	frame_count += 1
	
	# Reset accumulator periodically to prevent overflow
	if frame_count >= 1000:
		frame_time_accumulator *= 0.9
		frame_count = int(frame_count * 0.9)

## Get debug information for this object
func get_debug_info() -> Dictionary:
	return {
		"id": object_id,
		"type": ObjectType.keys()[object_type],
		"update_frequency": UpdateFrequency.keys()[update_frequency],
		"age": get_age(),
		"active": is_active,
		"pooled": is_pooled,
		"avg_frame_time": get_average_frame_time(),
		"position": global_position,
		"lifetime_remaining": max_lifetime - get_age() if max_lifetime > 0 else -1
	}