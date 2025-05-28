class_name WCSObject
extends Node3D

## Base class for all WCS game objects
## Provides common functionality for object lifecycle, identification, and data management

signal object_data_changed()
signal state_reset()

# Object identification
var object_id: int = -1
var object_type: String = ""
var update_frequency: int = 60  # Hz

# Object state
var is_initialized: bool = false
var object_data: WCSObjectData

func _ready() -> void:
	if not is_initialized:
		initialize_default()

# Object lifecycle methods

func initialize_from_data(data: WCSObjectData) -> void:
	object_data = data
	_apply_data_to_object()
	is_initialized = true

func initialize_default() -> void:
	object_data = WCSObjectData.new()
	object_data.object_type = object_type
	is_initialized = true

func reset_state() -> void:
	# Reset to clean state for object pooling
	transform = Transform3D.IDENTITY
	set_visible(true)
	set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	if object_data:
		object_data.reset_to_defaults()
		_apply_data_to_object()
	
	state_reset.emit()

# Object identification

func set_object_id(id: int) -> void:
	object_id = id

func get_object_id() -> int:
	return object_id

func set_object_type(type: String) -> void:
	object_type = type
	if object_data:
		object_data.object_type = type

func get_object_type() -> String:
	return object_type

func get_update_frequency() -> int:
	return update_frequency

func set_update_frequency(frequency: int) -> void:
	update_frequency = frequency

# Physics update (called by ObjectManager)
func _physics_update(delta: float) -> void:
	# Override in subclasses for specific physics behavior
	pass

# Data management

func _apply_data_to_object() -> void:
	if not object_data:
		return
	
	# Apply common data properties
	if object_data.has_property("position"):
		position = object_data.position
	
	if object_data.has_property("rotation"):
		rotation = object_data.rotation
	
	object_data_changed.emit()

func update_data_from_object() -> void:
	if not object_data:
		return
	
	# Update data from current object state
	object_data.position = position
	object_data.rotation = rotation
	
	object_data_changed.emit()

func get_object_data() -> WCSObjectData:
	return object_data

func set_object_data(data: WCSObjectData) -> void:
	object_data = data
	_apply_data_to_object()

# Debug helpers

func debug_info() -> String:
	return "WCSObject[ID:%d, Type:%s, Freq:%dHz]" % [object_id, object_type, update_frequency]
