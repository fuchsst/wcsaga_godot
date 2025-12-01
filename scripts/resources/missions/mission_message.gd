extends Resource
class_name MissionMessage

const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")
const PersonaResource = preload("res://scripts/resources/persona/persona_resource.gd")

@export var team: MissionEnums.Team = MissionEnums.Team.UNKNOWN
@export var persona: PersonaResource = null
@export var message_key: String = "" # Key in the persona's message dictionary
