class_name SettingsPanel
extends Control

## WCS-styled settings panel for configuration options with validation.
## Provides consistent settings UI with automatic validation and persistence.
## Integrates with ConfigurationManager for settings storage and UIThemeManager for styling.

signal setting_changed(setting_key: String, old_value: Variant, new_value: Variant)
signal settings_applied()
signal settings_reset()
signal validation_failed(setting_key: String, error_message: String)

# Setting types for different input controls
enum SettingType {
	BOOLEAN,        # Checkbox
	INTEGER,        # Spin box with range
	FLOAT,          # Spin box with decimal range
	STRING,         # Line edit
	ENUM,           # Option button with predefined values
	RANGE,          # Slider with min/max
	COLOR,          # Color picker
	KEY_BINDING,    # Key binding input
	DIRECTORY,      # Directory selection
	FILE            # File selection
}

# Validation rules
enum ValidationType {
	NONE,           # No validation
	RANGE,          # Numeric range validation
	REGEX,          # Regular expression validation
	CUSTOM,         # Custom validation function
	FILE_EXISTS,    # File existence validation
	DIR_EXISTS      # Directory existence validation
}

# Setting definition structure
class SettingDefinition:
	var key: String
	var display_name: String
	var setting_type: SettingType
	var default_value: Variant
	var description: String = ""
	var category: String = "General"
	var validation_type: ValidationType = ValidationType.NONE
	var validation_data: Variant = null  # Range, regex pattern, or custom function
	var enum_values: Array[String] = []  # For ENUM type
	var tooltip: String = ""
	var is_readonly: bool = false
	var requires_restart: bool = false

# Panel configuration
@export var panel_title: String = "Settings"
@export var show_apply_button: bool = true
@export var show_reset_button: bool = true
@export var show_categories: bool = true
@export var auto_apply_changes: bool = false
@export var confirm_reset: bool = true

# Internal components
var main_container: VBoxContainer = null
var title_label: Label = null
var category_tabs: TabContainer = null
var settings_scroll: ScrollContainer = null
var settings_container: VBoxContainer = null
var button_container: HBoxContainer = null
var apply_button: MenuButton = null
var reset_button: MenuButton = null
var cancel_button: MenuButton = null

# Settings management
var setting_definitions: Array[SettingDefinition] = []
var setting_controls: Dictionary = {}  # key -> control node
var current_values: Dictionary = {}
var original_values: Dictionary = {}
var has_unsaved_changes: bool = false

# Theme integration
var ui_theme_manager: UIThemeManager = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_settings_panel()

func _initialize_settings_panel() -> void:
	"""Initialize the settings panel with WCS styling and components."""
	print("SettingsPanel: Initializing settings panel")
	
	# Connect to theme manager
	_connect_to_theme_manager()
	
	# Setup panel structure
	_create_panel_structure()
	_setup_panel_styling()
	
	# Load existing settings
	_load_current_settings()

func _connect_to_theme_manager() -> void:
	"""Connect to UIThemeManager for consistent styling."""
	var theme_manager: Node = get_tree().get_first_node_in_group("ui_theme_manager")
	if theme_manager and theme_manager is UIThemeManager:
		ui_theme_manager = theme_manager as UIThemeManager
		ui_theme_manager.theme_changed.connect(_on_theme_changed)

func _create_panel_structure() -> void:
	"""Create the settings panel structure with all components."""
	# Main container
	main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)
	
	# Title label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = panel_title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	main_container.add_child(title_label)
	
	# Category tabs (if enabled)
	if show_categories:
		category_tabs = TabContainer.new()
		category_tabs.name = "CategoryTabs"
		category_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_container.add_child(category_tabs)
	else:
		# Settings scroll container
		settings_scroll = ScrollContainer.new()
		settings_scroll.name = "SettingsScroll"
		settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_container.add_child(settings_scroll)
		
		settings_container = VBoxContainer.new()
		settings_container.name = "SettingsContainer"
		settings_container.add_theme_constant_override("separation", 8)
		settings_scroll.add_child(settings_container)
	
	# Button container
	button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 10)
	main_container.add_child(button_container)
	
	# Create buttons
	_create_panel_buttons()

