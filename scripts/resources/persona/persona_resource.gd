class_name PersonaResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Persona Resource
##
## Defines a character persona, including their type, species, and associated messages.
## Maps to #Personas and #Messages sections in messages.tbl

@export_group("Identity")
@export var persona_name: String = ""
@export var type: String = "" # e.g. wingman, support
@export var species: String = "" # e.g. Kilrathi, Terran
@export var auto_assign: bool = false # +autoassign flag

@export_group("Messages")
## Dictionary of messages associated with this persona.
## Key: Message Name (e.g. "All Clear")
## Value: PersonaMessage
@export var messages: Dictionary = {}

func get_resource_type() -> String:
	return "persona"

func add_message(msg_name: String, text: String, avi: String, wave: String) -> void:
	var msg = PersonaMessage.new()
	msg.text = text
	msg.avi_filename = avi
	msg.wave_filename = wave
	messages[msg_name] = msg

## Inner class for typed message data
class PersonaMessage:
	extends Resource
	
	@export var text: String = ""
	var avi_filename: String = ""
	var wave_filename: String = ""
	
	## The actual audio stream resource (loaded from wave_filename)
	@export var wave_stream: AudioStream
	
	## The actual video stream resource (loaded from avi_filename)
	@export var avi_stream: VideoStream
