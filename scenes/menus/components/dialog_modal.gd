class_name DialogModal
extends Control

## WCS-styled dialog modal for confirmations, warnings, and information displays.
## Provides consistent modal behavior with military aesthetic and accessibility support.
## Integrates with UIThemeManager for responsive design and theme consistency.

signal dialog_confirmed(result: bool, user_data: Dictionary)
signal dialog_cancelled()
signal dialog_closed()

# Dialog types for different styling and behavior
enum DialogType {
	INFO,           # Information display
	WARNING,        # Warning message
	ERROR,          # Error notification
	CONFIRMATION,   # Yes/No confirmation
	INPUT,          # Text input dialog
	CUSTOM          # Custom dialog layout
}

# Button configuration for dialog
enum ButtonLayout {
	OK_ONLY,        # Single OK button
	OK_CANCEL,      # OK and Cancel buttons
	YES_NO,         # Yes and No buttons
	YES_NO_CANCEL,  # Yes, No, and Cancel buttons
	CUSTOM          # Custom button configuration
}

# Dialog configuration
@export var dialog_type: DialogType = DialogType.INFO
@export var button_layout: ButtonLayout = ButtonLayout.OK_ONLY
@export var dialog_title: String = "Dialog"
@export var dialog_message: String = "Message"
@export var auto_close_delay: float = 0.0  # Auto-close after delay (0 = no auto-close)
@export var modal_background: bool = true
@export var escape_closes: bool = true

# Visual configuration
@export var dialog_width: int = 400
@export var dialog_height: int = 200
@export var enable_animations: bool = true

# Internal components
var background_overlay: ColorRect = null
var dialog_panel: Panel = null
var title_label: Label = null
var message_label: RichTextLabel = null
var button_container: HBoxContainer = null
var input_field: LineEdit = null

# Buttons
var button_ok: MenuButton = null
var button_cancel: MenuButton = null
var button_yes: MenuButton = null
var button_no: MenuButton = null
var custom_buttons: Array[MenuButton] = []

# Animation and state
var show_tween: Tween = null
var hide_tween: Tween = null
var is_dialog_visible: bool = false
var user_data: Dictionary = {}

# Theme integration
var ui_theme_manager: UIThemeManager = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_dialog_modal()

func _initialize_dialog_modal() -> void:
	"""Initialize the dialog modal with WCS styling and components."""
	print("DialogModal: Initializing dialog modal")
	
	# Connect to theme manager
	_connect_to_theme_manager()
	
	# Setup dialog structure
	_create_dialog_structure()
	_setup_dialog_styling()
	_setup_input_handling()
	
	# Initially hide the dialog
	visible = false
	modulate.a = 0.0

func _connect_to_theme_manager() -> void:
	"""Connect to UIThemeManager for consistent styling."""
	var theme_manager: Node = get_tree().get_first_node_in_group("ui_theme_manager")
	if theme_manager and theme_manager is UIThemeManager:
		ui_theme_manager = theme_manager as UIThemeManager
		ui_theme_manager.theme_changed.connect(_on_theme_changed)

func _create_dialog_structure() -> void:
	"""Create the dialog modal structure with all components."""
	# Set dialog as full-screen overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to background
	
	# Create background overlay
	background_overlay = ColorRect.new()
	background_overlay.name = "BackgroundOverlay"
	background_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_overlay.color = Color.BLACK
	background_overlay.color.a = 0.7  # Semi-transparent
	add_child(background_overlay)
	
	# Create main dialog panel
	dialog_panel = Panel.new()
	dialog_panel.name = "DialogPanel"
	dialog_panel.set_anchors_preset(Control.PRESET_CENTER)
	dialog_panel.size = Vector2(dialog_width, dialog_height)
	dialog_panel.position = Vector2(-dialog_width / 2, -dialog_height / 2)
	add_child(dialog_panel)
	
	# Create dialog content container
	var content_container: VBoxContainer = VBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_container.add_theme_constant_override("separation", 10)
	dialog_panel.add_child(content_container)
	
	# Create title label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = dialog_title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	content_container.add_child(title_label)
	
	# Create message display
	message_label = RichTextLabel.new()
	message_label.name = "MessageLabel"
	message_label.text = dialog_message
	message_label.bbcode_enabled = true
	message_label.fit_content = true
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(message_label)
	
	# Create input field (initially hidden)
	input_field = LineEdit.new()
	input_field.name = "InputField"
	input_field.placeholder_text = "Enter text..."
	input_field.visible = false
	content_container.add_child(input_field)
	
	# Create button container
	button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 10)
	content_container.add_child(button_container)
	
	# Create buttons based on layout
	_create_dialog_buttons()

