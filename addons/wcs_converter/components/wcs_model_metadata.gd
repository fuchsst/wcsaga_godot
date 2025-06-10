@tool
extends Node

## WCS Model Metadata Component
## Stores metadata and conversion information for imported WCS models

class_name WCSModelMetadata

@export var pof_file: String = ""
@export var conversion_data: Dictionary = {}
@export var model_name: String = ""
@export var model_version: int = 0
@export var subobject_count: int = 0
@export var texture_count: int = 0
@export var conversion_time: float = 0.0

func _init() -> void:
	name = "WCSModelMetadata"

func get_conversion_summary() -> String:
	"""Get a summary of the conversion process"""
	var summary: String = "WCS Model Conversion Summary:\n"
	summary += "Source POF: " + pof_file + "\n"
	summary += "Model: " + model_name + "\n"
	summary += "Subobjects: " + str(subobject_count) + "\n"
	summary += "Textures: " + str(texture_count) + "\n"
	summary += "Conversion time: " + str(conversion_time) + "s"
	return summary
