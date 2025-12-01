extends Resource
class_name BackgroundSet
const SunData = preload("res://scripts/resources/missions/sun_data.gd")
const StarBitmapData = preload("res://scripts/resources/environment/stars/star_bitmap_data.gd")
## A set of background elements (suns + star bitmaps)
## Multiple sets can exist in a mission

const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")

@export var suns: Array[SunData] = []
@export var bitmaps: Array[StarBitmapData] = []

# Skybox overrides if any
@export var skybox: Sky = null # Godot Sky resource
@export var skybox_flags: Array[MissionEnums.SkyboxFlags] = []