func _create_dialog_buttons() -> void:
	"""Create dialog buttons based on button layout."""
	# Clear existing buttons
	for child in button_container.get_children():
		child.queue_free()
	custom_buttons.clear()
	
	match button_layout:
		ButtonLayout.OK_ONLY:
			button_ok = _create_button("OK", MenuButton.ButtonCategory.PRIMARY)
			button_ok.pressed.connect(_on_ok_pressed)
		
		ButtonLayout.OK_CANCEL:
			button_ok = _create_button("OK", MenuButton.ButtonCategory.PRIMARY)
			button_cancel = _create_button("Cancel", MenuButton.ButtonCategory.SECONDARY)
			button_ok.pressed.connect(_on_ok_pressed)
			button_cancel.pressed.connect(_on_cancel_pressed)
		
		ButtonLayout.YES_NO:
			button_yes = _create_button("Yes", MenuButton.ButtonCategory.SUCCESS)
			button_no = _create_button("No", MenuButton.ButtonCategory.SECONDARY)
			button_yes.pressed.connect(_on_yes_pressed)
			button_no.pressed.connect(_on_no_pressed)
		
		ButtonLayout.YES_NO_CANCEL:
			button_yes = _create_button("Yes", MenuButton.ButtonCategory.SUCCESS)
			button_no = _create_button("No", MenuButton.ButtonCategory.DANGER)
			button_cancel = _create_button("Cancel", MenuButton.ButtonCategory.SECONDARY)
			button_yes.pressed.connect(_on_yes_pressed)
			button_no.pressed.connect(_on_no_pressed)
			button_cancel.pressed.connect(_on_cancel_pressed)

func _create_button(text: String, category: MenuButton.ButtonCategory) -> MenuButton:
	"""Create a dialog button with specified text and category."""
	var button: MenuButton = MenuButton.new()
	button.button_text = text
	button.button_category = category
	button.custom_minimum_size = Vector2(80, 35)
	button_container.add_child(button)
	custom_buttons.append(button)
	return button

func _setup_dialog_styling() -> void:
	"""Apply WCS styling to dialog components."""
	if not ui_theme_manager:
		return
	
	# Apply theme to main components
	ui_theme_manager.apply_theme_to_control(dialog_panel)
	
	# Set dialog panel style based on type
	var panel_style: StyleBox
	match dialog_type:
		DialogType.ERROR:
			panel_style = ui_theme_manager.get_panel_style("dialog")
			if panel_style is StyleBoxFlat:
				(panel_style as StyleBoxFlat).border_color = ui_theme_manager.get_wcs_color("red_danger")
		DialogType.WARNING:
			panel_style = ui_theme_manager.get_panel_style("dialog")
			if panel_style is StyleBoxFlat:
				(panel_style as StyleBoxFlat).border_color = ui_theme_manager.get_wcs_color("yellow_warning")
		_:
			panel_style = ui_theme_manager.get_panel_style("dialog")
	
	dialog_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Style title label
	title_label.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("gray_light"))
	title_label.add_theme_font_size_override("font_size", ui_theme_manager.get_responsive_font_size(16))
	
	# Style message label
	message_label.add_theme_color_override("default_color", ui_theme_manager.get_wcs_color("gray_light"))
	message_label.add_theme_font_size_override("normal_font_size", ui_theme_manager.get_responsive_font_size(14))
	
	# Style input field
	if input_field:
		ui_theme_manager.apply_theme_to_control(input_field)

