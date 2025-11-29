extends Resource
class_name BackgroundData

## Mission background configuration including skybox, nebula, and stars
const MissionNebulaData = preload("res://scripts/resources/missions/mission_nebula_data.gd")
const BackgroundSet = preload("res://scripts/resources/missions/background_set.gd")
@export var num_stars: int = 0
@export var ambient_light_level: int = 0
@export var nebula: MissionNebulaData = null
@export var backgrounds: Array[BackgroundSet] = [] # Multiple background sets possible