func _create_panel_buttons() -> void:
	"""Create panel action buttons."""
	if show_apply_button:
		apply_button = MenuButton.new()
		apply_button.button_text = "Apply"
		apply_button.button_category = MenuButton.ButtonCategory.PRIMARY
		apply_button.pressed.connect(_on_apply_pressed)
		button_container.add_child(apply_button)
	
	if show_reset_button:
		reset_button = MenuButton.new()
		reset_button.button_text = "Reset"
		reset_button.button_category = MenuButton.ButtonCategory.WARNING
		reset_button.pressed.connect(_on_reset_pressed)
		button_container.add_child(reset_button)
	
	# Cancel button (always available)
	cancel_button = MenuButton.new()
	cancel_button.button_text = "Cancel"
	cancel_button.button_category = MenuButton.ButtonCategory.SECONDARY
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_container.add_child(cancel_button)

func _setup_panel_styling() -> void:
	"""Apply WCS styling to panel components."""
	if not ui_theme_manager:
		return
	
	# Apply theme to main components
	ui_theme_manager.apply_theme_to_control(self)
	
	# Style title
	title_label.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("gray_light"))
	title_label.add_theme_font_size_override("font_size", ui_theme_manager.get_responsive_font_size(18))
	
	# Style category tabs
	if category_tabs:
		ui_theme_manager.apply_theme_to_control(category_tabs)

func _load_current_settings() -> void:
	"""Load current settings from ConfigurationManager."""
	current_values.clear()
	original_values.clear()
	
	for setting_def: SettingDefinition in setting_definitions:
		var value: Variant = setting_def.default_value
		
		if ConfigurationManager and ConfigurationManager.has_method("get_setting"):
			value = ConfigurationManager.get_setting(setting_def.key, setting_def.default_value)
		
		current_values[setting_def.key] = value
		original_values[setting_def.key] = value

# ============================================================================
# SETTING DEFINITION MANAGEMENT
# ============================================================================

func add_setting(
	key: String,
	display_name: String,
	setting_type: SettingType,
	default_value: Variant,
	description: String = "",
	category: String = "General"
) -> SettingDefinition:
	"""Add a setting definition to the panel."""
	var setting_def: SettingDefinition = SettingDefinition.new()
	setting_def.key = key
	setting_def.display_name = display_name
	setting_def.setting_type = setting_type
	setting_def.default_value = default_value
	setting_def.description = description
	setting_def.category = category
	
	setting_definitions.append(setting_def)
	return setting_def

func add_boolean_setting(key: String, display_name: String, default_value: bool, category: String = "General") -> SettingDefinition:
	"""Add a boolean (checkbox) setting."""
	return add_setting(key, display_name, SettingType.BOOLEAN, default_value, "", category)

func add_integer_setting(key: String, display_name: String, default_value: int, min_value: int = 0, max_value: int = 100, category: String = "General") -> SettingDefinition:
	"""Add an integer setting with range validation."""
	var setting_def: SettingDefinition = add_setting(key, display_name, SettingType.INTEGER, default_value, "", category)
	setting_def.validation_type = ValidationType.RANGE
	setting_def.validation_data = Vector2i(min_value, max_value)
	return setting_def

func add_float_setting(key: String, display_name: String, default_value: float, min_value: float = 0.0, max_value: float = 1.0, category: String = "General") -> SettingDefinition:
	"""Add a float setting with range validation."""
	var setting_def: SettingDefinition = add_setting(key, display_name, SettingType.FLOAT, default_value, "", category)
	setting_def.validation_type = ValidationType.RANGE
	setting_def.validation_data = Vector2(min_value, max_value)
	return setting_def

func add_enum_setting(key: String, display_name: String, enum_values: Array[String], default_index: int = 0, category: String = "General") -> SettingDefinition:
	"""Add an enum (option button) setting."""
	var setting_def: SettingDefinition = add_setting(key, display_name, SettingType.ENUM, default_index, "", category)
	setting_def.enum_values = enum_values
	return setting_def