func _setup_input_handling() -> void:
	"""Setup keyboard input handling for dialog."""
	set_process_input(true)
	
	# Connect input field signals
	if input_field:
		input_field.text_submitted.connect(_on_input_submitted)

func _input(event: InputEvent) -> void:
	"""Handle keyboard input for dialog navigation."""
	if not is_dialog_visible:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if escape_closes:
					_close_dialog_cancelled()
			KEY_ENTER:
				if button_ok and button_ok.visible:
					_on_ok_pressed()
				elif button_yes and button_yes.visible:
					_on_yes_pressed()

# ============================================================================
# BUTTON SIGNAL HANDLERS
# ============================================================================

func _on_ok_pressed() -> void:
	"""Handle OK button press."""
	var result_data: Dictionary = user_data.duplicate()
	if input_field and input_field.visible:
		result_data["input_text"] = input_field.text
	
	dialog_confirmed.emit(true, result_data)
	close_dialog()

func _on_cancel_pressed() -> void:
	"""Handle Cancel button press."""
	_close_dialog_cancelled()

func _on_yes_pressed() -> void:
	"""Handle Yes button press."""
	dialog_confirmed.emit(true, user_data)
	close_dialog()

func _on_no_pressed() -> void:
	"""Handle No button press."""
	dialog_confirmed.emit(false, user_data)
	close_dialog()

func _on_input_submitted(text: String) -> void:
	"""Handle input field submission."""
	if button_ok:
		_on_ok_pressed()

func _close_dialog_cancelled() -> void:
	"""Handle dialog cancellation."""
	dialog_cancelled.emit()
	close_dialog()

func _on_theme_changed(theme_name: String) -> void:
	"""Handle theme changes."""
	_setup_dialog_styling()

# ============================================================================
# ANIMATION METHODS
# ============================================================================

func _animate_show() -> void:
	"""Animate dialog show with scaling and fade effect."""
	if not enable_animations:
		visible = true
		modulate.a = 1.0
		return
	
	visible = true
	modulate.a = 0.0
	dialog_panel.scale = Vector2(0.8, 0.8)
	
	if show_tween:
		show_tween.kill()
	
	show_tween = create_tween()
	show_tween.set_parallel(true)
	
	# Fade in
	show_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	# Scale in with overshoot
	show_tween.tween_method(_set_dialog_scale, 0.8, 1.05, 0.2)
	show_tween.tween_method(_set_dialog_scale, 1.05, 1.0, 0.1).set_delay(0.2)

func _animate_hide() -> void:
	"""Animate dialog hide with scaling and fade effect."""
	if not enable_animations:
		visible = false
		return
	
	if hide_tween:
		hide_tween.kill()
	
	hide_tween = create_tween()
	hide_tween.set_parallel(true)
	
	# Fade out
	hide_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	
	# Scale out
	hide_tween.tween_property(dialog_panel, "scale", Vector2(0.9, 0.9), 0.2)
	
	# Hide when complete
	hide_tween.tween_callback(_on_hide_animation_complete).set_delay(0.2)

func _set_dialog_scale(scale_value: float) -> void:
	"""Helper method for dialog scaling animation."""
	dialog_panel.scale = Vector2(scale_value, scale_value)

func _on_hide_animation_complete() -> void:
	"""Called when hide animation completes."""
	visible = false
	dialog_closed.emit()

# ============================================================================
# PUBLIC API
# ============================================================================

