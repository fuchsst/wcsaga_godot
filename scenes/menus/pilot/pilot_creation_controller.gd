class_name PilotCreationController
extends Control

## Simplified WCS pilot creation scene controller for scene-based UI approach.
## Handles callsign, squadron, and portrait selection with validation and preview.
## Integrates with PilotDataManager for secure profile creation and persistence.

signal pilot_creation_completed(profile: PlayerProfile)
signal pilot_creation_cancelled()
signal validation_error(error_message: String)

# UI configuration
@export var enable_portrait_selection: bool = true
@export var enable_squadron_selection: bool = true
@export var show_preview_panel: bool = true
@export var auto_generate_short_callsign: bool = true

# Scene references (from pilot_creation.tscn)
@onready var main_container: VBoxContainer = $MainContainer
@onready var title_label: Label = $MainContainer/HeaderContainer/TitleLabel
@onready var creation_form: VBoxContainer = $MainContainer/ContentContainer/CreationForm
@onready var callsign_container: VBoxContainer = $MainContainer/ContentContainer/CreationForm/CallsignContainer
@onready var callsign_input: LineEdit = $MainContainer/ContentContainer/CreationForm/CallsignContainer/CallsignInput
@onready var callsign_validation_label: Label = $MainContainer/ContentContainer/CreationForm/CallsignContainer/CallsignValidationLabel
@onready var squadron_container: VBoxContainer = $MainContainer/ContentContainer/CreationForm/SquadronContainer
@onready var squadron_input: LineEdit = $MainContainer/ContentContainer/CreationForm/SquadronContainer/SquadronInput
@onready var portrait_container: VBoxContainer = $MainContainer/ContentContainer/CreationForm/PortraitContainer
@onready var portrait_grid: GridContainer = $MainContainer/ContentContainer/CreationForm/PortraitContainer/PortraitScroll/PortraitGrid
@onready var preview_panel: VBoxContainer = $MainContainer/ContentContainer/PreviewPanel
@onready var preview_callsign: Label = $MainContainer/ContentContainer/PreviewPanel/PreviewInfo/PreviewDetails/PreviewCallsign
@onready var preview_squadron: Label = $MainContainer/ContentContainer/PreviewPanel/PreviewInfo/PreviewDetails/PreviewSquadron
@onready var preview_image: TextureRect = $MainContainer/ContentContainer/PreviewPanel/PreviewInfo/PreviewImage
@onready var button_container: HBoxContainer = $MainContainer/ButtonContainer
@onready var create_button: Button = $MainContainer/ButtonContainer/CreateButton
@onready var cancel_button: Button = $MainContainer/HeaderContainer/CancelButton
@onready var validation_message: AcceptDialog = $ValidationDisplay/ValidationMessage

# Data management
var pilot_manager: PilotDataManager = null
var available_portraits: Array[String] = []
var portrait_textures: Dictionary = {}
var selected_portrait: String = ""

# Validation
var callsign_valid: bool = false
var squadron_valid: bool = true  # Squadron is optional
var portrait_selected: bool = false

# Theme integration
var ui_theme_manager: UIThemeManager = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_pilot_creation()

func _initialize_pilot_creation() -> void:
	"""Initialize pilot creation scene with WCS styling and components."""
	print("PilotCreationController: Initializing pilot creation interface")
	
	# Connect to theme manager
	_connect_to_theme_manager()
	
	# Initialize pilot manager
	pilot_manager = PilotDataManager.new()
	pilot_manager.validation_error.connect(_on_pilot_manager_validation_error)
	pilot_manager.pilot_created.connect(_on_pilot_created)
	
	# Setup scene functionality
	_setup_scene_styling()
	_load_available_portraits()
	_setup_validation()
	_connect_ui_signals()
	
	# Focus callsign input
	if callsign_input:
		callsign_input.grab_focus()

func _connect_to_theme_manager() -> void:
	"""Connect to UIThemeManager for consistent styling."""
	var theme_manager: Node = get_tree().get_first_node_in_group("ui_theme_manager")
	if theme_manager and theme_manager is UIThemeManager:
		ui_theme_manager = theme_manager as UIThemeManager
		ui_theme_manager.theme_changed.connect(_on_theme_changed)

