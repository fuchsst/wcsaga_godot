@tool
extends Node

# Dialog references
var mission_specs_dialog: Window
var asteroid_field_editor_dialog: Window
var ship_editor_dialog: Window
var wing_editor_dialog: Window
var event_editor_dialog: Window
var message_editor_dialog: Window
var briefing_editor_dialog: Window
var debriefing_editor_dialog: Window
var background_editor_dialog: Window

# Mission data reference
var mission_data: MissionData

func _ready():
	# Create dialog instances
	mission_specs_dialog = preload("res://addons/gfred2/dialogs/mission_specs_editor.gd").new()
	asteroid_field_editor_dialog = preload("res://addons/gfred2/dialogs/asteroid_field_editor.gd").new()
	
	# Add dialogs to scene
	add_child(mission_specs_dialog)
	add_child(asteroid_field_editor_dialog)
	
	# Connect dialog signals
	_connect_dialog_signals()

func _connect_dialog_signals():
	# Mission Specs dialog
	mission_specs_dialog.confirmed.connect(_on_mission_specs_confirmed)
	mission_specs_dialog.canceled.connect(_on_mission_specs_canceled)
	
	# Asteroid Field dialog
	asteroid_field_editor_dialog.confirmed.connect(_on_asteroid_field_confirmed)
	asteroid_field_editor_dialog.canceled.connect(_on_asteroid_field_canceled)

func set_mission_data(data: MissionData):
	mission_data = data
	_update_dialog_data()

func _update_dialog_data():
	if !mission_data:
		return
		
	# Update Mission Specs dialog
	if mission_specs_dialog:
		mission_specs_dialog.title = mission_data.title
		mission_specs_dialog.designer = mission_data.designer
		mission_specs_dialog.description = mission_data.description
		mission_specs_dialog.designer_notes = mission_data.designer_notes
		mission_specs_dialog.mission_type = mission_data.mission_type
		mission_specs_dialog.all_teams_at_war = mission_data.all_teams_at_war
		mission_specs_dialog.red_alert = mission_data.red_alert
		mission_specs_dialog.scramble = mission_data.scramble
		mission_specs_dialog.no_briefing = mission_data.no_briefing
		mission_specs_dialog.no_debriefing = mission_data.no_debriefing
		mission_specs_dialog.disable_builtin_messages = mission_data.disable_builtin_messages
		mission_specs_dialog.no_traitor = mission_data.no_traitor
		mission_specs_dialog.is_training = mission_data.is_training
		mission_specs_dialog.disallow_support_ships = mission_data.disallow_support_ships
		mission_specs_dialog.support_ships_repair_hull = mission_data.support_ships_repair_hull
		mission_specs_dialog.hull_repair_ceiling = mission_data.hull_repair_ceiling
		mission_specs_dialog.subsystem_repair_ceiling = mission_data.subsystem_repair_ceiling
		mission_specs_dialog.loading_screen_640 = mission_data.loading_screen_640
		mission_specs_dialog.loading_screen_1024 = mission_data.loading_screen_1024
		mission_specs_dialog.squadron_name = mission_data.squadron_name
		mission_specs_dialog.squadron_logo = mission_data.squadron_logo
	
	# Update Asteroid Field dialog
	if asteroid_field_editor_dialog:
		asteroid_field_editor_dialog.enabled = mission_data.asteroid_field != null
		if mission_data.asteroid_field:
			asteroid_field_editor_dialog.is_active_field = mission_data.asteroid_field.is_active
			asteroid_field_editor_dialog.is_asteroid = mission_data.asteroid_field.is_asteroid_field
			asteroid_field_editor_dialog.field_colors = mission_data.asteroid_field.colors
			asteroid_field_editor_dialog.ship_types = mission_data.asteroid_field.ship_types
			asteroid_field_editor_dialog.number = mission_data.asteroid_field.num_asteroids
			asteroid_field_editor_dialog.avg_speed = mission_data.asteroid_field.avg_speed
			asteroid_field_editor_dialog.outer_box = mission_data.asteroid_field.outer_box
			asteroid_field_editor_dialog.inner_box = mission_data.asteroid_field.inner_box

func show_dialog(dialog_type: String):
	match dialog_type:
		"mission_specs":
			mission_specs_dialog.show_dialog()
		"ship_editor":
			if ship_editor_dialog:
				ship_editor_dialog.show_dialog()
		"wing_editor":
			if wing_editor_dialog:
				wing_editor_dialog.show_dialog()
		"event_editor":
			if event_editor_dialog:
				event_editor_dialog.show_dialog()
		"message_editor":
			if message_editor_dialog:
				message_editor_dialog.show_dialog()
		"briefing_editor":
			if briefing_editor_dialog:
				briefing_editor_dialog.show_dialog()
		"debriefing_editor":
			if debriefing_editor_dialog:
				debriefing_editor_dialog.show_dialog()
		"background_editor":
			if background_editor_dialog:
				background_editor_dialog.show_dialog()
		"asteroid_field":
			asteroid_field_editor_dialog.show_dialog()

