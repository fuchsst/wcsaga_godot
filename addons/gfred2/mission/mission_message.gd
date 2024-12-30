@tool
extends Resource
class_name MissionMessage

# Message properties
@export var name := ""  # Unique identifier
@export var text := ""  # Message content
@export var priority := 1  # 0=Low, 1=Normal, 2=High
@export var team := 0  # Team that sends the message
@export var persona_index := -1  # -1 means no persona
@export var wave_file := ""  # Voice file
@export var ani_file := ""  # Animation file

# Message flags
@export var team_specific := false  # Only show to specific team
@export var no_music := false  # Don't play music
@export var no_special_music := false  # Don't play special music

func _init():
	# Set default values
	name = "New Message"
	text = "Enter message text here"
	priority = 1  # Normal priority
	team = 0  # Friendly team
	persona_index = -1  # No persona
	wave_file = ""
	ani_file = ""
	team_specific = false
	no_music = false
	no_special_music = false

func validate() -> Array:
	var errors := []
	
	# Check required fields
	if name.is_empty():
		errors.append("Message requires a name")
	if text.is_empty():
		errors.append("Message '%s' requires text" % name)
		
	# Check wave file exists if specified
	if !wave_file.is_empty():
		var file = FileAccess.open(wave_file, FileAccess.READ)
		if !file:
			errors.append("Message '%s' wave file not found: %s" % [name, wave_file])
			
	# Check ani file exists if specified  
	if !ani_file.is_empty():
		var file = FileAccess.open(ani_file, FileAccess.READ)
		if !file:
			errors.append("Message '%s' ani file not found: %s" % [name, ani_file])
			
	# Check persona index is valid
	if persona_index >= 0:
		# TODO: Check against actual persona list
		pass
		
	return errors
