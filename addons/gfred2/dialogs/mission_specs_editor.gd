@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

# Mission properties
var mission_title := "Untitled"
var designer := "Info"
var mission_type := MissionType.SINGLE_PLAYER
var mission_description := ""
var designer_notes := ""
var squadron_name := "<none>"
var squadron_logo := ""
var loading_screen_640 := ""
var loading_screen_1024 := ""
var max_respawns := 3
var music := ""

# Mission flags
var all_teams_at_war := false
var red_alert_mission := false
var scramble_mission := false
var no_briefing := false
var no_debriefing := false
var disallow_promotions := false
var disable_builtin_messages := false
var no_traitor := false
var warp_3d_effect := false
var all_ships_beam_free := false

# Support ship settings
var disallow_support_ships := false
var support_ships_repair_hull := false
var hull_repair_ceiling := 0.0
var subsystem_repair_ceiling := 100.0

# Ship trail settings
var display_trails_in_nebula := false
var min_speed_for_trails := 0.0
var min_speed_enabled := false

# UI Controls
var title_edit: LineEdit
var designer_edit: LineEdit
var type_buttons: Array[CheckBox]
var description_edit: TextEdit
var notes_edit: TextEdit
var squadron_name_edit: LineEdit
var squadron_logo_edit: LineEdit
var squadron_logo_btn: Button
var loading_screen_640_edit: LineEdit
var loading_screen_640_btn: Button
var loading_screen_1024_edit: LineEdit
var loading_screen_1024_btn: Button
var max_respawns_spin: SpinBox
var music_option: OptionButton

enum MissionType {
	SINGLE_PLAYER,
	MULTI_PLAYER,
	TRAINING,
	COOPERATIVE,
	TEAM_VS_TEAM,
	DOGFIGHT
}

