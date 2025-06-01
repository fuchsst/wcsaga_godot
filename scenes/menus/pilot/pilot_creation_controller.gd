class_name PilotCreationController
extends Control

## WCS pilot creation scene controller providing complete pilot setup interface.
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

# Internal components
var main_container: VBoxContainer = null
var title_label: Label = null
var creation_form: Control = null
var callsign_container: VBoxContainer = null
var callsign_input: LineEdit = null
var callsign_validation_label: Label = null
var squadron_container: VBoxContainer = null
var squadron_input: LineEdit = null
var portrait_container: VBoxContainer = null
var portrait_grid: GridContainer = null
var selected_portrait: String = ""
var preview_panel: Control = null
var preview_callsign: Label = null
var preview_squadron: Label = null
var preview_image: TextureRect = null
var button_container: HBoxContainer = null
var create_button: MenuButton = null
var cancel_button: MenuButton = null

# Data management
var pilot_manager: PilotDataManager = null
var available_portraits: Array[String] = []
var portrait_textures: Dictionary = {}

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
	
	# Setup scene structure
	_create_scene_structure()
	_setup_scene_styling()
	_load_available_portraits()
	_setup_validation()
	
	# Focus callsign input
	if callsign_input:
		callsign_input.grab_focus()

func _connect_to_theme_manager() -> void:
	"""Connect to UIThemeManager for consistent styling."""
	var theme_manager: Node = get_tree().get_first_node_in_group("ui_theme_manager")
	if theme_manager and theme_manager is UIThemeManager:
		ui_theme_manager = theme_manager as UIThemeManager
		ui_theme_manager.theme_changed.connect(_on_theme_changed)

func _create_scene_structure() -> void:
	"""Create the pilot creation scene structure."""
	# Set as full-screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Main container with WCS background
	main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)
	
	# Title
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Create New Pilot"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title_label)
	
	# Content container with form and preview
	var content_container: HBoxContainer = HBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.add_theme_constant_override("separation", 30)
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(content_container)
	
	# Creation form
	_create_pilot_form(content_container)
	
	# Preview panel
	if show_preview_panel:
		_create_preview_panel(content_container)
	
	# Button container
	button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 15)
	main_container.add_child(button_container)
	
	_create_action_buttons()

func _create_pilot_form(parent: Control) -> void:
	"""Create pilot creation form."""
	creation_form = Control.new()
	creation_form.name = "CreationForm"
	creation_form.custom_minimum_size = Vector2(400, 0)
	creation_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(creation_form)
	
	var form_container: VBoxContainer = VBoxContainer.new()
	form_container.name = "FormContainer"
	form_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	form_container.add_theme_constant_override("separation", 20)
	creation_form.add_child(form_container)
	
	# Callsign section
	_create_callsign_section(form_container)
	
	# Squadron section
	if enable_squadron_selection:
		_create_squadron_section(form_container)
	
	# Portrait selection
	if enable_portrait_selection:
		_create_portrait_section(form_container)

func _create_callsign_section(parent: VBoxContainer) -> void:
	"""Create callsign input section."""
	callsign_container = VBoxContainer.new()
	callsign_container.name = "CallsignContainer"
	callsign_container.add_theme_constant_override("separation", 8)
	parent.add_child(callsign_container)
	
	# Callsign label
	var callsign_label: Label = Label.new()
	callsign_label.text = "Pilot Callsign:"
	callsign_label.add_theme_font_size_override("font_size", 16)
	callsign_container.add_child(callsign_label)
	
	# Callsign input
	callsign_input = LineEdit.new()
	callsign_input.name = "CallsignInput"
	callsign_input.placeholder_text = "Enter your callsign (1-16 characters)"
	callsign_input.max_length = 16
	callsign_input.text_changed.connect(_on_callsign_changed)
	callsign_input.text_submitted.connect(_on_callsign_submitted)
	callsign_container.add_child(callsign_input)
	
	# Validation feedback
	callsign_validation_label = Label.new()
	callsign_validation_label.name = "CallsignValidation"
	callsign_validation_label.text = ""
	callsign_validation_label.add_theme_font_size_override("font_size", 12)
	callsign_validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	callsign_container.add_child(callsign_validation_label)