func add_string_setting(key: String, display_name: String, default_value: String = "", regex_pattern: String = "", category: String = "General") -> SettingDefinition:
	"""Add a string setting with optional regex validation."""
	var setting_def: SettingDefinition = add_setting(key, display_name, SettingType.STRING, default_value, "", category)
	if not regex_pattern.is_empty():
		setting_def.validation_type = ValidationType.REGEX
		setting_def.validation_data = regex_pattern
	return setting_def

func build_settings_ui() -> void:
	"""Build the settings UI from setting definitions."""
	if setting_definitions.is_empty():
		print("SettingsPanel: No settings defined")
		return
	
	# Group settings by category
	var categories: Dictionary = {}
	for setting_def: SettingDefinition in setting_definitions:
		if not categories.has(setting_def.category):
			categories[setting_def.category] = []
		categories[setting_def.category].append(setting_def)
	
	# Create UI for each category
	for category_name: String in categories:
		_create_category_ui(category_name, categories[category_name])
	
	# Load current values into controls
	_update_ui_from_values()

func _create_category_ui(category_name: String, settings: Array) -> void:
	"""Create UI for a category of settings."""
	var container: VBoxContainer
	
	if show_categories and category_tabs:
		# Create tab for category
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.name = category_name
		category_tabs.add_child(scroll)
		
		container = VBoxContainer.new()
		container.name = "SettingsContainer"
		container.add_theme_constant_override("separation", 8)
		scroll.add_child(container)
	else:
		# Use main settings container
		container = settings_container
		
		# Add category header if multiple categories
		if len(categories) > 1:
			var header: Label = Label.new()
			header.text = category_name
			header.add_theme_font_size_override("font_size", 16)
			if ui_theme_manager:
				header.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("blue_secondary"))
			container.add_child(header)
	
	# Create controls for each setting in category
	for setting_def in settings:
		_create_setting_control(setting_def as SettingDefinition, container)

func _create_setting_control(setting_def: SettingDefinition, parent: VBoxContainer) -> void:
	"""Create UI control for a specific setting."""
	# Create setting row container
	var row_container: HBoxContainer = HBoxContainer.new()
	row_container.name = "Row_" + setting_def.key
	row_container.add_theme_constant_override("separation", 10)
	parent.add_child(row_container)
	
	# Create label
	var label: Label = Label.new()
	label.text = setting_def.display_name
	label.custom_minimum_size.x = 150
	label.tooltip_text = setting_def.tooltip if not setting_def.tooltip.is_empty() else setting_def.description
	if ui_theme_manager:
		label.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("gray_light"))
	row_container.add_child(label)
	
	# Create appropriate control based on setting type
	var control: Control = _create_control_for_type(setting_def)
	if control:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_container.add_child(control)
		setting_controls[setting_def.key] = control
		
		# Setup control change signals
		_connect_control_signals(setting_def, control)

func _create_control_for_type(setting_def: SettingDefinition) -> Control:
	"""Create the appropriate control for a setting type."""
	match setting_def.setting_type:
		SettingType.BOOLEAN:
			return _create_checkbox_control(setting_def)
		SettingType.INTEGER:
			return _create_integer_control(setting_def)
		SettingType.FLOAT:
			return _create_float_control(setting_def)
		SettingType.STRING:
			return _create_string_control(setting_def)
		SettingType.ENUM:
			return _create_enum_control(setting_def)
		SettingType.RANGE:
			return _create_range_control(setting_def)
		SettingType.COLOR:
			return _create_color_control(setting_def)
		_:
			push_warning("SettingsPanel: Unsupported setting type: %s" % setting_def.setting_type)
			return null

func _create_checkbox_control(setting_def: SettingDefinition) -> CheckBox:
	"""Create checkbox control for boolean setting."""
	var checkbox: CheckBox = CheckBox.new()
	checkbox.button_pressed = setting_def.default_value as bool
	if ui_theme_manager:
		ui_theme_manager.apply_theme_to_control(checkbox)
	return checkbox

