extends Resource
class_name BriefingStage

const BriefingIcon = preload("res://scripts/resources/missions/briefing_icon.gd")

@export var text: String = ""
@export var formula: String = ""
@export var camera_pos: Vector3 = Vector3.ZERO
@export var camera_orient: Basis = Basis.IDENTITY
@export var icons: Array[BriefingIcon] = []
@export var voice_file: String = ""
@export var voice_stream: AudioStream = null
