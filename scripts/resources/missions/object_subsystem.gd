extends Resource
class_name ObjectSubsystem

## Subsystem configuration for mission objects

@export var subsystem_name: String = ""
@export var damage: float = 0.0  # Percentage damage (0-100)
@export var cargo_name: String = ""
@export var primary_banks: Array[String] = []
@export var secondary_banks: Array[String] = []
