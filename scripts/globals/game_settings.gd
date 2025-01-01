extends Resource
class_name GameSettings

# Last pilot info
@export var last_pilot_callsign: String = ""
@export var last_pilot_was_multi: bool = false

# Global settings
@export var master_volume: float = 1.0
@export var music_volume: float = 1.0
@export var voice_volume: float = 1.0

# Save settings to user://settings.tres
func save() -> bool:
	return ResourceSaver.save(self, "user://settings.tres") == OK

# Load settings from user://settings.tres
static func load_or_create() -> GameSettings:
	if ResourceLoader.exists("user://settings.tres"):
		return ResourceLoader.load("user://settings.tres") as GameSettings
	
	var settings = GameSettings.new()
	settings.save()
	return settings