func _on_mission_specs_confirmed():
	if !mission_data:
		return
		
	# Update mission data from dialog
	mission_data.title = mission_specs_dialog.title
	mission_data.designer = mission_specs_dialog.designer
	mission_data.description = mission_specs_dialog.description
	mission_data.designer_notes = mission_specs_dialog.designer_notes
	mission_data.mission_type = mission_specs_dialog.mission_type
	mission_data.all_teams_at_war = mission_specs_dialog.all_teams_at_war
	mission_data.red_alert = mission_specs_dialog.red_alert
	mission_data.scramble = mission_specs_dialog.scramble
	mission_data.no_briefing = mission_specs_dialog.no_briefing
	mission_data.no_debriefing = mission_specs_dialog.no_debriefing
	mission_data.disable_builtin_messages = mission_specs_dialog.disable_builtin_messages
	mission_data.no_traitor = mission_specs_dialog.no_traitor
	mission_data.is_training = mission_specs_dialog.is_training
	mission_data.disallow_support_ships = mission_specs_dialog.disallow_support_ships
	mission_data.support_ships_repair_hull = mission_specs_dialog.support_ships_repair_hull
	mission_data.hull_repair_ceiling = mission_specs_dialog.hull_repair_ceiling
	mission_data.subsystem_repair_ceiling = mission_specs_dialog.subsystem_repair_ceiling
	mission_data.loading_screen_640 = mission_specs_dialog.loading_screen_640
	mission_data.loading_screen_1024 = mission_specs_dialog.loading_screen_1024
	mission_data.squadron_name = mission_specs_dialog.squadron_name
	mission_data.squadron_logo = mission_specs_dialog.squadron_logo

func _on_mission_specs_canceled():
	# Revert dialog data back to mission data
	if mission_data:
		mission_specs_dialog.title = mission_data.title
		mission_specs_dialog.designer = mission_data.designer
		mission_specs_dialog.description = mission_data.description
		mission_specs_dialog.designer_notes = mission_data.designer_notes
		mission_specs_dialog.mission_type = mission_data.mission_type
		mission_specs_dialog.all_teams_at_war = mission_data.all_teams_at_war
		mission_specs_dialog.red_alert = mission_data.red_alert
		mission_specs_dialog.scramble = mission_data.scramble
		mission_specs_dialog.no_briefing = mission_data.no_briefing
		mission_specs_dialog.no_debriefing = mission_data.no_debriefing
		mission_specs_dialog.disable_builtin_messages = mission_data.disable_builtin_messages
		mission_specs_dialog.no_traitor = mission_data.no_traitor
		mission_specs_dialog.is_training = mission_data.is_training
		mission_specs_dialog.disallow_support_ships = mission_data.disallow_support_ships
		mission_specs_dialog.support_ships_repair_hull = mission_data.support_ships_repair_hull
		mission_specs_dialog.hull_repair_ceiling = mission_data.hull_repair_ceiling
		mission_specs_dialog.subsystem_repair_ceiling = mission_data.subsystem_repair_ceiling
		mission_specs_dialog.loading_screen_640 = mission_data.loading_screen_640
		mission_specs_dialog.loading_screen_1024 = mission_data.loading_screen_1024
		mission_specs_dialog.squadron_name = mission_data.squadron_name
		mission_specs_dialog.squadron_logo = mission_data.squadron_logo

func _on_asteroid_field_confirmed():
	if !mission_data:
		return
		
	# Update asteroid field data from dialog
	if asteroid_field_editor_dialog.enabled:
		if !mission_data.asteroid_field:
			mission_data.asteroid_field = {}
			
		mission_data.asteroid_field.is_active = asteroid_field_editor_dialog.is_active_field
		mission_data.asteroid_field.is_asteroid_field = asteroid_field_editor_dialog.is_asteroid
		mission_data.asteroid_field.colors = asteroid_field_editor_dialog.field_colors
		mission_data.asteroid_field.ship_types = asteroid_field_editor_dialog.ship_types
		mission_data.asteroid_field.num_asteroids = asteroid_field_editor_dialog.number
		mission_data.asteroid_field.avg_speed = asteroid_field_editor_dialog.avg_speed
		mission_data.asteroid_field.outer_box = asteroid_field_editor_dialog.outer_box
		mission_data.asteroid_field.inner_box = asteroid_field_editor_dialog.inner_box
	else:
		mission_data.asteroid_field = null

func _on_asteroid_field_canceled():
	# Revert dialog data back to mission data
	if mission_data:
		asteroid_field_editor_dialog.enabled = mission_data.asteroid_field != null
		if mission_data.asteroid_field:
			asteroid_field_editor_dialog.is_active_field = mission_data.asteroid_field.is_active
			asteroid_field_editor_dialog.is_asteroid = mission_data.asteroid_field.is_asteroid_field
			asteroid_field_editor_dialog.field_colors = mission_data.asteroid_field.colors
			asteroid_field_editor_dialog.ship_types = mission_data.asteroid_field.ship_types
			asteroid_field_editor_dialog.number = mission_data.asteroid_field.num_asteroids
			asteroid_field_editor_dialog.avg_speed = mission_data.asteroid_field.avg_speed
			asteroid_field_editor_dialog.outer_box = mission_data.asteroid_field.outer_box
			asteroid_field_editor_dialog.inner_box = mission_data.asteroid_field.inner_box

func create_dialog(dialog_class: GDScript) -> Window:
	var dialog = dialog_class.new()
	add_child(dialog)
	return dialog

func destroy_dialog(dialog: Window):
	if dialog:
		dialog.queue_free()
