extends Resource
class_name BackgroundData

## Mission background configuration including skybox, nebula, and stars

@export var num_stars: int = 0
@export var ambient_light_level: int = 0
@export var nebula: MissionNebulaData = null
@export var backgrounds: Array[BackgroundSet] = [] # Multiple background sets possible
