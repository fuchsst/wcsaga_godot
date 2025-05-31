@tool
class_name EnvironmentEditorPanel
extends Control

## Environment configuration editor for GFRED2-010 Mission Component Editors.
## Scene-based UI controller for asteroid fields, starfields, and environmental effects.
## Scene: addons/gfred2/scenes/dialogs/component_editors/environment_editor_panel.tscn

signal environment_updated(environment_data: EnvironmentData)
signal validation_changed(is_valid: bool, errors: Array[String])
signal preview_updated()

# Current mission and environment data
var current_mission_data: MissionData = null
var environment_data: EnvironmentData = null

# Scene node references
@onready var environment_tabs: TabContainer = $VBoxContainer/EnvironmentTabs

# Asteroid field tab
@onready var asteroid_enabled_check: CheckBox = $VBoxContainer/EnvironmentTabs/AsteroidField/AsteroidEnabledCheck
@onready var asteroid_density_spin: SpinBox = $VBoxContainer/EnvironmentTabs/AsteroidField/PropertiesContainer/DensitySpin
@onready var asteroid_size_min_spin: SpinBox = $VBoxContainer/EnvironmentTabs/AsteroidField/PropertiesContainer/SizeMinSpin
@onready var asteroid_size_max_spin: SpinBox = $VBoxContainer/EnvironmentTabs/AsteroidField/PropertiesContainer/SizeMaxSpin
@onready var asteroid_composition_option: OptionButton = $VBoxContainer/EnvironmentTabs/AsteroidField/PropertiesContainer/CompositionOption
@onready var asteroid_debris_check: CheckBox = $VBoxContainer/EnvironmentTabs/AsteroidField/PropertiesContainer/DebrisCheck
@onready var asteroid_hazard_level_spin: SpinBox = $VBoxContainer/EnvironmentTabs/AsteroidField/PropertiesContainer/HazardLevelSpin

# Starfield tab
@onready var starfield_enabled_check: CheckBox = $VBoxContainer/EnvironmentTabs/Starfield/StarfieldEnabledCheck
@onready var star_density_spin: SpinBox = $VBoxContainer/EnvironmentTabs/Starfield/PropertiesContainer/StarDensitySpin
@onready var star_brightness_spin: SpinBox = $VBoxContainer/EnvironmentTabs/Starfield/PropertiesContainer/StarBrightnessSpin
@onready var star_color_tint_picker: ColorPicker = $VBoxContainer/EnvironmentTabs/Starfield/PropertiesContainer/StarColorTintPicker
@onready var background_bitmap_edit: LineEdit = $VBoxContainer/EnvironmentTabs/Starfield/PropertiesContainer/BackgroundBitmapEdit
@onready var browse_background_button: Button = $VBoxContainer/EnvironmentTabs/Starfield/PropertiesContainer/BrowseBackgroundButton

# Nebula tab
@onready var nebula_enabled_check: CheckBox = $VBoxContainer/EnvironmentTabs/Nebula/NebulaEnabledCheck
@onready var nebula_density_spin: SpinBox = $VBoxContainer/EnvironmentTabs/Nebula/PropertiesContainer/NebulaDensitySpin
@onready var nebula_color_picker: ColorPicker = $VBoxContainer/EnvironmentTabs/Nebula/PropertiesContainer/NebulaColorPicker
@onready var nebula_lightning_check: CheckBox = $VBoxContainer/EnvironmentTabs/Nebula/PropertiesContainer/NebulaLightningCheck
@onready var lightning_frequency_spin: SpinBox = $VBoxContainer/EnvironmentTabs/Nebula/PropertiesContainer/LightningFrequencySpin
@onready var sensor_range_spin: SpinBox = $VBoxContainer/EnvironmentTabs/Nebula/PropertiesContainer/SensorRangeSpin