func _ready():
	super._ready()
	title = "Mission Specs"
	
	var content = get_content_container()
	
	# Create main layout with spacing
	var scroll = ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(scroll)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(main_vbox)
	
	# Title and designer section
	var info_grid = GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 10)
	info_grid.add_theme_constant_override("v_separation", 10)
	main_vbox.add_child(info_grid)
	
	info_grid.add_child(_create_label("Title"))
	title_edit = LineEdit.new()
	title_edit.text = mission_title
	title_edit.text_submitted.connect(_on_title_changed)
	info_grid.add_child(title_edit)
	
	info_grid.add_child(_create_label("Designer"))
	designer_edit = LineEdit.new()
	designer_edit.text = designer
	designer_edit.text_submitted.connect(_on_designer_changed)
	info_grid.add_child(designer_edit)
	
	# Mission type selection
	var type_grid = GridContainer.new()
	type_grid.columns = 2
	type_grid.add_theme_constant_override("h_separation", 20)
	type_grid.add_theme_constant_override("v_separation", 5)
	main_vbox.add_child(type_grid)
	
	type_buttons = []
	for type in MissionType.values():
		var btn = CheckBox.new()
		btn.text = MissionType.keys()[type].capitalize().replace("_", " ")
		btn.button_group = ButtonGroup.new()
		btn.toggled.connect(_on_mission_type_changed.bind(type))
		type_grid.add_child(btn)
		type_buttons.append(btn)
	
	# Description and notes
	main_vbox.add_child(_create_label("Mission Description"))
	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 100
	description_edit.text = mission_description
	description_edit.text_changed.connect(_on_description_changed)
	main_vbox.add_child(description_edit)
	
	main_vbox.add_child(_create_label("Designer Notes"))
	notes_edit = TextEdit.new()
	notes_edit.custom_minimum_size.y = 100
	notes_edit.text = designer_notes
	notes_edit.text_changed.connect(_on_notes_changed)
	main_vbox.add_child(notes_edit)
	
	# Squadron settings
	var squadron_box = VBoxContainer.new()
	squadron_box.add_theme_constant_override("separation", 10)
	main_vbox.add_child(squadron_box)
	
	var squadron_frame = PanelContainer.new()
	squadron_box.add_child(squadron_frame)
	
	var squadron_vbox = VBoxContainer.new()
	squadron_vbox.add_theme_constant_override("separation", 10)
	squadron_frame.add_child(squadron_vbox)
	
	squadron_vbox.add_child(_create_label("Squadron Reassign"))
	
	var name_box = HBoxContainer.new()
	squadron_vbox.add_child(name_box)
	name_box.add_child(_create_label("Name"))
	squadron_name_edit = LineEdit.new()
	squadron_name_edit.text = squadron_name
	squadron_name_edit.text_submitted.connect(_on_squadron_name_changed)
	name_box.add_child(squadron_name_edit)
	
	var logo_box = HBoxContainer.new()
	squadron_vbox.add_child(logo_box)
	squadron_logo_btn = Button.new()
	squadron_logo_btn.text = "Logo"
	squadron_logo_btn.pressed.connect(_on_squadron_logo_pressed)
	logo_box.add_child(squadron_logo_btn)
	squadron_logo_edit = LineEdit.new()
	squadron_logo_edit.text = squadron_logo
	squadron_logo_edit.text_submitted.connect(_on_squadron_logo_changed)
	logo_box.add_child(squadron_logo_edit)
	
	# Loading screen settings
	var loading_box = VBoxContainer.new()
	loading_box.add_theme_constant_override("separation", 10)
	main_vbox.add_child(loading_box)
	
	var loading_frame = PanelContainer.new()
	loading_box.add_child(loading_frame)
	
	var loading_vbox = VBoxContainer.new()
	loading_vbox.add_theme_constant_override("separation", 10)
	loading_frame.add_child(loading_vbox)
	
	loading_vbox.add_child(_create_label("Loading Screen"))
	
	var screen_640_box = HBoxContainer.new()
	loading_vbox.add_child(screen_640_box)
	loading_screen_640_btn = Button.new()
	loading_screen_640_btn.text = "640x480"
	loading_screen_640_btn.pressed.connect(_on_loading_screen_640_pressed)
	screen_640_box.add_child(loading_screen_640_btn)
	loading_screen_640_edit = LineEdit.new()
	loading_screen_640_edit.text = loading_screen_640
	loading_screen_640_edit.text_submitted.connect(_on_loading_screen_640_changed)
	screen_640_box.add_child(loading_screen_640_edit)
	
	var screen_1024_box = HBoxContainer.new()
	loading_vbox.add_child(screen_1024_box)
	loading_screen_1024_btn = Button.new()
	loading_screen_1024_btn.text = "1024x768"
	loading_screen_1024_btn.pressed.connect(_on_loading_screen_1024_pressed)
	screen_1024_box.add_child(loading_screen_1024_btn)
	loading_screen_1024_edit = LineEdit.new()
	loading_screen_1024_edit.text = loading_screen_1024
	loading_screen_1024_edit.text_submitted.connect(_on_loading_screen_1024_changed)
	screen_1024_box.add_child(loading_screen_1024_edit)
	
	# Mission flags
	var flags_box = VBoxContainer.new()
	flags_box.add_theme_constant_override("separation", 5)
	main_vbox.add_child(flags_box)
	
	var flags_frame = PanelContainer.new()
	flags_box.add_child(flags_frame)
	
	var flags_vbox = VBoxContainer.new()
	flags_vbox.add_theme_constant_override("separation", 5)
	flags_frame.add_child(flags_vbox)
	
	flags_vbox.add_child(_create_checkbox("All Teams at War", all_teams_at_war, _on_all_teams_at_war_toggled))
	flags_vbox.add_child(_create_checkbox("Red Alert Mission", red_alert_mission, _on_red_alert_toggled))
	flags_vbox.add_child(_create_checkbox("Scramble Mission", scramble_mission, _on_scramble_toggled))
	flags_vbox.add_child(_create_checkbox("No Briefing", no_briefing, _on_no_briefing_toggled))
	flags_vbox.add_child(_create_checkbox("No Debriefing", no_debriefing, _on_no_debriefing_toggled))
	flags_vbox.add_child(_create_checkbox("Disallow Promotions/Badges", disallow_promotions, _on_disallow_promotions_toggled))
	flags_vbox.add_child(_create_checkbox("Disable Built-in Messages", disable_builtin_messages, _on_disable_messages_toggled))
	flags_vbox.add_child(_create_checkbox("No Traitor", no_traitor, _on_no_traitor_toggled))
	flags_vbox.add_child(_create_checkbox("3-D Warp Effect", warp_3d_effect, _on_warp_3d_toggled))
	flags_vbox.add_child(_create_checkbox("All Ships Beam-Freed By Default", all_ships_beam_free, _on_beam_free_toggled))
	
	# Support ship settings
	var support_box = VBoxContainer.new()
	support_box.add_theme_constant_override("separation", 10)
	main_vbox.add_child(support_box)
	
	var support_frame = PanelContainer.new()
	support_box.add_child(support_frame)
	
	var support_vbox = VBoxContainer.new()
	support_vbox.add_theme_constant_override("separation", 10)
	support_frame.add_child(support_vbox)
	
	support_vbox.add_child(_create_label("Support Ships"))
	
	support_vbox.add_child(_create_checkbox("Disallow Support Ships", disallow_support_ships, _on_disallow_support_toggled))
	support_vbox.add_child(_create_checkbox("Support Ships Repair Hull", support_ships_repair_hull, _on_repair_hull_toggled))
	
	var hull_box = HBoxContainer.new()
	support_vbox.add_child(hull_box)
	hull_box.add_child(_create_label("Hull Repair Ceiling"))
	var hull_edit = LineEdit.new()
	hull_edit.text = str(hull_repair_ceiling)
	hull_edit.text_submitted.connect(_on_hull_ceiling_changed)
	hull_box.add_child(hull_edit)
	hull_box.add_child(_create_label("%"))
	
	var subsys_box = HBoxContainer.new()
	support_vbox.add_child(subsys_box)
	subsys_box.add_child(_create_label("Subsystem Repair Ceiling"))
	var subsys_edit = LineEdit.new()
	subsys_edit.text = str(subsystem_repair_ceiling)
	subsys_edit.text_submitted.connect(_on_subsystem_ceiling_changed)
	subsys_box.add_child(subsys_edit)
	subsys_box.add_child(_create_label("%"))
	
	# Ship trails settings
	var trails_box = VBoxContainer.new()
	trails_box.add_theme_constant_override("separation", 10)
	main_vbox.add_child(trails_box)
	
	var trails_frame = PanelContainer.new()
	trails_box.add_child(trails_frame)
	
	var trails_vbox = VBoxContainer.new()
	trails_vbox.add_theme_constant_override("separation", 10)
	trails_frame.add_child(trails_vbox)
	
	trails_vbox.add_child(_create_label("Ship Trails"))
	
	trails_vbox.add_child(_create_checkbox("Display Regardless of Nebula", display_trails_in_nebula, _on_display_in_nebula_toggled))
	
	var speed_box = HBoxContainer.new()
	trails_vbox.add_child(speed_box)
	speed_box.add_child(_create_checkbox("Minimum Speed to Display", min_speed_enabled, _on_min_speed_enabled_toggled))
	var speed_edit = LineEdit.new()
	speed_edit.text = str(min_speed_for_trails)
	speed_edit.text_submitted.connect(_on_min_speed_changed)
	speed_box.add_child(speed_edit)
	
	# Music selection
	var music_box = HBoxContainer.new()
	main_vbox.add_child(music_box)
	
	music_box.add_child(_create_label("Music"))
	music_option = OptionButton.new()
	music_option.item_selected.connect(_on_music_selected)
	music_box.add_child(music_option)
	
	# Set initial state
	_update_ui()
	
	# Set dialog size
	size = Vector2(800, 600)
	show_dialog(Vector2(800, 600))