func _create_squadron_section(parent: VBoxContainer) -> void:
	"""Create squadron input section."""
	squadron_container = VBoxContainer.new()
	squadron_container.name = "SquadronContainer"
	squadron_container.add_theme_constant_override("separation", 8)
	parent.add_child(squadron_container)
	
	# Squadron label
	var squadron_label: Label = Label.new()
	squadron_label.text = "Squadron Name (Optional):"
	squadron_label.add_theme_font_size_override("font_size", 16)
	squadron_container.add_child(squadron_label)
	
	# Squadron input
	squadron_input = LineEdit.new()
	squadron_input.name = "SquadronInput"
	squadron_input.placeholder_text = "Enter squadron name"
	squadron_input.max_length = 32
	squadron_input.text_changed.connect(_on_squadron_changed)
	squadron_container.add_child(squadron_input)

func _create_portrait_section(parent: VBoxContainer) -> void:
	"""Create portrait selection section."""
	portrait_container = VBoxContainer.new()
	portrait_container.name = "PortraitContainer"
	portrait_container.add_theme_constant_override("separation", 12)
	parent.add_child(portrait_container)
	
	# Portrait label
	var portrait_label: Label = Label.new()
	portrait_label.text = "Pilot Portrait:"
	portrait_label.add_theme_font_size_override("font_size", 16)
	portrait_container.add_child(portrait_label)
	
	# Portrait scroll container
	var portrait_scroll: ScrollContainer = ScrollContainer.new()
	portrait_scroll.name = "PortraitScroll"
	portrait_scroll.custom_minimum_size = Vector2(0, 200)
	portrait_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_container.add_child(portrait_scroll)
	
	# Portrait grid
	portrait_grid = GridContainer.new()
	portrait_grid.name = "PortraitGrid"
	portrait_grid.columns = 4
	portrait_grid.add_theme_constant_override("h_separation", 8)
	portrait_grid.add_theme_constant_override("v_separation", 8)
	portrait_scroll.add_child(portrait_grid)

func _create_preview_panel(parent: Control) -> void:
	"""Create pilot preview panel."""
	preview_panel = Control.new()
	preview_panel.name = "PreviewPanel"
	preview_panel.custom_minimum_size = Vector2(300, 0)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(preview_panel)
	
	var preview_container: VBoxContainer = VBoxContainer.new()
	preview_container.name = "PreviewContainer"
	preview_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_container.add_theme_constant_override("separation", 15)
	preview_panel.add_child(preview_container)
	
	# Preview title
	var preview_title: Label = Label.new()
	preview_title.text = "Pilot Preview"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 18)
	preview_container.add_child(preview_title)
	
	# Preview image
	preview_image = TextureRect.new()
	preview_image.name = "PreviewImage"
	preview_image.custom_minimum_size = Vector2(128, 128)
	preview_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_container.add_child(preview_image)
	
	# Preview callsign
	var callsign_preview_label: Label = Label.new()
	callsign_preview_label.text = "Callsign:"
	callsign_preview_label.add_theme_font_size_override("font_size", 14)
	preview_container.add_child(callsign_preview_label)
	
	preview_callsign = Label.new()
	preview_callsign.name = "PreviewCallsign"
	preview_callsign.text = "<not set>"
	preview_callsign.add_theme_font_size_override("font_size", 16)
	preview_container.add_child(preview_callsign)
	
	# Preview squadron
	var squadron_preview_label: Label = Label.new()
	squadron_preview_label.text = "Squadron:"
	squadron_preview_label.add_theme_font_size_override("font_size", 14)
	preview_container.add_child(squadron_preview_label)
	
	preview_squadron = Label.new()
	preview_squadron.name = "PreviewSquadron"
	preview_squadron.text = "<not set>"
	preview_squadron.add_theme_font_size_override("font_size", 16)
	preview_container.add_child(preview_squadron)

func _create_action_buttons() -> void:
	"""Create action buttons."""
	# Create button
	create_button = MenuButton.new()
	create_button.button_text = "Create Pilot"
	create_button.button_category = MenuButton.ButtonCategory.PRIMARY
	create_button.disabled = true
	create_button.pressed.connect(_on_create_pilot_pressed)
	button_container.add_child(create_button)
	
	# Cancel button
	cancel_button = MenuButton.new()
	cancel_button.button_text = "Cancel"
	cancel_button.button_category = MenuButton.ButtonCategory.SECONDARY
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_container.add_child(cancel_button)

func _setup_scene_styling() -> void:
	"""Apply WCS styling to scene components."""
	if not ui_theme_manager:
		return
	
	# Apply theme to controls
	ui_theme_manager.apply_theme_to_control(self)
	
	# Style title
	title_label.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("gray_light"))
	
	# Style form inputs
	if callsign_input:
		ui_theme_manager.apply_theme_to_control(callsign_input)
	
	if squadron_input:
		ui_theme_manager.apply_theme_to_control(squadron_input)
	
	# Style validation label
	if callsign_validation_label:
		callsign_validation_label.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("red_danger"))