# Jump nodes tab
@onready var jump_nodes_list: ItemList = $VBoxContainer/EnvironmentTabs/JumpNodes/JumpNodesList
@onready var add_jump_node_button: Button = $VBoxContainer/EnvironmentTabs/JumpNodes/ButtonContainer/AddJumpNodeButton
@onready var remove_jump_node_button: Button = $VBoxContainer/EnvironmentTabs/JumpNodes/ButtonContainer/RemoveJumpNodeButton
@onready var jump_node_name_edit: LineEdit = $VBoxContainer/EnvironmentTabs/JumpNodes/PropertiesContainer/JumpNodeNameEdit
@onready var jump_node_pos_x_spin: SpinBox = $VBoxContainer/EnvironmentTabs/JumpNodes/PropertiesContainer/PosXSpin
@onready var jump_node_pos_y_spin: SpinBox = $VBoxContainer/EnvironmentTabs/JumpNodes/PropertiesContainer/PosYSpin
@onready var jump_node_pos_z_spin: SpinBox = $VBoxContainer/EnvironmentTabs/JumpNodes/PropertiesContainer/PosZSpin

# Preview
@onready var environment_preview: EnvironmentPreview3D = $VBoxContainer/PreviewContainer/EnvironmentPreview3D
@onready var update_preview_button: Button = $VBoxContainer/PreviewContainer/UpdatePreviewButton
@onready var auto_update_check: CheckBox = $VBoxContainer/PreviewContainer/AutoUpdateCheck

# File dialog for background images
@onready var background_file_dialog: FileDialog = $BackgroundFileDialog

# Selected jump node
var selected_jump_node_index: int = -1

# Asteroid composition types
var asteroid_compositions: Array[String] = [
	"Rock",
	"Ice",
	"Metal",
	"Mixed",
	"Debris"
]

func _ready() -> void:
	name = "EnvironmentEditorPanel"
	
	# Initialize environment data
	environment_data = EnvironmentData.new()
	
	# Setup UI components
	_setup_asteroid_options()
	_setup_property_editors()
	_setup_file_dialog()
	_setup_preview()
	_connect_signals()
	
	# Initialize UI state
	_update_ui_from_data()
	
	print("EnvironmentEditorPanel: Environment editor initialized")

