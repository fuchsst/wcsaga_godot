extends Node2D

# Constants
const MAX_PILOTS = 20  # From original WC Saga
const VALID_PILOT_CHARS = " _-"  # Valid special characters for pilot names

# UI References
@onready var pilot_list: ItemList = $PilotListContainer/ItemList
@onready var pilot_list_label: Label = $PilotListContainer/PilotListLabel
@onready var bottom_text: Label = $BottomText
@onready var pilot_input_box: LineEdit = $PilotInputBox

# Current pilot selection
var selected_pilot_index: int = -1

func _ready() -> void:	
	# Load and display pilot list
	refresh_pilot_list()
	
	# Try to load last pilot
	if GameState.try_load_last_pilot():
		# Find and select last pilot in list
		for i in range(pilot_list.item_count):
			if pilot_list.get_item_text(i) == GameState.settings.last_pilot_callsign:
				selected_pilot_index = i
				pilot_list.select(i)
				
				# Set mode indicator
				if GameState.active_pilot.flags & PilotData.PilotFlags.IS_MULTI:
					set_bottom_text("Multiplayer Mode")
				else:
					set_bottom_text("Single Player Mode")
				break
	
	# If no pilots exist, automatically start pilot creation
	if pilot_list.item_count == 0:
		set_input_mode(true)
		set_bottom_text("Type Callsign and Press Enter")

func refresh_pilot_list() -> void:
	pilot_list.clear()
	
	var pilots = GameState.get_all_pilots()
	for pilot_name in pilots:
		pilot_list.add_item(pilot_name)
	
	if pilot_list.item_count > 0 and selected_pilot_index == -1:
		selected_pilot_index = 0
		pilot_list.select(selected_pilot_index)
		GameState.load_pilot(pilot_list.get_item_text(selected_pilot_index))

# Input mode handling
var input_mode: bool = false
var is_cloning: bool = false

func set_input_mode(enabled: bool) -> void:
	input_mode = enabled
	
	# Enable/disable buttons based on mode
	for button in [$LeftButtons/CreatePilotButton, $LeftButtons/ClonePilotButton, 
				   $LeftButtons/RemovePilotButton, $RightButtons/UpButton,
				   $RightButtons/DownButton, $RightButtons/SelectButton,
				   $TopRightButtons/SinglePlayer, $TopRightButtons/Multiplayer]:
		button.disabled = enabled
	
	if enabled:
		pilot_input_box.visible = true
		pilot_input_box.grab_focus()		
	else:
		pilot_input_box.visible = false

func set_bottom_text(text: String) -> void:
	bottom_text.text = text

func validate_pilot_name(name: String) -> bool:
	if name.is_empty():
		return false
		
	# First character must be a letter
	if not name[0].is_valid_identifier():
		return false
		
	# Check remaining characters
	for c in name:
		if not (c.is_valid_identifier() or c in VALID_PILOT_CHARS):
			return false
	
	return true

func _on_pilot_input_box_text_submitted(new_text: String) -> void:
	var new_name = new_text.strip_edges()
	
	if not validate_pilot_name(new_name):
		set_bottom_text("Invalid pilot name! Must start with a letter.")
		return
	
	# Check for duplicate names
	if GameState.load_pilot(new_name):
		set_bottom_text("A pilot with that name already exists!")
		return
	
	# Create or clone pilot
	var pilot: PilotData
	if is_cloning and GameState.active_pilot:
		pilot = PilotData.clone_from(GameState.active_pilot, new_name)
	else:
		pilot = PilotData.create(new_name)
	
	# Set as active pilot and save
	GameState.active_pilot = pilot
	if GameState.save_active_pilot():
		set_input_mode(false)
		refresh_pilot_list()
		
		# Select the new pilot
		for i in range(pilot_list.item_count):
			if pilot_list.get_item_text(i) == new_name:
				selected_pilot_index = i
				pilot_list.select(i)
				break
		
		set_bottom_text("")
		pilot_input_box.clear()
	else:
		set_bottom_text("Error creating pilot file!")

func _on_single_player_pressed() -> void:
	if GameState.active_pilot:
		GameState.active_pilot.flags &= ~PilotData.PilotFlags.IS_MULTI
		GameState.save_active_pilot()
		set_bottom_text("Single Player Mode")

func _on_multiplayer_pressed() -> void:
	if GameState.active_pilot:
		GameState.active_pilot.flags |= PilotData.PilotFlags.IS_MULTI
		GameState.save_active_pilot()
		set_bottom_text("Multiplayer Mode")

func _on_create_pilot_button_pressed() -> void:
	if pilot_list.item_count >= MAX_PILOTS:
		set_bottom_text("Maximum number of pilots reached!")
		return
	
	is_cloning = false
	set_input_mode(true)
	set_bottom_text("Type Callsign and Press Enter")

func _on_clone_pilot_button_pressed() -> void:
	if GameState.active_pilot == null:
		return
		
	if pilot_list.item_count >= MAX_PILOTS:
		set_bottom_text("Maximum number of pilots reached!")
		return
	
	is_cloning = true
	set_input_mode(true)
	set_bottom_text("Type Callsign and Press Enter")

func _on_remove_pilot_button_pressed() -> void:
	if GameState.active_pilot == null:
		return
		
	# Show confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Are you sure you want to delete pilot '%s'?" % GameState.active_pilot.callsign
	dialog.confirmed.connect(func():
		if GameState.delete_pilot(GameState.active_pilot.callsign):
			selected_pilot_index = -1
			refresh_pilot_list()
			set_bottom_text("")
	)
	add_child(dialog)
	dialog.popup_centered()

func _on_up_button_pressed() -> void:
	if selected_pilot_index > 0:
		selected_pilot_index -= 1
		pilot_list.select(selected_pilot_index)
		GameState.load_pilot(pilot_list.get_item_text(selected_pilot_index))
		set_bottom_text("")

func _on_down_button_pressed() -> void:
	if selected_pilot_index < pilot_list.item_count - 1:
		selected_pilot_index += 1
		pilot_list.select(selected_pilot_index)
		GameState.load_pilot(pilot_list.get_item_text(selected_pilot_index))
		set_bottom_text("")

func _on_select_button_pressed() -> void:
	if GameState.active_pilot == null:
		return
		
	# Update multiplayer state and save settings
	GameState.is_multiplayer = (GameState.active_pilot.flags & PilotData.PilotFlags.IS_MULTI) != 0
	GameState.save_active_pilot()
		
	SceneManager.change_scene("main_hall", 
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_general_options(Color.BLACK))

func _input(event: InputEvent) -> void:
	if input_mode and event.is_action_pressed("ui_cancel"):
		set_input_mode(false)
		set_bottom_text("")
