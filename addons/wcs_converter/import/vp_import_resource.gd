## VP Import Resource Class
class_name VPImportResource
extends Resource

## Resource representing imported VP archive with metadata

@export var source_vp_file: String = ""
@export var extracted_directory: String = ""
@export var file_count: int = 0
@export var extraction_time: float = 0.0
@export var manifest_data: Dictionary = {}

func _init() -> void:
	resource_name = "VP Archive Import"
