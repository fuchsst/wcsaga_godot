extends Resource
class_name BackgroundData

const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")
const MissionNebulaData = preload("res://scripts/resources/missions/mission_nebula_data.gd")
const SunData = preload("res://scripts/resources/missions/sun_data.gd")
const BackgroundSet = preload("res://scripts/resources/missions/background_set.gd")

## Mission background configuration

# Skybox
@export var skybox_model: Sky = null # Godot Sky resource
@export var skybox_flags: Array[MissionEnums.SkyboxFlags] = []

# Stars/Suns
@export var num_suns: int = 0
@export var suns: Array[SunData] = []
@export var background_sets: Array[BackgroundSet] = [] # Bitmaps/Stars

# Nebula
@export var nebula: MissionNebulaData = MissionNebulaData.new()
@export var neb_awacs: float = -1.0
@export var storm_name: String = ""