func _create_integer_control(setting_def: SettingDefinition) -> SpinBox:
	"""Create spin box control for integer setting."""
	var spinbox: SpinBox = SpinBox.new()
	spinbox.value = setting_def.default_value as int
	spinbox.step = 1.0
	
	if setting_def.validation_type == ValidationType.RANGE and setting_def.validation_data is Vector2i:
		var range_data: Vector2i = setting_def.validation_data as Vector2i
		spinbox.min_value = range_data.x
		spinbox.max_value = range_data.y
	
	if ui_theme_manager:
		ui_theme_manager.apply_theme_to_control(spinbox)
	return spinbox

func _create_float_control(setting_def: SettingDefinition) -> SpinBox:
	"""Create spin box control for float setting."""
	var spinbox: SpinBox = SpinBox.new()
	spinbox.value = setting_def.default_value as float
	spinbox.step = 0.1
	
	if setting_def.validation_type == ValidationType.RANGE and setting_def.validation_data is Vector2:
		var range_data: Vector2 = setting_def.validation_data as Vector2
		spinbox.min_value = range_data.x
		spinbox.max_value = range_data.y
	
	if ui_theme_manager:
		ui_theme_manager.apply_theme_to_control(spinbox)
	return spinbox

func _create_string_control(setting_def: SettingDefinition) -> LineEdit:
	"""Create line edit control for string setting."""
	var line_edit: LineEdit = LineEdit.new()
	line_edit.text = setting_def.default_value as String
	line_edit.placeholder_text = setting_def.description
	
	if ui_theme_manager:
		ui_theme_manager.apply_theme_to_control(line_edit)
	return line_edit

func _create_enum_control(setting_def: SettingDefinition) -> OptionButton:
	"""Create option button control for enum setting."""
	var option_button: OptionButton = OptionButton.new()
	
	for i in range(setting_def.enum_values.size()):
		option_button.add_item(setting_def.enum_values[i])
	
	option_button.selected = setting_def.default_value as int
	
	if ui_theme_manager:
		ui_theme_manager.apply_theme_to_control(option_button)
	return option_button

func _create_range_control(setting_def: SettingDefinition) -> HSlider:
	"""Create slider control for range setting."""
	var slider: HSlider = HSlider.new()
	slider.value = setting_def.default_value as float
	
	if setting_def.validation_type == ValidationType.RANGE and setting_def.validation_data is Vector2:
		var range_data: Vector2 = setting_def.validation_data as Vector2
		slider.min_value = range_data.x
		slider.max_value = range_data.y
	
	if ui_theme_manager:
		ui_theme_manager.apply_theme_to_control(slider)
	return slider

func _create_color_control(setting_def: SettingDefinition) -> ColorPicker:
	"""Create color picker control for color setting."""
	var color_picker: ColorPicker = ColorPicker.new()
	color_picker.color = setting_def.default_value as Color
	color_picker.edit_alpha = true
	
	if ui_theme_manager:
		ui_theme_manager.apply_theme_to_control(color_picker)
	return color_picker

func _connect_control_signals(setting_def: SettingDefinition, control: Control) -> void:
	"""Connect control change signals for a setting."""
	match setting_def.setting_type:
		SettingType.BOOLEAN:
			(control as CheckBox).toggled.connect(_on_setting_changed.bind(setting_def.key))
		SettingType.INTEGER, SettingType.FLOAT:
			(control as SpinBox).value_changed.connect(_on_setting_changed.bind(setting_def.key))
		SettingType.STRING:
			(control as LineEdit).text_changed.connect(_on_setting_changed.bind(setting_def.key))
		SettingType.ENUM:
			(control as OptionButton).item_selected.connect(_on_setting_changed.bind(setting_def.key))
		SettingType.RANGE:
			(control as HSlider).value_changed.connect(_on_setting_changed.bind(setting_def.key))
		SettingType.COLOR:
			(control as ColorPicker).color_changed.connect(_on_setting_changed.bind(setting_def.key))

# ============================================================================
# VALUE MANAGEMENT
# ============================================================================