func _update_ui():
	title_edit.text = mission_title
	designer_edit.text = designer
	
	for i in range(type_buttons.size()):
		type_buttons[i].button_pressed = (i == mission_type)
	
	description_edit.text = mission_description
	notes_edit.text = designer_notes
	
	squadron_name_edit.text = squadron_name
	squadron_logo_edit.text = squadron_logo
	loading_screen_640_edit.text = loading_screen_640
	loading_screen_1024_edit.text = loading_screen_1024

func _create_checkbox(text: String, initial_state: bool, callback: Callable) -> CheckBox:
	var checkbox = CheckBox.new()
	checkbox.text = text
	checkbox.button_pressed = initial_state
	checkbox.toggled.connect(callback)
	return checkbox

func _on_title_changed(new_text: String):
	mission_title = new_text

func _on_designer_changed(new_text: String):
	designer = new_text

func _on_mission_type_changed(pressed: bool, type: MissionType):
	if pressed:
		mission_type = type

func _on_description_changed():
	mission_description = description_edit.text

func _on_notes_changed():
	designer_notes = notes_edit.text

func _on_squadron_name_changed(new_text: String):
	squadron_name = new_text

func _on_squadron_logo_changed(new_text: String):
	squadron_logo = new_text

func _on_squadron_logo_pressed():
	# TODO: Open file dialog
	pass

func _on_loading_screen_640_changed(new_text: String):
	loading_screen_640 = new_text

func _on_loading_screen_640_pressed():
	# TODO: Open file dialog
	pass

func _on_loading_screen_1024_changed(new_text: String):
	loading_screen_1024 = new_text

func _on_loading_screen_1024_pressed():
	# TODO: Open file dialog
	pass

func _on_all_teams_at_war_toggled(pressed: bool):
	all_teams_at_war = pressed

func _on_red_alert_toggled(pressed: bool):
	red_alert_mission = pressed

func _on_scramble_toggled(pressed: bool):
	scramble_mission = pressed

func _on_no_briefing_toggled(pressed: bool):
	no_briefing = pressed

func _on_no_debriefing_toggled(pressed: bool):
	no_debriefing = pressed

func _on_disallow_promotions_toggled(pressed: bool):
	disallow_promotions = pressed

func _on_disable_messages_toggled(pressed: bool):
	disable_builtin_messages = pressed

func _on_no_traitor_toggled(pressed: bool):
	no_traitor = pressed

func _on_warp_3d_toggled(pressed: bool):
	warp_3d_effect = pressed

func _on_beam_free_toggled(pressed: bool):
	all_ships_beam_free = pressed

func _on_disallow_support_toggled(pressed: bool):
	disallow_support_ships = pressed

func _on_repair_hull_toggled(pressed: bool):
	support_ships_repair_hull = pressed

func _on_hull_ceiling_changed(new_text: String):
	hull_repair_ceiling = float(new_text)

func _on_subsystem_ceiling_changed(new_text: String):
	subsystem_repair_ceiling = float(new_text)

func _on_display_in_nebula_toggled(pressed: bool):
	display_trails_in_nebula = pressed

func _on_min_speed_enabled_toggled(pressed: bool):
	min_speed_enabled = pressed

func _on_min_speed_changed(new_text: String):
	min_speed_for_trails = float(new_text)

func _on_music_selected(index: int):
	# TODO: Set music based on selected item
	pass
