@tool
extends Resource
class_name SoundEntry

enum SoundType {
	NORMAL = 0,
	STEREO_3D = 1,
	AUREAL_A3D = 2
}


@export var audio_file: AudioStream
@export var volume: float = 1.0
@export var type: SoundType = SoundType.NORMAL
@export var min_distance: float = 0.0
@export var max_distance: float = 0.0

func _get_property_list() -> Array:
	# This ensures the resource shows up with its resource_name in the editor
	var properties = []
	properties.append({
		"name": "resource_name",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR_INSTANTIATE_OBJECT
	})
	return properties
