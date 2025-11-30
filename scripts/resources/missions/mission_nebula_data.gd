extends Resource
class_name MissionNebulaData

## Nebula configuration for mission backgrounds

@export var texture: String = ""  # Nebula texture filename
@export var nebula_type: String = ""  # "full", "standard", or ""
@export var flags: int = 0
@export var color: String = ""  # Color specification from mission
@export var pitch: int = 0
@export var bank: int = 0
@export var heading: int = 0