func _update_ui_from_values() -> void:
	"""Update UI controls from current values."""
	for key: String in current_values:
		if setting_controls.has(key):
			_set_control_value(key, current_values[key])

func _set_control_value(key: String, value: Variant) -> void:
	"""Set control value for a specific setting."""
	var control: Control = setting_controls[key]
	var setting_def: SettingDefinition = _get_setting_definition(key)
	
	if not control or not setting_def:
		return
	
	match setting_def.setting_type:
		SettingType.BOOLEAN:
			(control as CheckBox).button_pressed = value as bool
		SettingType.INTEGER, SettingType.FLOAT, SettingType.RANGE:
			(control as Range).value = value as float
		SettingType.STRING:
			(control as LineEdit).text = value as String
		SettingType.ENUM:
			(control as OptionButton).selected = value as int
		SettingType.COLOR:
			(control as ColorPicker).color = value as Color

func _get_control_value(key: String) -> Variant:
	"""Get current value from control for a specific setting."""
	var control: Control = setting_controls[key]
	var setting_def: SettingDefinition = _get_setting_definition(key)
	
	if not control or not setting_def:
		return null
	
	match setting_def.setting_type:
		SettingType.BOOLEAN:
			return (control as CheckBox).button_pressed
		SettingType.INTEGER:
			return int((control as SpinBox).value)
		SettingType.FLOAT, SettingType.RANGE:
			return (control as Range).value
		SettingType.STRING:
			return (control as LineEdit).text
		SettingType.ENUM:
			return (control as OptionButton).selected
		SettingType.COLOR:
			return (control as ColorPicker).color
		_:
			return null

func _get_setting_definition(key: String) -> SettingDefinition:
	"""Get setting definition by key."""
	for setting_def: SettingDefinition in setting_definitions:
		if setting_def.key == key:
			return setting_def
	return null

# ============================================================================
# VALIDATION
# ============================================================================

func validate_setting(key: String, value: Variant) -> bool:
	"""Validate a setting value."""
	var setting_def: SettingDefinition = _get_setting_definition(key)
	if not setting_def:
		return false
	
	match setting_def.validation_type:
		ValidationType.NONE:
			return true
		ValidationType.RANGE:
			return _validate_range(value, setting_def.validation_data)
		ValidationType.REGEX:
			return _validate_regex(value as String, setting_def.validation_data as String)
		ValidationType.FILE_EXISTS:
			return _validate_file_exists(value as String)
		ValidationType.DIR_EXISTS:
			return _validate_dir_exists(value as String)
		ValidationType.CUSTOM:
			if setting_def.validation_data is Callable:
				return (setting_def.validation_data as Callable).call(value)
			return true
		_:
			return true

func _validate_range(value: Variant, range_data: Variant) -> bool:
	"""Validate numeric range."""
	if range_data is Vector2:
		var range_vec: Vector2 = range_data as Vector2
		var num_value: float = value as float
		return num_value >= range_vec.x and num_value <= range_vec.y
	elif range_data is Vector2i:
		var range_vec: Vector2i = range_data as Vector2i
		var num_value: int = value as int
		return num_value >= range_vec.x and num_value <= range_vec.y
	return false

func _validate_regex(value: String, pattern: String) -> bool:
	"""Validate string against regex pattern."""
	var regex: RegEx = RegEx.new()
	regex.compile(pattern)
	return regex.search(value) != null

func _validate_file_exists(path: String) -> bool:
	"""Validate file exists."""
	return FileAccess.file_exists(path)

func _validate_dir_exists(path: String) -> bool:
	"""Validate directory exists."""
	return DirAccess.dir_exists_absolute(path)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_setting_changed(key: String, new_value: Variant) -> void:
	"""Handle setting value change."""
	var old_value: Variant = current_values.get(key, null)
	
	# Validate new value
	if not validate_setting(key, new_value):
		validation_failed.emit(key, "Invalid value for setting: %s" % key)
		# Revert to previous value
		_set_control_value(key, old_value)
		return
	
	# Update current values
	current_values[key] = new_value
	has_unsaved_changes = true
	
	# Update button states
	_update_button_states()
	
	# Emit change signal
	setting_changed.emit(key, old_value, new_value)
	
	# Auto-apply if enabled
	if auto_apply_changes:
		_apply_settings()