func _load_available_portraits() -> void:
	"""Load available pilot portraits from assets."""
	available_portraits.clear()
	portrait_textures.clear()
	
	# Look for pilot portraits in assets directory
	var portrait_dir: String = "res://assets/images/pilots/"
	var dir: DirAccess = DirAccess.open(portrait_dir)
	
	if not dir:
		push_warning("PilotCreationController: Pilot portraits directory not found")
		_create_default_portraits()
		return
	
	# Scan for portrait images
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while not file_name.is_empty():
		if not dir.current_is_dir() and _is_image_file(file_name):
			var portrait_path: String = portrait_dir + file_name
			var texture: Texture2D = load(portrait_path) as Texture2D
			if texture:
				available_portraits.append(file_name)
				portrait_textures[file_name] = texture
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if available_portraits.is_empty():
		_create_default_portraits()
	else:
		_populate_portrait_grid()

func _create_default_portraits() -> void:
	"""Create default portraits if none found."""
	# Create simple colored placeholders
	var colors: Array[Color] = [
		Color.BLUE, Color.GREEN, Color.RED, Color.YELLOW,
		Color.PURPLE, Color.ORANGE, Color.CYAN, Color.MAGENTA
	]
	
	for i in range(colors.size()):
		var portrait_name: String = "default_%d.png" % i
		var texture: ImageTexture = ImageTexture.new()
		var image: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
		image.fill(colors[i])
		texture.set_image(image)
		
		available_portraits.append(portrait_name)
		portrait_textures[portrait_name] = texture
	
	_populate_portrait_grid()

func _populate_portrait_grid() -> void:
	"""Populate portrait selection grid."""
	if not portrait_grid:
		return
	
	# Clear existing portraits
	for child in portrait_grid.get_children():
		child.queue_free()
	
	# Add portrait buttons
	for portrait_name in available_portraits:
		var portrait_button: TextureButton = TextureButton.new()
		portrait_button.name = "Portrait_" + portrait_name
		portrait_button.texture_normal = portrait_textures[portrait_name]
		portrait_button.custom_minimum_size = Vector2(64, 64)
		portrait_button.expand_mode = TextureButton.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		portrait_button.pressed.connect(_on_portrait_selected.bind(portrait_name))
		
		# Apply styling
		if ui_theme_manager:
			ui_theme_manager.apply_theme_to_control(portrait_button)
		
		portrait_grid.add_child(portrait_button)

func _is_image_file(filename: String) -> bool:
	"""Check if file is a supported image format."""
	var ext: String = filename.get_extension().to_lower()
	return ext in ["png", "jpg", "jpeg", "bmp", "tga", "webp"]

# ============================================================================
# VALIDATION
# ============================================================================

func _setup_validation() -> void:
	"""Setup input validation."""
	_validate_all_inputs()

func _validate_callsign(callsign: String) -> Dictionary:
	"""Validate callsign input."""
	var result: Dictionary = {
		"valid": false,
		"message": ""
	}
	
	if callsign.is_empty():
		result.message = "Callsign is required"
		return result
	
	if callsign.length() > 16:
		result.message = "Callsign too long (max 16 characters)"
		return result
	
	# Use static validation from PilotDataManager
	if not PilotDataManager.validate_pilot_name(callsign):
		result.message = "Callsign contains invalid characters"
		return result
	
	# Check if pilot already exists
	if pilot_manager and pilot_manager.pilot_exists(callsign):
		result.message = "Pilot '%s' already exists" % callsign
		return result
	
	result.valid = true
	result.message = "Callsign is valid"
	return result

func _validate_all_inputs() -> void:
	"""Validate all form inputs and update UI."""
	# Validate callsign
	var callsign_text: String = callsign_input.text if callsign_input else ""
	var callsign_validation: Dictionary = _validate_callsign(callsign_text)
	
	callsign_valid = callsign_validation.valid
	
	# Update validation feedback
	if callsign_validation_label:
		callsign_validation_label.text = callsign_validation.message
		if callsign_valid:
			callsign_validation_label.add_theme_color_override("font_color", 
				ui_theme_manager.get_wcs_color("green_success") if ui_theme_manager else Color.GREEN)
		else:
			callsign_validation_label.add_theme_color_override("font_color", 
				ui_theme_manager.get_wcs_color("red_danger") if ui_theme_manager else Color.RED)
	
	# Squadron is always valid (optional)
	squadron_valid = true
	
	# Portrait selection validation
	portrait_selected = not selected_portrait.is_empty()
	
	# Update create button state
	var can_create: bool = callsign_valid and squadron_valid
	if create_button:
		create_button.disabled = not can_create
	
	# Update preview
	_update_preview()

