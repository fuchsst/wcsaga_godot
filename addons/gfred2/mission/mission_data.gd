@tool
extends Resource
class_name MissionData

# Mission metadata
@export var title := "Untitled"
@export var designer := "Unknown"
@export var description := ""
@export var designer_notes := ""

enum MissionType {
	SINGLE_PLAYER,
	MULTI_PLAYER,
	TRAINING,
	COOPERATIVE,
	TEAM_VS_TEAM,
	DOGFIGHT
}

@export var mission_type: MissionType = MissionType.SINGLE_PLAYER

# Mission flags
@export var all_teams_at_war := false
@export var red_alert := false
@export var scramble := false
@export var no_briefing := false
@export var no_debriefing := false
@export var disable_builtin_messages := false
@export var no_traitor := false
@export var is_training := false

# Support ship settings
@export var disallow_support_ships := false
@export var support_ships_repair_hull := false
@export var hull_repair_ceiling := 0.0
@export var subsystem_repair_ceiling := 100.0

# Loading screens
@export_file("*.png") var loading_screen_640 := ""
@export_file("*.png") var loading_screen_1024 := ""

# Squadron settings
@export var squadron_name := "<none>"
@export_file("*.png") var squadron_logo := ""

# Mission objects
var objects := {}  # Dictionary of all mission objects by ID
var root_objects := []  # Top-level objects (no parent)

# Mission events
var events := []
var event_tree := {}  # Tree structure for event chains

# Mission goals
var primary_goals := []
var secondary_goals := []
var hidden_goals := []

# Mission variables
var variables := {}

# Mission statistics
var stats := {
	"created": "",
	"modified": "",
	"num_ships": 0,
	"num_wings": 0,
	"num_events": 0,
	"num_goals": 0
}

func _init():
	# Set creation time
	stats.created = Time.get_datetime_string_from_system()
	stats.modified = stats.created

func add_object(object: MissionObject, parent: MissionObject = null) -> void:
	# Add to objects dictionary
	objects[object.id] = object
	
	if parent:
		# Add as child of parent
		parent.add_child(object)
	else:
		# Add to root objects
		root_objects.append(object)
	
	# Update statistics
	match object.type:
		MissionObject.Type.SHIP:
			stats.num_ships += 1
		MissionObject.Type.WING:
			stats.num_wings += 1
	
	stats.modified = Time.get_datetime_string_from_system()

func remove_object(object: MissionObject) -> void:
	# Remove from objects dictionary
	objects.erase(object.id)
	
	if object.parent:
		# Remove from parent
		object.parent.remove_child(object)
	else:
		# Remove from root objects
		root_objects.erase(object)
	
	# Update statistics
	match object.type:
		MissionObject.Type.SHIP:
			stats.num_ships -= 1
		MissionObject.Type.WING:
			stats.num_wings -= 1
	
	stats.modified = Time.get_datetime_string_from_system()

func add_event(event: MissionEvent) -> void:
	events.append(event)
	stats.num_events += 1
	stats.modified = Time.get_datetime_string_from_system()

func remove_event(event: MissionEvent) -> void:
	events.erase(event)
	stats.num_events -= 1
	stats.modified = Time.get_datetime_string_from_system()

func add_goal(goal: MissionGoal) -> void:
	match goal.type:
		MissionGoal.Type.PRIMARY:
			primary_goals.append(goal)
		MissionGoal.Type.SECONDARY:
			secondary_goals.append(goal)
		MissionGoal.Type.HIDDEN:
			hidden_goals.append(goal)
	
	stats.num_goals += 1
	stats.modified = Time.get_datetime_string_from_system()

func remove_goal(goal: MissionGoal) -> void:
	match goal.type:
		MissionGoal.Type.PRIMARY:
			primary_goals.erase(goal)
		MissionGoal.Type.SECONDARY:
			secondary_goals.erase(goal)
		MissionGoal.Type.HIDDEN:
			hidden_goals.erase(goal)
	
	stats.num_goals -= 1
	stats.modified = Time.get_datetime_string_from_system()

func set_variable(name: String, value) -> void:
	variables[name] = value
	stats.modified = Time.get_datetime_string_from_system()

func get_variable(name: String, default = null):
	return variables.get(name, default)

func save_fs2(path: String) -> Error:
	# TODO: Implement FS2 file format saving
	return OK

func load_fs2(path: String) -> Error:
	# TODO: Implement FS2 file format loading
	return OK

func validate() -> Array:
	var errors := []
	
	# Check mission metadata
	if title.is_empty():
		errors.append("Mission title is required")
	if designer.is_empty():
		errors.append("Mission designer is required")
	
	# Check mission objects
	for object in objects.values():
		var object_errors = object.validate()
		if !object_errors.is_empty():
			errors.append_array(object_errors)
	
	# Check events
	for event in events:
		var event_errors = event.validate()
		if !event_errors.is_empty():
			errors.append_array(event_errors)
	
	# Check goals
	if primary_goals.is_empty():
		errors.append("Mission must have at least one primary goal")
	
	for goal in primary_goals + secondary_goals + hidden_goals:
		var goal_errors = goal.validate()
		if !goal_errors.is_empty():
			errors.append_array(goal_errors)
	
	return errors
