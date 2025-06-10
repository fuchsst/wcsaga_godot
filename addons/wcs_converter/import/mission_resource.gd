## Mission Resource Class
class_name MissionResource
extends Resource

## Resource representing imported mission with metadata

@export var mission_name: String = ""
@export var source_file: String = ""
@export var ship_count: int = 0
@export var waypoint_count: int = 0
@export var event_count: int = 0
@export var goal_count: int = 0
@export var conversion_metadata: Dictionary = {}

func _init() -> void:
	resource_name = "Mission Data"
