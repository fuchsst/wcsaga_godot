extends Resource
class_name MissionMessage

const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")
const PersonaResource = preload("res://scripts/resources/persona/persona_resource.gd")

@export var name: String = "" # Internal ID
@export var team: MissionEnums.Team = MissionEnums.Team.UNKNOWN
@export var message_text: String = ""
@export var persona_name: String = ""
@export var avi_file: VideoStream = null
@export var wave_file: AudioStream = null

# Future-proofing/Refactoring fields
@export var persona: PersonaResource = null
@export var message_key: String = ""