func _connect_ui_signals() -> void:
	"""Connect UI signals for pilot creation interface."""
	# Connect input signals
	if callsign_input:
		callsign_input.text_changed.connect(_on_callsign_changed)
		callsign_input.text_submitted.connect(_on_callsign_submitted)
	
	if squadron_input:
		squadron_input.text_changed.connect(_on_squadron_changed)
	
	# Connect button signals
	if create_button:
		create_button.pressed.connect(_on_create_pilot_pressed)
	
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

func _setup_scene_styling() -> void:
	"""Apply WCS styling to scene components."""
	if not ui_theme_manager:
		return
	
	# Apply theme to controls
	ui_theme_manager.apply_theme_to_control(self)
	
	# Set initial preview text
	if preview_callsign:
		preview_callsign.text = "Callsign: [Not Set]"
	if preview_squadron:
		preview_squadron.text = "Squadron: [Not Set]"

func _load_available_portraits() -> void:
	"""Load available portrait images."""
	available_portraits.clear()
	portrait_textures.clear()
	
	# Load default portraits first
	_create_default_portraits()
	
	# Try to load custom portraits from data/players/portraits/
	var portraits_dir: String = "user://portraits/"
	if DirAccess.dir_exists_absolute(portraits_dir):
		var dir: DirAccess = DirAccess.open(portraits_dir)
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and _is_image_file(file_name):
					var portrait_path: String = portraits_dir + file_name
					var texture: Texture2D = load(portrait_path)
					if texture:
						available_portraits.append(file_name)
						portrait_textures[file_name] = texture
				file_name = dir.get_next()
			dir.list_dir_end()
	
	# Populate portrait grid
	_populate_portrait_grid()

func _create_default_portraits() -> void:
	"""Create default portrait placeholders."""
	# Add default portraits
	var default_portraits: Array[String] = [
		"pilot_male_01", "pilot_female_01", "pilot_male_02", "pilot_female_02",
		"pilot_male_03", "pilot_female_03", "pilot_male_04", "pilot_female_04"
	]
	
	for portrait_name in default_portraits:
		available_portraits.append(portrait_name)
		# Create placeholder texture for default portraits
		var placeholder: ImageTexture = ImageTexture.new()
		var image: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
		image.fill(Color.GRAY)
		placeholder.set_image(image)
		portrait_textures[portrait_name] = placeholder

func _populate_portrait_grid() -> void:
	"""Populate the portrait selection grid."""
	if not portrait_grid:
		return
	
	# Clear existing portraits
	for child in portrait_grid.get_children():
		child.queue_free()
	
	# Add portrait buttons
	for portrait_name in available_portraits:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(64, 64)
		button.icon = portrait_textures.get(portrait_name, null)
		button.pressed.connect(_on_portrait_selected.bind(portrait_name))
		button.tooltip_text = portrait_name
		portrait_grid.add_child(button)

func _is_image_file(filename: String) -> bool:
	"""Check if a file is a supported image format."""
	var extension: String = filename.get_extension().to_lower()
	return extension in ["png", "jpg", "jpeg", "webp", "bmp", "tga"]

func _setup_validation() -> void:
	"""Setup input validation."""
	_validate_all_inputs()

func _validate_callsign(callsign: String) -> Dictionary:
	"""Validate pilot callsign."""
	var result: Dictionary = {"valid": false, "message": ""}
	
	if callsign.length() < 3:
		result.message = "Callsign must be at least 3 characters"
		return result
	
	if callsign.length() > 20:
		result.message = "Callsign must be 20 characters or less"
		return result
	
	# Check for valid characters (letters, numbers, limited symbols)
	var regex: RegEx = RegEx.new()
	regex.compile("^[a-zA-Z0-9_-]+$")
	if not regex.search(callsign):
		result.message = "Callsign can only contain letters, numbers, underscores, and hyphens"
		return result
	
	# Check if callsign already exists
	if pilot_manager and pilot_manager.pilot_exists(callsign):
		result.message = "A pilot with this callsign already exists"
		return result
	
	result.valid = true
	result.message = "Callsign is valid"
	return result