func _update_preview() -> void:
	"""Update preview panel with current data."""
	if not show_preview_panel or not preview_panel:
		return
	
	# Update callsign preview
	var callsign_text: String = callsign_input.text if callsign_input else ""
	if preview_callsign:
		preview_callsign.text = callsign_text if not callsign_text.is_empty() else "<not set>"
	
	# Update squadron preview
	var squadron_text: String = squadron_input.text if squadron_input else ""
	if preview_squadron:
		preview_squadron.text = squadron_text if not squadron_text.is_empty() else "Unassigned"
	
	# Update portrait preview
	if preview_image:
		if not selected_portrait.is_empty() and portrait_textures.has(selected_portrait):
			preview_image.texture = portrait_textures[selected_portrait]
		else:
			preview_image.texture = null

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_callsign_changed(new_text: String) -> void:
	"""Handle callsign input change."""
	_validate_all_inputs()

func _on_callsign_submitted(text: String) -> void:
	"""Handle callsign input submission."""
	if callsign_valid and create_button and not create_button.disabled:
		_on_create_pilot_pressed()

func _on_squadron_changed(new_text: String) -> void:
	"""Handle squadron input change."""
	_validate_all_inputs()

func _on_portrait_selected(portrait_name: String) -> void:
	"""Handle portrait selection."""
	selected_portrait = portrait_name
	_validate_all_inputs()
	
	# Update portrait button styling to show selection
	for child in portrait_grid.get_children():
		if child is TextureButton:
			var button: TextureButton = child as TextureButton
			if button.name == "Portrait_" + portrait_name:
				button.modulate = Color.YELLOW  # Highlight selected
			else:
				button.modulate = Color.WHITE   # Normal state

func _on_create_pilot_pressed() -> void:
	"""Handle create pilot button press."""
	if not callsign_valid:
		return
	
	var callsign: String = callsign_input.text.strip_edges()
	var squadron: String = squadron_input.text.strip_edges() if squadron_input else ""
	var portrait: String = selected_portrait
	
	print("PilotCreationController: Creating pilot '%s'" % callsign)
	
	# Create pilot using manager
	var profile: PlayerProfile = pilot_manager.create_pilot(callsign, squadron, portrait)
	if profile:
		pilot_creation_completed.emit(profile)
	else:
		validation_error.emit("Failed to create pilot profile")

func _on_cancel_pressed() -> void:
	"""Handle cancel button press."""
	pilot_creation_cancelled.emit()

func _on_pilot_manager_validation_error(error_message: String) -> void:
	"""Handle pilot manager validation errors."""
	validation_error.emit(error_message)

func _on_pilot_created(profile: PlayerProfile) -> void:
	"""Handle successful pilot creation."""
	print("PilotCreationController: Pilot created successfully: %s" % profile.callsign)
	pilot_creation_completed.emit(profile)

func _on_theme_changed(theme_name: String) -> void:
	"""Handle theme changes."""
	_setup_scene_styling()

# ============================================================================
# PUBLIC API
# ============================================================================

func reset_form() -> void:
	"""Reset form to initial state."""
	if callsign_input:
		callsign_input.text = ""
	if squadron_input:
		squadron_input.text = ""
	
	selected_portrait = ""
	_validate_all_inputs()
	
	# Reset portrait selection highlighting
	for child in portrait_grid.get_children():
		if child is TextureButton:
			(child as TextureButton).modulate = Color.WHITE

func get_form_data() -> Dictionary:
	"""Get current form data."""
	return {
		"callsign": callsign_input.text if callsign_input else "",
		"squadron": squadron_input.text if squadron_input else "",
		"portrait": selected_portrait
	}

func set_form_data(data: Dictionary) -> void:
	"""Set form data from dictionary."""
	if data.has("callsign") and callsign_input:
		callsign_input.text = data.callsign as String
	
	if data.has("squadron") and squadron_input:
		squadron_input.text = data.squadron as String
	
	if data.has("portrait"):
		selected_portrait = data.portrait as String
	
	_validate_all_inputs()

func is_form_valid() -> bool:
	"""Check if form is valid for submission."""
	return callsign_valid and squadron_valid