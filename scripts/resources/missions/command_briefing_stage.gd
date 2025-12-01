extends Resource
class_name CommandBriefingStage

@export var text: String = ""
@export var ani_filename: String = "" # Animation file
@export var anim_stream: VideoStream = null # Or SpriteFrames if it's an ANI file
@export var wave_filename: String = "" # Audio file path
@export var audio_stream: AudioStream = null