func _validate_all_inputs() -> void:
	"""Validate all form inputs and update UI."""
	var callsign_text: String = callsign_input.text if callsign_input else ""
	var validation_result: Dictionary = _validate_callsign(callsign_text)
	
	callsign_valid = validation_result.valid
	
	# Update validation label
	if callsign_validation_label:
		callsign_validation_label.text = validation_result.message
		if callsign_valid:
			callsign_validation_label.modulate = Color.GREEN
		else:
			callsign_validation_label.modulate = Color.RED
	
	# Squadron is always valid (optional)
	squadron_valid = true
	
	# Portrait selection is optional but recommended
	portrait_selected = not selected_portrait.is_empty()
	
	# Update create button
	var form_valid: bool = callsign_valid and squadron_valid
	if create_button:
		create_button.disabled = not form_valid
	
	# Update preview
	_update_preview()

func _update_preview() -> void:
	"""Update the pilot preview panel."""
	if not preview_panel:
		return
	
	var callsign_text: String = callsign_input.text if callsign_input else ""
	var squadron_text: String = squadron_input.text if squadron_input else ""
	
	# Update preview labels
	if preview_callsign:
		preview_callsign.text = "Callsign: " + (callsign_text if not callsign_text.is_empty() else "[Not Set]")
	
	if preview_squadron:
		preview_squadron.text = "Squadron: " + (squadron_text if not squadron_text.is_empty() else "[Not Set]")
	
	# Update preview image
	if preview_image and not selected_portrait.is_empty():
		preview_image.texture = portrait_textures.get(selected_portrait, null)

# Signal handlers
func _on_callsign_changed(new_text: String) -> void:
	_validate_all_inputs()

func _on_callsign_submitted(text: String) -> void:
	if callsign_valid and create_button and not create_button.disabled:
		_on_create_pilot_pressed()

func _on_squadron_changed(new_text: String) -> void:
	_update_preview()

func _on_portrait_selected(portrait_name: String) -> void:
	selected_portrait = portrait_name
	portrait_selected = true
	
	# Update visual selection state
	if portrait_grid:
		for i in range(portrait_grid.get_child_count()):
			var button: Button = portrait_grid.get_child(i) as Button
			if button:
				button.button_pressed = (button.tooltip_text == portrait_name)
	
	_update_preview()

func _on_create_pilot_pressed() -> void:
	"""Handle create pilot button press."""
	if not callsign_valid:
		return
	
	var form_data: Dictionary = get_form_data()
	
	# Create pilot profile
	if pilot_manager:
		pilot_manager.create_pilot_profile(
			form_data.callsign,
			form_data.squadron,
			form_data.portrait
		)

func _on_cancel_pressed() -> void:
	"""Handle cancel button press."""
	pilot_creation_cancelled.emit()

func _on_pilot_manager_validation_error(error_message: String) -> void:
	validation_error.emit(error_message)
	if validation_message:
		validation_message.dialog_text = error_message
		validation_message.popup_centered()

func _on_pilot_created(profile: PlayerProfile) -> void:
	"""Handle successful pilot creation."""
	pilot_creation_completed.emit(profile)

func _on_theme_changed(theme_name: String) -> void:
	"""Handle theme change."""
	_setup_scene_styling()

# Public interface
func reset_form() -> void:
	"""Reset the form to default state."""
	if callsign_input:
		callsign_input.clear()
	if squadron_input:
		squadron_input.clear()
	
	selected_portrait = ""
	portrait_selected = false
	
	# Reset portrait selection visual state
	if portrait_grid:
		for button in portrait_grid.get_children():
			if button is Button:
				button.button_pressed = false
	
	_validate_all_inputs()

func get_form_data() -> Dictionary:
	"""Get current form data."""
	return {
		"callsign": callsign_input.text if callsign_input else "",
		"squadron": squadron_input.text if squadron_input else "",
		"portrait": selected_portrait
	}

func set_form_data(data: Dictionary) -> void:
	"""Set form data from dictionary."""
	if callsign_input and data.has("callsign"):
		callsign_input.text = data.callsign
	
	if squadron_input and data.has("squadron"):
		squadron_input.text = data.squadron
	
	if data.has("portrait"):
		_on_portrait_selected(data.portrait)
	
	_validate_all_inputs()

func is_form_valid() -> bool:
	"""Check if the form is currently valid."""
	return callsign_valid and squadron_valid