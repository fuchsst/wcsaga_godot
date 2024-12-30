@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

# Mission data reference
var mission_data: MissionData

# Currently selected message
var current_message: MissionMessage

func _ready():
	super._ready()
	
	# Get node references
	var priority = %Priority
	var team = %Team
	var persona = %Persona
	
	# Setup priority options
	priority.clear()
	priority.add_item("Low", 0)
	priority.add_item("Normal", 1)
	priority.add_item("High", 2)
	
	# Setup team options
	team.clear()
	team.add_item("Friendly", 0)
	team.add_item("Hostile", 1)
	team.add_item("Neutral", 2)
	team.add_item("Unknown", 3)
	
	# Setup persona options
	persona.clear()
	persona.add_item("<None>", -1)
	# TODO: Add personas from mission data
	
	# Connect signals
	%MessageList.item_selected.connect(_on_message_selected)
	%MessageName.text_changed.connect(_on_message_name_changed)
	%MessageText.text_changed.connect(_on_message_text_changed)
	%Priority.item_selected.connect(_on_priority_changed)
	%Team.item_selected.connect(_on_team_changed)
	%Persona.item_selected.connect(_on_persona_changed)
	%TeamSpecific.toggled.connect(_on_team_specific_toggled)
	%NoMusic.toggled.connect(_on_no_music_toggled)
	%NoSpecialMusic.toggled.connect(_on_no_special_music_toggled)
	%BrowseWave.pressed.connect(_on_browse_wave_pressed)
	%BrowseAni.pressed.connect(_on_browse_ani_pressed)

func show_dialog_with_mission(mission: MissionData):
	mission_data = mission
	
	# Clear and populate message list
	%MessageList.clear()
	
	for message in mission_data.messages:
		%MessageList.add_item(message.name)
	
	# Select first message if any exist
	if %MessageList.item_count > 0:
		%MessageList.select(0)
		_on_message_selected(0)
	else:
		_clear_message_properties()
		
	show_dialog()

func _clear_message_properties():
	current_message = null
	%MessageName.text = ""
	%MessageText.text = ""
	%Priority.selected = 1  # Normal
	%Team.selected = 0  # Friendly
	%Persona.selected = 0  # None
	%WaveFile.text = ""
	%AniFile.text = ""
	%TeamSpecific.button_pressed = false
	%NoMusic.button_pressed = false
	%NoSpecialMusic.button_pressed = false
	
	# Disable property controls
	%MessageName.editable = false
	%MessageText.editable = false
	%Priority.disabled = true
	%Team.disabled = true
	%Persona.disabled = true
	%BrowseWave.disabled = true
	%BrowseAni.disabled = true
	%TeamSpecific.disabled = true
	%NoMusic.disabled = true
	%NoSpecialMusic.disabled = true

func _update_message_properties():
	if !current_message:
		_clear_message_properties()
		return
		
	# Enable property controls
	%MessageName.editable = true
	%MessageText.editable = true
	%Priority.disabled = false
	%Team.disabled = false
	%Persona.disabled = false
	%BrowseWave.disabled = false
	%BrowseAni.disabled = false
	%TeamSpecific.disabled = false
	%NoMusic.disabled = false
	%NoSpecialMusic.disabled = false
	
	# Update values
	%MessageName.text = current_message.name
	%MessageText.text = current_message.text
	%Priority.selected = current_message.priority
	%Team.selected = current_message.team
	%Persona.selected = current_message.persona_index + 1  # Account for <None> at index 0
	%WaveFile.text = current_message.wave_file
	%AniFile.text = current_message.ani_file
	%TeamSpecific.button_pressed = current_message.team_specific
	%NoMusic.button_pressed = current_message.no_music
	%NoSpecialMusic.button_pressed = current_message.no_special_music

func _on_message_selected(index: int):
	# Find selected message
	var message_name = %MessageList.get_item_text(index)
	
	for message in mission_data.messages:
		if message.name == message_name:
			current_message = message
			break
	
	_update_message_properties()

func _on_add_message_pressed():
	# Create new message
	var message = MissionMessage.new()
	message.name = "New Message"
	message.text = "Enter message text here"
	message.priority = 1  # Normal
	
	# Add to mission
	mission_data.add_message(message)
	
	# Add to list and select
	%MessageList.add_item(message.name)
	%MessageList.select(%MessageList.item_count - 1)
	_on_message_selected(%MessageList.item_count - 1)

func _on_delete_message_pressed():
	if !current_message:
		return
		
	# Remove from mission
	mission_data.remove_message(current_message)
	
	# Remove from list
	var selected = %MessageList.get_selected_items()[0]
	%MessageList.remove_item(selected)
	
	# Select next item if any
	if %MessageList.item_count > 0:
		var next_index = min(selected, %MessageList.item_count - 1)
		%MessageList.select(next_index)
		_on_message_selected(next_index)
	else:
		_clear_message_properties()

func _on_message_name_changed(new_text: String):
	if !current_message:
		return
		
	current_message.name = new_text
	
	# Update list item
	var selected = %MessageList.get_selected_items()[0]
	%MessageList.set_item_text(selected, new_text)

func _on_message_text_changed():
	if !current_message:
		return
		
	current_message.text = %MessageText.text

func _on_priority_changed(index: int):
	if !current_message:
		return
		
	current_message.priority = index

func _on_team_changed(index: int):
	if !current_message:
		return
		
	current_message.team = index

func _on_persona_changed(index: int):
	if !current_message:
		return
		
	current_message.persona_index = index - 1  # Account for <None> at index 0

func _on_team_specific_toggled(button_pressed: bool):
	if !current_message:
		return
		
	current_message.team_specific = button_pressed

func _on_no_music_toggled(button_pressed: bool):
	if !current_message:
		return
		
	current_message.no_music = button_pressed

func _on_no_special_music_toggled(button_pressed: bool):
	if !current_message:
		return
		
	current_message.no_special_music = button_pressed

func _on_browse_wave_pressed():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.wav,*.ogg ; Audio Files"]
	dialog.file_selected.connect(func(path): 
		current_message.wave_file = path
		%WaveFile.text = path
	)
	add_child(dialog)
	dialog.popup_centered(Vector2(800, 600))

func _on_browse_ani_pressed():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.ani ; Animation Files"]
	dialog.file_selected.connect(func(path):
		current_message.ani_file = path
		%AniFile.text = path
	)
	add_child(dialog)
	dialog.popup_centered(Vector2(800, 600))

func _on_ok_pressed():
	# Validate messages
	var errors = []
	
	for message in mission_data.messages:
		var message_errors = message.validate()
		if !message_errors.is_empty():
			errors.append_array(message_errors)
	
	if !errors.is_empty():
		# Show error dialog
		var error_text = "The following errors were found:\n\n"
		for error in errors:
			error_text += "- " + error + "\n"
		
		var dialog = AcceptDialog.new()
		dialog.dialog_text = error_text
		add_child(dialog)
		dialog.popup_centered()
		await dialog.confirmed
		dialog.queue_free()
		return
	
	super._on_ok_pressed()

func _on_cancel_pressed():
	super._on_cancel_pressed()
