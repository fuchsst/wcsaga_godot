extends Resource
class_name MissionMessage

## In-mission communication message

@export var message_name: String = ""
@export var team: String = "" # Team the message relates to
@export var message_text: String = ""
@export var persona_name: String = "" # Persona delivering the message
@export var avi_filename: String = "" # Video file (if any)
@export var wave_filename: String = "" # Audio file path
@export var wave_audio: AudioStream = null # Loaded audio stream
