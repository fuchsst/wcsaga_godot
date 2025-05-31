@tool
class_name MissionMessagesEditorPanel
extends Control

## In-mission message system editor for GFRED2-010 Mission Component Editors.
## Scene-based UI controller for configuring mission messages with timing and triggers.
## Scene: addons/gfred2/scenes/dialogs/component_editors/mission_messages_editor_panel.tscn

signal message_updated(message_data: MissionMessage)
signal validation_changed(is_valid: bool, errors: Array[String])
signal message_selected(message_id: String)

# Current mission and messages data
var current_mission_data: MissionData = null
var message_list: Array[MissionMessage] = []

# Scene node references
@onready var messages_tree: Tree = $VBoxContainer/MessagesList/MessagesTree
@onready var add_message_button: Button = $VBoxContainer/MessagesList/ButtonContainer/AddButton
@onready var remove_message_button: Button = $VBoxContainer/MessagesList/ButtonContainer/RemoveButton
@onready var duplicate_message_button: Button = $VBoxContainer/MessagesList/ButtonContainer/DuplicateButton
@onready var play_message_button: Button = $VBoxContainer/MessagesList/ButtonContainer/PlayButton

@onready var properties_container: VBoxContainer = $VBoxContainer/PropertiesContainer
@onready var message_name_edit: LineEdit = $VBoxContainer/PropertiesContainer/NameContainer/NameEdit
@onready var message_text_edit: TextEdit = $VBoxContainer/PropertiesContainer/TextContainer/MessageTextEdit
@onready var sender_name_edit: LineEdit = $VBoxContainer/PropertiesContainer/SenderContainer/SenderNameEdit
@onready var sender_type_option: OptionButton = $VBoxContainer/PropertiesContainer/SenderContainer/SenderTypeOption

@onready var timing_container: VBoxContainer = $VBoxContainer/PropertiesContainer/TimingContainer
@onready var trigger_condition_edit: SexpPropertyEditor = $VBoxContainer/PropertiesContainer/TimingContainer/TriggerConditionEdit
@onready var delay_spin: SpinBox = $VBoxContainer/PropertiesContainer/TimingContainer/DelaySpin
@onready var duration_spin: SpinBox = $VBoxContainer/PropertiesContainer/TimingContainer/DurationSpin
@onready var priority_spin: SpinBox = $VBoxContainer/PropertiesContainer/TimingContainer/PrioritySpin

@onready var voice_container: VBoxContainer = $VBoxContainer/PropertiesContainer/VoiceContainer
@onready var voice_file_edit: LineEdit = $VBoxContainer/PropertiesContainer/VoiceContainer/VoiceFileEdit
@onready var browse_voice_button: Button = $VBoxContainer/PropertiesContainer/VoiceContainer/BrowseVoiceButton
@onready var voice_volume_spin: SpinBox = $VBoxContainer/PropertiesContainer/VoiceContainer/VoiceVolumeSpin

@onready var flags_container: VBoxContainer = $VBoxContainer/PropertiesContainer/FlagsContainer
@onready var builtin_message_check: CheckBox = $VBoxContainer/PropertiesContainer/FlagsContainer/BuiltinMessageCheck
@onready var critical_message_check: CheckBox = $VBoxContainer/PropertiesContainer/FlagsContainer/CriticalMessageCheck
@onready var no_log_check: CheckBox = $VBoxContainer/PropertiesContainer/FlagsContainer/NoLogCheck

# File dialog for voice selection
@onready var voice_file_dialog: FileDialog = $VoiceFileDialog

# Current selected message
var selected_message: MissionMessage = null

# Message sender types
var sender_types: Array[Dictionary] = [
	{"name": "Command", "value": "command"},
	{"name": "Ship", "value": "ship"},
	{"name": "Wing", "value": "wing"},
	{"name": "Base", "value": "base"},
	{"name": "Narrator", "value": "narrator"},
	{"name": "Wingman", "value": "wingman"}
]

func _ready() -> void:
	name = "MissionMessagesEditorPanel"
	
	# Setup UI components
	_setup_messages_tree()
	_setup_sender_type_options()
	_setup_property_editors()
	_setup_voice_file_dialog()
	_connect_signals()
	
	# Initialize empty state
	_update_properties_display()
	
	print("MissionMessagesEditorPanel: Mission messages editor initialized")