## Initializes the editor with mission data
func initialize_with_mission(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	current_mission_data = mission_data
	
	# Load existing environment data from mission
	if mission_data.has_method("get_environment_data"):
		environment_data = mission_data.get_environment_data()
	else:
		environment_data = EnvironmentData.new()
	
	# Update UI with loaded data
	_update_ui_from_data()
	
	# Update preview
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()
	
	print("EnvironmentEditorPanel: Initialized with environment data")

func _setup_asteroid_options() -> void:
	if not asteroid_composition_option:
		return
	
	asteroid_composition_option.clear()
	for composition in asteroid_compositions:
		asteroid_composition_option.add_item(composition)

func _setup_property_editors() -> void:
	# Setup numeric controls
	if asteroid_density_spin:
		asteroid_density_spin.min_value = 0.0
		asteroid_density_spin.max_value = 1.0
		asteroid_density_spin.step = 0.01
	
	if asteroid_size_min_spin:
		asteroid_size_min_spin.min_value = 1.0
		asteroid_size_min_spin.max_value = 1000.0
	
	if asteroid_size_max_spin:
		asteroid_size_max_spin.min_value = 1.0
		asteroid_size_max_spin.max_value = 1000.0
	
	if asteroid_hazard_level_spin:
		asteroid_hazard_level_spin.min_value = 0
		asteroid_hazard_level_spin.max_value = 10
	
	if star_density_spin:
		star_density_spin.min_value = 0.0
		star_density_spin.max_value = 2.0
		star_density_spin.step = 0.1
	
	if star_brightness_spin:
		star_brightness_spin.min_value = 0.0
		star_brightness_spin.max_value = 2.0
		star_brightness_spin.step = 0.1
	
	if nebula_density_spin:
		nebula_density_spin.min_value = 0.0
		nebula_density_spin.max_value = 1.0
		nebula_density_spin.step = 0.01
	
	if lightning_frequency_spin:
		lightning_frequency_spin.min_value = 0.0
		lightning_frequency_spin.max_value = 10.0
		lightning_frequency_spin.step = 0.1
	
	if sensor_range_spin:
		sensor_range_spin.min_value = 100.0
		sensor_range_spin.max_value = 10000.0
		sensor_range_spin.step = 100.0
	
	# Setup position controls for jump nodes
	for spin in [jump_node_pos_x_spin, jump_node_pos_y_spin, jump_node_pos_z_spin]:
		if spin:
			spin.min_value = -50000.0
			spin.max_value = 50000.0
			spin.step = 1.0

func _setup_file_dialog() -> void:
	if not background_file_dialog:
		return
	
	background_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	background_file_dialog.access = FileDialog.ACCESS_RESOURCES
	background_file_dialog.add_filter("*.jpg", "JPEG Images")
	background_file_dialog.add_filter("*.png", "PNG Images")
	background_file_dialog.add_filter("*.dds", "DDS Textures")
	background_file_dialog.file_selected.connect(_on_background_file_selected)

func _setup_preview() -> void:
	if auto_update_check:
		auto_update_check.button_pressed = true

func _connect_signals() -> void:
	# Asteroid field signals
	if asteroid_enabled_check:
		asteroid_enabled_check.toggled.connect(_on_asteroid_enabled_toggled)
	if asteroid_density_spin:
		asteroid_density_spin.value_changed.connect(_on_asteroid_density_changed)
	if asteroid_size_min_spin:
		asteroid_size_min_spin.value_changed.connect(_on_asteroid_size_min_changed)
	if asteroid_size_max_spin:
		asteroid_size_max_spin.value_changed.connect(_on_asteroid_size_max_changed)
	if asteroid_composition_option:
		asteroid_composition_option.item_selected.connect(_on_asteroid_composition_selected)
	if asteroid_debris_check:
		asteroid_debris_check.toggled.connect(_on_asteroid_debris_toggled)
	if asteroid_hazard_level_spin:
		asteroid_hazard_level_spin.value_changed.connect(_on_asteroid_hazard_level_changed)
	
	# Starfield signals
	if starfield_enabled_check:
		starfield_enabled_check.toggled.connect(_on_starfield_enabled_toggled)
	if star_density_spin:
		star_density_spin.value_changed.connect(_on_star_density_changed)
	if star_brightness_spin:
		star_brightness_spin.value_changed.connect(_on_star_brightness_changed)
	if star_color_tint_picker:
		star_color_tint_picker.color_changed.connect(_on_star_color_tint_changed)
	if background_bitmap_edit:
		background_bitmap_edit.text_changed.connect(_on_background_bitmap_changed)
	if browse_background_button:
		browse_background_button.pressed.connect(_on_browse_background_pressed)
	
	# Nebula signals
	if nebula_enabled_check:
		nebula_enabled_check.toggled.connect(_on_nebula_enabled_toggled)
	if nebula_density_spin:
		nebula_density_spin.value_changed.connect(_on_nebula_density_changed)
	if nebula_color_picker:
		nebula_color_picker.color_changed.connect(_on_nebula_color_changed)
	if nebula_lightning_check:
		nebula_lightning_check.toggled.connect(_on_nebula_lightning_toggled)
	if lightning_frequency_spin:
		lightning_frequency_spin.value_changed.connect(_on_lightning_frequency_changed)
	if sensor_range_spin:
		sensor_range_spin.value_changed.connect(_on_sensor_range_changed)
	
	# Jump nodes signals
	if jump_nodes_list:
		jump_nodes_list.item_selected.connect(_on_jump_node_selected)
	if add_jump_node_button:
		add_jump_node_button.pressed.connect(_on_add_jump_node_pressed)
	if remove_jump_node_button:
		remove_jump_node_button.pressed.connect(_on_remove_jump_node_pressed)
	if jump_node_name_edit:
		jump_node_name_edit.text_changed.connect(_on_jump_node_name_changed)
	if jump_node_pos_x_spin:
		jump_node_pos_x_spin.value_changed.connect(_on_jump_node_pos_x_changed)
	if jump_node_pos_y_spin:
		jump_node_pos_y_spin.value_changed.connect(_on_jump_node_pos_y_changed)
	if jump_node_pos_z_spin:
		jump_node_pos_z_spin.value_changed.connect(_on_jump_node_pos_z_changed)
	
	# Preview signals
	if update_preview_button:
		update_preview_button.pressed.connect(_on_update_preview_pressed)
	if auto_update_check:
		auto_update_check.toggled.connect(_on_auto_update_toggled)

func _update_ui_from_data() -> void:
	if not environment_data:
		return
	
	# Update asteroid field UI
	if asteroid_enabled_check:
		asteroid_enabled_check.button_pressed = environment_data.asteroid_field_enabled
	if asteroid_density_spin:
		asteroid_density_spin.value = environment_data.asteroid_density
	if asteroid_size_min_spin:
		asteroid_size_min_spin.value = environment_data.asteroid_size_min
	if asteroid_size_max_spin:
		asteroid_size_max_spin.value = environment_data.asteroid_size_max
	if asteroid_composition_option:
		var composition_index: int = asteroid_compositions.find(environment_data.asteroid_composition)
		if composition_index >= 0:
			asteroid_composition_option.selected = composition_index
	if asteroid_debris_check:
		asteroid_debris_check.button_pressed = environment_data.asteroid_debris_enabled
	if asteroid_hazard_level_spin:
		asteroid_hazard_level_spin.value = environment_data.asteroid_hazard_level
	
	# Update starfield UI
	if starfield_enabled_check:
		starfield_enabled_check.button_pressed = environment_data.starfield_enabled
	if star_density_spin:
		star_density_spin.value = environment_data.star_density
	if star_brightness_spin:
		star_brightness_spin.value = environment_data.star_brightness
	if star_color_tint_picker:
		star_color_tint_picker.color = environment_data.star_color_tint
	if background_bitmap_edit:
		background_bitmap_edit.text = environment_data.background_bitmap
	
	# Update nebula UI
	if nebula_enabled_check:
		nebula_enabled_check.button_pressed = environment_data.nebula_enabled
	if nebula_density_spin:
		nebula_density_spin.value = environment_data.nebula_density
	if nebula_color_picker:
		nebula_color_picker.color = environment_data.nebula_color
	if nebula_lightning_check:
		nebula_lightning_check.button_pressed = environment_data.nebula_lightning_enabled
	if lightning_frequency_spin:
		lightning_frequency_spin.value = environment_data.lightning_frequency
	if sensor_range_spin:
		sensor_range_spin.value = environment_data.sensor_range
	
	# Update jump nodes list
	_populate_jump_nodes_list()

func _populate_jump_nodes_list() -> void:
	if not jump_nodes_list or not environment_data:
		return
	
	jump_nodes_list.clear()
	
	for i in range(environment_data.jump_nodes.size()):
		var jump_node: JumpNodeData = environment_data.jump_nodes[i]
		var display_text: String = "%s (%.1f, %.1f, %.1f)" % [jump_node.name, jump_node.position.x, jump_node.position.y, jump_node.position.z]
		jump_nodes_list.add_item(display_text)

func _update_jump_node_properties() -> void:
	var has_selection: bool = selected_jump_node_index >= 0 and selected_jump_node_index < environment_data.jump_nodes.size()
	
	if not has_selection:
		# Clear jump node property inputs
		if jump_node_name_edit:
			jump_node_name_edit.text = ""
		if jump_node_pos_x_spin:
			jump_node_pos_x_spin.value = 0.0
		if jump_node_pos_y_spin:
			jump_node_pos_y_spin.value = 0.0
		if jump_node_pos_z_spin:
			jump_node_pos_z_spin.value = 0.0
		return
	
	# Update jump node property inputs
	var jump_node: JumpNodeData = environment_data.jump_nodes[selected_jump_node_index]
	if jump_node_name_edit:
		jump_node_name_edit.text = jump_node.name
	if jump_node_pos_x_spin:
		jump_node_pos_x_spin.value = jump_node.position.x
	if jump_node_pos_y_spin:
		jump_node_pos_y_spin.value = jump_node.position.y
	if jump_node_pos_z_spin:
		jump_node_pos_z_spin.value = jump_node.position.z

func _update_preview() -> void:
	if environment_preview:
		environment_preview.update_environment(environment_data)
		preview_updated.emit()

## Signal handlers

# Asteroid field handlers
func _on_asteroid_enabled_toggled(enabled: bool) -> void:
	environment_data.asteroid_field_enabled = enabled
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_asteroid_density_changed(value: float) -> void:
	environment_data.asteroid_density = value
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_asteroid_size_min_changed(value: float) -> void:
	environment_data.asteroid_size_min = value
	# Ensure min <= max
	if asteroid_size_max_spin and value > asteroid_size_max_spin.value:
		asteroid_size_max_spin.value = value
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_asteroid_size_max_changed(value: float) -> void:
	environment_data.asteroid_size_max = value
	# Ensure min <= max
	if asteroid_size_min_spin and value < asteroid_size_min_spin.value:
		asteroid_size_min_spin.value = value
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_asteroid_composition_selected(index: int) -> void:
	if index >= 0 and index < asteroid_compositions.size():
		environment_data.asteroid_composition = asteroid_compositions[index]
		environment_updated.emit(environment_data)
		if auto_update_check and auto_update_check.button_pressed:
			_update_preview()

func _on_asteroid_debris_toggled(enabled: bool) -> void:
	environment_data.asteroid_debris_enabled = enabled
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_asteroid_hazard_level_changed(value: float) -> void:
	environment_data.asteroid_hazard_level = int(value)
	environment_updated.emit(environment_data)

# Starfield handlers
func _on_starfield_enabled_toggled(enabled: bool) -> void:
	environment_data.starfield_enabled = enabled
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_star_density_changed(value: float) -> void:
	environment_data.star_density = value
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_star_brightness_changed(value: float) -> void:
	environment_data.star_brightness = value
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_star_color_tint_changed(color: Color) -> void:
	environment_data.star_color_tint = color
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_background_bitmap_changed(new_text: String) -> void:
	environment_data.background_bitmap = new_text
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_browse_background_pressed() -> void:
	if background_file_dialog:
		background_file_dialog.popup_centered(Vector2i(800, 600))

func _on_background_file_selected(file_path: String) -> void:
	if background_bitmap_edit:
		background_bitmap_edit.text = file_path
		_on_background_bitmap_changed(file_path)

# Nebula handlers
func _on_nebula_enabled_toggled(enabled: bool) -> void:
	environment_data.nebula_enabled = enabled
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_nebula_density_changed(value: float) -> void:
	environment_data.nebula_density = value
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_nebula_color_changed(color: Color) -> void:
	environment_data.nebula_color = color
	environment_updated.emit(environment_data)
	if auto_update_check and auto_update_check.button_pressed:
		_update_preview()

func _on_nebula_lightning_toggled(enabled: bool) -> void:
	environment_data.nebula_lightning_enabled = enabled
	environment_updated.emit(environment_data)

func _on_lightning_frequency_changed(value: float) -> void:
	environment_data.lightning_frequency = value
	environment_updated.emit(environment_data)

func _on_sensor_range_changed(value: float) -> void:
	environment_data.sensor_range = value
	environment_updated.emit(environment_data)

# Jump nodes handlers
func _on_jump_node_selected(index: int) -> void:
	selected_jump_node_index = index
	_update_jump_node_properties()

func _on_add_jump_node_pressed() -> void:
	var new_jump_node: JumpNodeData = JumpNodeData.new()
	new_jump_node.name = "Jump Node %d" % (environment_data.jump_nodes.size() + 1)
	new_jump_node.position = Vector3.ZERO
	
	environment_data.jump_nodes.append(new_jump_node)
	_populate_jump_nodes_list()
	
	# Select the new jump node
	if jump_nodes_list:
		jump_nodes_list.select(environment_data.jump_nodes.size() - 1)
		_on_jump_node_selected(environment_data.jump_nodes.size() - 1)
	
	environment_updated.emit(environment_data)

func _on_remove_jump_node_pressed() -> void:
	if selected_jump_node_index >= 0 and selected_jump_node_index < environment_data.jump_nodes.size():
		environment_data.jump_nodes.remove_at(selected_jump_node_index)
		selected_jump_node_index = -1
		_populate_jump_nodes_list()
		_update_jump_node_properties()
		environment_updated.emit(environment_data)

func _on_jump_node_name_changed(new_text: String) -> void:
	if selected_jump_node_index >= 0 and selected_jump_node_index < environment_data.jump_nodes.size():
		environment_data.jump_nodes[selected_jump_node_index].name = new_text
		_populate_jump_nodes_list()  # Refresh display
		environment_updated.emit(environment_data)

func _on_jump_node_pos_x_changed(value: float) -> void:
	if selected_jump_node_index >= 0 and selected_jump_node_index < environment_data.jump_nodes.size():
		environment_data.jump_nodes[selected_jump_node_index].position.x = value
		_populate_jump_nodes_list()
		environment_updated.emit(environment_data)

func _on_jump_node_pos_y_changed(value: float) -> void:
	if selected_jump_node_index >= 0 and selected_jump_node_index < environment_data.jump_nodes.size():
		environment_data.jump_nodes[selected_jump_node_index].position.y = value
		_populate_jump_nodes_list()
		environment_updated.emit(environment_data)

func _on_jump_node_pos_z_changed(value: float) -> void:
	if selected_jump_node_index >= 0 and selected_jump_node_index < environment_data.jump_nodes.size():
		environment_data.jump_nodes[selected_jump_node_index].position.z = value
		_populate_jump_nodes_list()
		environment_updated.emit(environment_data)

# Preview handlers
func _on_update_preview_pressed() -> void:
	_update_preview()

func _on_auto_update_toggled(enabled: bool) -> void:
	if enabled:
		_update_preview()

## Validation and export methods

func validate_component() -> Dictionary:
	var errors: Array[String] = []
	
	if not environment_data:
		errors.append("Environment data is null")
		return {"is_valid": false, "errors": errors}
	
	# Validate asteroid field
	if environment_data.asteroid_field_enabled:
		if environment_data.asteroid_density < 0.0 or environment_data.asteroid_density > 1.0:
			errors.append("Asteroid density must be between 0.0 and 1.0")
		
		if environment_data.asteroid_size_min > environment_data.asteroid_size_max:
			errors.append("Asteroid minimum size cannot be greater than maximum size")
		
		if environment_data.asteroid_hazard_level < 0 or environment_data.asteroid_hazard_level > 10:
			errors.append("Asteroid hazard level must be between 0 and 10")
	
	# Validate starfield
	if environment_data.starfield_enabled:
		if environment_data.star_density < 0.0:
			errors.append("Star density cannot be negative")
		
		if environment_data.star_brightness < 0.0:
			errors.append("Star brightness cannot be negative")
		
		if not environment_data.background_bitmap.is_empty() and not FileAccess.file_exists(environment_data.background_bitmap):
			errors.append("Background bitmap file does not exist: %s" % environment_data.background_bitmap)
	
	# Validate nebula
	if environment_data.nebula_enabled:
		if environment_data.nebula_density < 0.0 or environment_data.nebula_density > 1.0:
			errors.append("Nebula density must be between 0.0 and 1.0")
		
		if environment_data.lightning_frequency < 0.0:
			errors.append("Lightning frequency cannot be negative")
		
		if environment_data.sensor_range <= 0.0:
			errors.append("Sensor range must be greater than 0")
	
	# Validate jump nodes
	for i in range(environment_data.jump_nodes.size()):
		var jump_node: JumpNodeData = environment_data.jump_nodes[i]
		if jump_node.name.is_empty():
			errors.append("Jump node %d: Name cannot be empty" % (i + 1))
	
	var is_valid: bool = errors.is_empty()
	validation_changed.emit(is_valid, errors)
	
	return {"is_valid": is_valid, "errors": errors}

func apply_changes(mission_data: MissionData) -> void:
	if not mission_data or not environment_data:
		return
	
	# Apply environment data to mission
	if mission_data.has_method("set_environment_data"):
		mission_data.set_environment_data(environment_data)
	
	print("EnvironmentEditorPanel: Applied environment data to mission")

func export_component() -> Dictionary:
	return {
		"environment": environment_data,
		"asteroid_field_enabled": environment_data.asteroid_field_enabled,
		"starfield_enabled": environment_data.starfield_enabled,
		"nebula_enabled": environment_data.nebula_enabled,
		"jump_node_count": environment_data.jump_nodes.size()
	}

## Gets current environment data
func get_environment_data() -> EnvironmentData:
	return environment_data

## Forces preview update
func force_preview_update() -> void:
	_update_preview()