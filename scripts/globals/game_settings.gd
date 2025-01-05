extends Resource
class_name GameSettings

# Last pilot info
@export var last_pilot_callsign: String = ""
@export var last_pilot_was_multi: bool = false

# Audio settings
@export var master_volume: float = 1.0
@export var music_volume: float = 1.0
@export var voice_volume: float = 1.0
@export var effects_volume: float = 1.0
@export var briefing_voice_enabled: bool = true

# Control settings  
@export var use_mouse_to_fly: bool = true
@export var mouse_sensitivity: int = 5
@export var joystick_sensitivity: int = 5
@export var joystick_deadzone: int = 5

# Game settings
@export var skill_level: int = 2  # Medium by default
@export var brightness: float = 1.0

# Detail settings
@export var detail_distance: int = 3
@export var nebula_detail: int = 3
@export var hardware_textures: int = 3
@export var num_particles: int = 3
@export var shard_culling: int = 3
@export var shield_effects: int = 3
@export var num_stars: int = 3
@export var lighting: int = 3

# Display options
@export var planets_enabled: bool = true
@export var target_view_enabled: bool = true
@export var weapon_extras_enabled: bool = true

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