func show_dialog(title: String = "", message: String = "", data: Dictionary = {}) -> void:
	"""Show the dialog with specified parameters."""
	dialog_title = title
	dialog_message = message
	user_data = data.duplicate()
	
	# Update UI elements
	if title_label:
		title_label.text = title
	if message_label:
		message_label.text = message
	
	# Show input field for input dialogs
	if input_field:
		input_field.visible = (dialog_type == DialogType.INPUT)
		if dialog_type == DialogType.INPUT:
			input_field.grab_focus()
	
	# Focus first button
	_focus_default_button()
	
	is_dialog_visible = true
	_animate_show()
	
	# Setup auto-close if specified
	if auto_close_delay > 0.0:
		get_tree().create_timer(auto_close_delay).timeout.connect(close_dialog)

func close_dialog() -> void:
	"""Close the dialog with animation."""
	is_dialog_visible = false
	_animate_hide()

func set_dialog_type(type: DialogType) -> void:
	"""Set dialog type and update styling."""
	dialog_type = type
	_setup_dialog_styling()

func set_button_layout(layout: ButtonLayout) -> void:
	"""Set button layout and recreate buttons."""
	button_layout = layout
	_create_dialog_buttons()

func add_custom_button(text: String, category: MenuButton.ButtonCategory = MenuButton.ButtonCategory.STANDARD, callback: Callable = Callable()) -> MenuButton:
	"""Add a custom button to the dialog."""
	var button: MenuButton = _create_button(text, category)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button

func set_input_placeholder(placeholder: String) -> void:
	"""Set placeholder text for input field."""
	if input_field:
		input_field.placeholder_text = placeholder

func get_input_text() -> String:
	"""Get current input field text."""
	if input_field:
		return input_field.text
	return ""

func set_dialog_size(width: int, height: int) -> void:
	"""Set dialog size and reposition."""
	dialog_width = width
	dialog_height = height
	
	if dialog_panel:
		dialog_panel.size = Vector2(width, height)
		dialog_panel.position = Vector2(-width / 2, -height / 2)

func _focus_default_button() -> void:
	"""Focus the default button based on layout."""
	var default_button: MenuButton = null
	
	match button_layout:
		ButtonLayout.OK_ONLY, ButtonLayout.OK_CANCEL:
			default_button = button_ok
		ButtonLayout.YES_NO, ButtonLayout.YES_NO_CANCEL:
			default_button = button_yes
	
	if default_button:
		default_button.grab_focus()

# ============================================================================
# STATIC CONVENIENCE METHODS
# ============================================================================

static func show_info_dialog(parent: Node, title: String, message: String) -> DialogModal:
	"""Show an information dialog."""
	var dialog: DialogModal = DialogModal.new()
	dialog.dialog_type = DialogType.INFO
	dialog.button_layout = ButtonLayout.OK_ONLY
	parent.add_child(dialog)
	dialog.show_dialog(title, message)
	return dialog

static func show_confirmation_dialog(parent: Node, title: String, message: String, callback: Callable) -> DialogModal:
	"""Show a confirmation dialog."""
	var dialog: DialogModal = DialogModal.new()
	dialog.dialog_type = DialogType.CONFIRMATION
	dialog.button_layout = ButtonLayout.YES_NO
	dialog.dialog_confirmed.connect(callback)
	parent.add_child(dialog)
	dialog.show_dialog(title, message)
	return dialog

static func show_warning_dialog(parent: Node, title: String, message: String) -> DialogModal:
	"""Show a warning dialog."""
	var dialog: DialogModal = DialogModal.new()
	dialog.dialog_type = DialogType.WARNING
	dialog.button_layout = ButtonLayout.OK_ONLY
	parent.add_child(dialog)
	dialog.show_dialog(title, message)
	return dialog

static func show_error_dialog(parent: Node, title: String, message: String) -> DialogModal:
	"""Show an error dialog."""
	var dialog: DialogModal = DialogModal.new()
	dialog.dialog_type = DialogType.ERROR
	dialog.button_layout = ButtonLayout.OK_ONLY
	parent.add_child(dialog)
	dialog.show_dialog(title, message)
	return dialog

func _exit_tree() -> void:
	"""Clean up when dialog is removed."""
	if show_tween:
		show_tween.kill()
	if hide_tween:
		hide_tween.kill()