## Initializes the editor with mission data
func initialize_with_mission(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	current_mission_data = mission_data
	
	# Load existing messages from mission data
	if mission_data.has_method("get_messages"):
		message_list = mission_data.get_messages()
	else:
		message_list = []
	
	# Populate messages tree
	_populate_messages_tree()
	
	print("MissionMessagesEditorPanel: Initialized with %d messages" % message_list.size())

## Sets up the messages tree
func _setup_messages_tree() -> void:
	if not messages_tree:
		return
	
	messages_tree.columns = 4
	messages_tree.set_column_title(0, "Name")
	messages_tree.set_column_title(1, "Sender")
	messages_tree.set_column_title(2, "Priority")
	messages_tree.set_column_title(3, "Voice")
	
	messages_tree.set_column_expand(0, true)
	messages_tree.set_column_expand(1, false)
	messages_tree.set_column_expand(2, false)
	messages_tree.set_column_expand(3, false)
	
	messages_tree.item_selected.connect(_on_message_selected)

func _setup_sender_type_options() -> void:
	if not sender_type_option:
		return
	
	sender_type_option.clear()
	for sender_type in sender_types:
		sender_type_option.add_item(sender_type["name"])
	
	sender_type_option.item_selected.connect(_on_sender_type_selected)

func _setup_property_editors() -> void:
	# Setup text inputs
	if message_name_edit:
		message_name_edit.text_changed.connect(_on_name_changed)
	
	if message_text_edit:
		message_text_edit.text_changed.connect(_on_message_text_changed)
	
	if sender_name_edit:
		sender_name_edit.text_changed.connect(_on_sender_name_changed)
	
	if voice_file_edit:
		voice_file_edit.text_changed.connect(_on_voice_file_changed)
	
	# Setup numeric inputs
	if delay_spin:
		delay_spin.min_value = 0.0
		delay_spin.max_value = 3600.0  # 1 hour max
		delay_spin.step = 0.1
		delay_spin.suffix = "s"
		delay_spin.value_changed.connect(_on_delay_changed)
	
	if duration_spin:
		duration_spin.min_value = 0.0
		duration_spin.max_value = 300.0  # 5 minutes max
		duration_spin.step = 0.1
		duration_spin.suffix = "s"
		duration_spin.value_changed.connect(_on_duration_changed)
	
	if priority_spin:
		priority_spin.min_value = 1
		priority_spin.max_value = 100
		priority_spin.value_changed.connect(_on_priority_changed)
	
	if voice_volume_spin:
		voice_volume_spin.min_value = 0.0
		voice_volume_spin.max_value = 1.0
		voice_volume_spin.step = 0.1
		voice_volume_spin.value_changed.connect(_on_voice_volume_changed)
	
	# Setup checkboxes
	if builtin_message_check:
		builtin_message_check.toggled.connect(_on_builtin_message_toggled)
	
	if critical_message_check:
		critical_message_check.toggled.connect(_on_critical_message_toggled)
	
	if no_log_check:
		no_log_check.toggled.connect(_on_no_log_toggled)
	
	# Setup SEXP editor
	if trigger_condition_edit:
		trigger_condition_edit.sexp_changed.connect(_on_trigger_condition_changed)

func _setup_voice_file_dialog() -> void:
	if not voice_file_dialog:
		return
	
	voice_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	voice_file_dialog.access = FileDialog.ACCESS_RESOURCES
	voice_file_dialog.add_filter("*.wav", "WAV Audio Files")
	voice_file_dialog.add_filter("*.ogg", "OGG Audio Files")
	voice_file_dialog.add_filter("*.mp3", "MP3 Audio Files")
	voice_file_dialog.file_selected.connect(_on_voice_file_selected)

func _connect_signals() -> void:
	if add_message_button:
		add_message_button.pressed.connect(_on_add_message_pressed)
	
	if remove_message_button:
		remove_message_button.pressed.connect(_on_remove_message_pressed)
	
	if duplicate_message_button:
		duplicate_message_button.pressed.connect(_on_duplicate_message_pressed)
	
	if play_message_button:
		play_message_button.pressed.connect(_on_play_message_pressed)
	
	if browse_voice_button:
		browse_voice_button.pressed.connect(_on_browse_voice_pressed)

## Populates the messages tree with current data
func _populate_messages_tree() -> void:
	if not messages_tree:
		return
	
	messages_tree.clear()
	var root: TreeItem = messages_tree.create_item()
	
	for i in range(message_list.size()):
		var message: MissionMessage = message_list[i]
		var item: TreeItem = messages_tree.create_item(root)
		
		item.set_text(0, message.message_name)
		item.set_text(1, message.sender_name if not message.sender_name.is_empty() else message.sender_type.capitalize())
		item.set_text(2, str(message.priority))
		item.set_text(3, "Yes" if not message.voice_file.is_empty() else "No")
		item.set_metadata(0, i)  # Store index for selection

func _update_properties_display() -> void:
	var has_selection: bool = selected_message != null
	
	# Enable/disable property controls
	properties_container.modulate = Color.WHITE if has_selection else Color(0.5, 0.5, 0.5)
	
	if not has_selection:
		# Clear all inputs when no selection
		if message_name_edit:
			message_name_edit.text = ""
		if message_text_edit:
			message_text_edit.text = ""
		if sender_name_edit:
			sender_name_edit.text = ""
		if sender_type_option:
			sender_type_option.selected = -1
		if delay_spin:
			delay_spin.value = 0.0
		if duration_spin:
			duration_spin.value = 0.0
		if priority_spin:
			priority_spin.value = 50
		if voice_file_edit:
			voice_file_edit.text = ""
		if voice_volume_spin:
			voice_volume_spin.value = 1.0
		if builtin_message_check:
			builtin_message_check.button_pressed = false
		if critical_message_check:
			critical_message_check.button_pressed = false
		if no_log_check:
			no_log_check.button_pressed = false
		return
	
	# Update inputs with selected message data
	if message_name_edit:
		message_name_edit.text = selected_message.message_name
	
	if message_text_edit:
		message_text_edit.text = selected_message.message_text
	
	if sender_name_edit:
		sender_name_edit.text = selected_message.sender_name
	
	if sender_type_option:
		# Find and select the appropriate sender type
		for i in range(sender_types.size()):
			if sender_types[i]["value"] == selected_message.sender_type:
				sender_type_option.selected = i
				break
	
	if delay_spin:
		delay_spin.value = selected_message.delay
	
	if duration_spin:
		duration_spin.value = selected_message.duration
	
	if priority_spin:
		priority_spin.value = selected_message.priority
	
	if voice_file_edit:
		voice_file_edit.text = selected_message.voice_file
	
	if voice_volume_spin:
		voice_volume_spin.value = selected_message.voice_volume
	
	if builtin_message_check:
		builtin_message_check.button_pressed = selected_message.builtin_message
	
	if critical_message_check:
		critical_message_check.button_pressed = selected_message.critical_message
	
	if no_log_check:
		no_log_check.button_pressed = selected_message.no_log
	
	if trigger_condition_edit and selected_message.trigger_condition:
		trigger_condition_edit.set_sexp_node(selected_message.trigger_condition)

## Signal handlers

func _on_message_selected() -> void:
	var selected_item: TreeItem = messages_tree.get_selected()
	if not selected_item:
		selected_message = null
		_update_properties_display()
		return
	
	var message_index: int = selected_item.get_metadata(0)
	if message_index >= 0 and message_index < message_list.size():
		selected_message = message_list[message_index]
		_update_properties_display()
		message_selected.emit(selected_message.message_id if selected_message else "")

func _on_add_message_pressed() -> void:
	var new_message: MissionMessage = MissionMessage.new()
	new_message.message_name = "Message %d" % (message_list.size() + 1)
	new_message.message_id = "message_%d" % (message_list.size() + 1)
	new_message.message_text = "This is a new mission message."
	new_message.sender_type = "command"
	new_message.sender_name = "Command"
	new_message.priority = 50
	new_message.delay = 0.0
	new_message.duration = 5.0
	new_message.voice_volume = 1.0
	
	message_list.append(new_message)
	_populate_messages_tree()
	
	# Select the new message
	var root: TreeItem = messages_tree.get_root()
	if root:
		var last_item: TreeItem = root.get_child(message_list.size() - 1)
		if last_item:
			last_item.select(0)
			_on_message_selected()
	
	message_updated.emit(new_message)

func _on_remove_message_pressed() -> void:
	if not selected_message:
		return
	
	var selected_item: TreeItem = messages_tree.get_selected()
	if not selected_item:
		return
	
	var message_index: int = selected_item.get_metadata(0)
	if message_index >= 0 and message_index < message_list.size():
		message_list.remove_at(message_index)
		selected_message = null
		_populate_messages_tree()
		_update_properties_display()

func _on_duplicate_message_pressed() -> void:
	if not selected_message:
		return
	
	var duplicated: MissionMessage = selected_message.duplicate()
	duplicated.message_name += " Copy"
	duplicated.message_id += "_copy"
	
	message_list.append(duplicated)
	_populate_messages_tree()
	
	message_updated.emit(duplicated)

func _on_play_message_pressed() -> void:
	if not selected_message or selected_message.voice_file.is_empty():
		print("MissionMessagesEditorPanel: No voice file to play")
		return
	
	# TODO: Implement voice file playback
	print("MissionMessagesEditorPanel: Playing voice file: %s" % selected_message.voice_file)

func _on_name_changed(new_text: String) -> void:
	if selected_message:
		selected_message.message_name = new_text
		_populate_messages_tree()  # Refresh display
		message_updated.emit(selected_message)

func _on_message_text_changed() -> void:
	if selected_message and message_text_edit:
		selected_message.message_text = message_text_edit.text
		message_updated.emit(selected_message)

func _on_sender_name_changed(new_text: String) -> void:
	if selected_message:
		selected_message.sender_name = new_text
		_populate_messages_tree()
		message_updated.emit(selected_message)

func _on_sender_type_selected(index: int) -> void:
	if selected_message and index >= 0 and index < sender_types.size():
		selected_message.sender_type = sender_types[index]["value"]
		_populate_messages_tree()
		message_updated.emit(selected_message)

func _on_delay_changed(value: float) -> void:
	if selected_message:
		selected_message.delay = value
		message_updated.emit(selected_message)

func _on_duration_changed(value: float) -> void:
	if selected_message:
		selected_message.duration = value
		message_updated.emit(selected_message)

func _on_priority_changed(value: float) -> void:
	if selected_message:
		selected_message.priority = int(value)
		_populate_messages_tree()
		message_updated.emit(selected_message)

func _on_voice_file_changed(new_text: String) -> void:
	if selected_message:
		selected_message.voice_file = new_text
		_populate_messages_tree()
		message_updated.emit(selected_message)

func _on_voice_volume_changed(value: float) -> void:
	if selected_message:
		selected_message.voice_volume = value
		message_updated.emit(selected_message)

func _on_builtin_message_toggled(enabled: bool) -> void:
	if selected_message:
		selected_message.builtin_message = enabled
		message_updated.emit(selected_message)

func _on_critical_message_toggled(enabled: bool) -> void:
	if selected_message:
		selected_message.critical_message = enabled
		message_updated.emit(selected_message)

func _on_no_log_toggled(enabled: bool) -> void:
	if selected_message:
		selected_message.no_log = enabled
		message_updated.emit(selected_message)

func _on_trigger_condition_changed(sexp_node: SexpNode) -> void:
	if selected_message:
		selected_message.trigger_condition = sexp_node
		message_updated.emit(selected_message)

func _on_browse_voice_pressed() -> void:
	if voice_file_dialog:
		voice_file_dialog.popup_centered(Vector2i(800, 600))

func _on_voice_file_selected(file_path: String) -> void:
	if voice_file_edit:
		voice_file_edit.text = file_path
		_on_voice_file_changed(file_path)

## Validation and export methods

func validate_component() -> Dictionary:
	var errors: Array[String] = []
	
	# Validate each message
	for i in range(message_list.size()):
		var message: MissionMessage = message_list[i]
		
		if message.message_name.is_empty():
			errors.append("Message %d: Name cannot be empty" % (i + 1))
		
		if message.message_text.is_empty():
			errors.append("Message %d: Text cannot be empty" % (i + 1))
		
		if message.sender_type.is_empty():
			errors.append("Message %d: Sender type must be selected" % (i + 1))
		
		if message.delay < 0.0:
			errors.append("Message %d: Delay cannot be negative" % (i + 1))
		
		if message.duration < 0.0:
			errors.append("Message %d: Duration cannot be negative" % (i + 1))
		
		if message.priority < 1 or message.priority > 100:
			errors.append("Message %d: Priority must be between 1 and 100" % (i + 1))
		
		if message.voice_volume < 0.0 or message.voice_volume > 1.0:
			errors.append("Message %d: Voice volume must be between 0.0 and 1.0" % (i + 1))
		
		# Validate voice file if specified
		if not message.voice_file.is_empty() and not FileAccess.file_exists(message.voice_file):
			errors.append("Message %d: Voice file does not exist: %s" % [i + 1, message.voice_file])
		
		# Validate trigger condition if present
		if message.trigger_condition and message.trigger_condition.has_method("validate"):
			var trigger_result: ValidationResult = message.trigger_condition.validate()
			if not trigger_result.is_valid():
				for error in trigger_result.get_errors():
					errors.append("Message %d trigger: %s" % [(i + 1), error])
	
	var is_valid: bool = errors.is_empty()
	validation_changed.emit(is_valid, errors)
	
	return {"is_valid": is_valid, "errors": errors}

func apply_changes(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	# Apply message list to mission data
	if mission_data.has_method("set_messages"):
		mission_data.set_messages(message_list)
	
	print("MissionMessagesEditorPanel: Applied %d messages to mission" % message_list.size())

func export_component() -> Dictionary:
	return {
		"messages": message_list,
		"count": message_list.size(),
		"has_voice_files": message_list.filter(func(m): return not m.voice_file.is_empty()).size(),
		"critical_count": message_list.filter(func(m): return m.critical_message).size()
	}

## Gets current message list
func get_messages() -> Array[MissionMessage]:
	return message_list

## Gets selected message
func get_selected_message() -> MissionMessage:
	return selected_message

## Gets messages by sender type
func get_messages_by_sender_type(sender_type: String) -> Array[MissionMessage]:
	return message_list.filter(func(message): return message.sender_type == sender_type)

## Gets messages with voice files
func get_messages_with_voice() -> Array[MissionMessage]:
	return message_list.filter(func(message): return not message.voice_file.is_empty())