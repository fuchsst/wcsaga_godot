extends Resource
class_name BriefingStage

@export var text: String = ""
@export var formula: String = ""
@export var camera_pos: Vector3 = Vector3.ZERO
@export var camera_orient: Vector3 = Vector3.ZERO
@export var icons: Array[Dictionary] = []  # Icon data is complex, keep as dict for now or define Icon class
@export var voice_file: String = ""
@export var voice_audio: AudioStream = null  # Loaded voice audio