func _on_apply_pressed() -> void:
	"""Handle apply button press."""
	_apply_settings()

func _on_reset_pressed() -> void:
	"""Handle reset button press."""
	if confirm_reset:
		var dialog: DialogModal = DialogModal.show_confirmation_dialog(
			get_parent(),
			"Reset Settings",
			"Reset all settings to default values?",
			_on_reset_confirmed
		)
	else:
		_reset_settings()

func _on_reset_confirmed(confirmed: bool, data: Dictionary) -> void:
	"""Handle reset confirmation."""
	if confirmed:
		_reset_settings()

func _on_cancel_pressed() -> void:
	"""Handle cancel button press."""
	if has_unsaved_changes:
		var dialog: DialogModal = DialogModal.show_confirmation_dialog(
			get_parent(),
			"Unsaved Changes",
			"Discard unsaved changes?",
			_on_cancel_confirmed
		)
	else:
		_cancel_changes()

func _on_cancel_confirmed(confirmed: bool, data: Dictionary) -> void:
	"""Handle cancel confirmation."""
	if confirmed:
		_cancel_changes()

func _on_theme_changed(theme_name: String) -> void:
	"""Handle theme changes."""
	_setup_panel_styling()

# ============================================================================
# SETTINGS OPERATIONS
# ============================================================================

func _apply_settings() -> void:
	"""Apply current settings to ConfigurationManager."""
	if not ConfigurationManager or not ConfigurationManager.has_method("set_setting"):
		push_warning("SettingsPanel: ConfigurationManager not available")
		return
	
	for key: String in current_values:
		ConfigurationManager.set_setting(key, current_values[key])
	
	# Update original values
	original_values = current_values.duplicate()
	has_unsaved_changes = false
	
	_update_button_states()
	settings_applied.emit()
	
	print("SettingsPanel: Settings applied")

func _reset_settings() -> void:
	"""Reset all settings to default values."""
	for setting_def: SettingDefinition in setting_definitions:
		current_values[setting_def.key] = setting_def.default_value
	
	_update_ui_from_values()
	has_unsaved_changes = true
	_update_button_states()
	
	settings_reset.emit()
	print("SettingsPanel: Settings reset to defaults")

func _cancel_changes() -> void:
	"""Cancel changes and revert to original values."""
	current_values = original_values.duplicate()
	_update_ui_from_values()
	has_unsaved_changes = false
	_update_button_states()

func _update_button_states() -> void:
	"""Update button enabled/disabled states."""
	if apply_button:
		apply_button.disabled = not has_unsaved_changes
	
	if reset_button:
		reset_button.disabled = false  # Always allow reset

# ============================================================================
# PUBLIC API
# ============================================================================

func has_changes() -> bool:
	"""Check if there are unsaved changes."""
	return has_unsaved_changes

func get_setting_value(key: String) -> Variant:
	"""Get current value for a setting."""
	return current_values.get(key, null)

func set_setting_value(key: String, value: Variant) -> bool:
	"""Set value for a setting."""
	if validate_setting(key, value):
		current_values[key] = value
		_set_control_value(key, value)
		has_unsaved_changes = true
		_update_button_states()
		return true
	return false

func clear_all_settings() -> void:
	"""Clear all setting definitions and controls."""
	setting_definitions.clear()
	setting_controls.clear()
	current_values.clear()
	original_values.clear()
	
	# Clear UI
	if settings_container:
		for child in settings_container.get_children():
			child.queue_free()
	if category_tabs:
		for child in category_tabs.get_children():
			child.queue_free()

func get_categories() -> Array[String]:
	"""Get list of setting categories."""
	var categories: Array[String] = []
	for setting_def: SettingDefinition in setting_definitions:
		if not categories.has(setting_def.category):
			categories.append(setting_def.category)
	return categories