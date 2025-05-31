@tool
class_name AdvancedShipConfigurationDialog
extends AcceptDialog

## Advanced ship configuration dialog for GFRED2-009 Advanced Ship Configuration.
## Scene-based UI controller implementing mandatory scene-based architecture.
## Scene: addons/gfred2/scenes/dialogs/ship_editor/advanced_ship_configuration_dialog.tscn

signal ship_configuration_updated(config: ShipConfigurationData)
signal batch_edit_started(ship_ids: Array[String])
signal batch_edit_completed()
signal configuration_template_applied(template_name: String)

# Core references
var ship_config_manager: ShipConfigurationManager = null
var current_configuration: ShipConfigurationData = null
var is_batch_editing: bool = false
var batch_ship_ids: Array[String] = []

# Scene node references (populated by .tscn file)
@onready var main_container: VBoxContainer = $VBoxContainer
@onready var tab_container: TabContainer = $VBoxContainer/MainTabContainer

# Tab panels (these are scene instances from .tscn)
@onready var basic_properties_panel: Control = $VBoxContainer/MainTabContainer/BasicProperties
@onready var ai_behavior_panel: Control = $VBoxContainer/MainTabContainer/AIBehavior
@onready var weapon_loadouts_panel: Control = $VBoxContainer/MainTabContainer/WeaponLoadouts
@onready var damage_system_panel: Control = $VBoxContainer/MainTabContainer/DamageSystem
@onready var hitpoints_panel: Control = $VBoxContainer/MainTabContainer/Hitpoints
@onready var ship_flags_panel: Control = $VBoxContainer/MainTabContainer/ShipFlags
@onready var texture_replacement_panel: Control = $VBoxContainer/MainTabContainer/TextureReplacement
@onready var ship_preview_panel: Control = $VBoxContainer/MainTabContainer/ShipPreview

# Dialog control buttons
@onready var apply_button: Button = $VBoxContainer/DialogButtons/ApplyButton
@onready var reset_button: Button = $VBoxContainer/DialogButtons/ResetButton
@onready var template_button: MenuButton = $VBoxContainer/DialogButtons/TemplateButton
@onready var batch_edit_button: Button = $VBoxContainer/DialogButtons/BatchEditButton

# Validation indicator
@onready var validation_indicator: Control = $VBoxContainer/ValidationStatus/ValidationIndicator
@onready var validation_status_label: Label = $VBoxContainer/ValidationStatus/StatusLabel

# Performance requirements tracking
var dialog_instantiation_time: int = 0
var last_ui_update_time: int = 0

func _ready() -> void:
	name = "AdvancedShipConfigurationDialog"
	title = "Advanced Ship Configuration"
	size = Vector2i(1200, 800)
	
	# Track instantiation performance (requirement: < 16ms)
	dialog_instantiation_time = Time.get_ticks_msec()
	
	# Initialize manager
	ship_config_manager = ShipConfigurationManager.new()
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Setup initial UI state
	_setup_initial_ui_state()
	
	# Setup template menu
	_setup_template_menu()
	
	print("AdvancedShipConfigurationDialog: Dialog instantiated in %d ms" % (Time.get_ticks_msec() - dialog_instantiation_time))

## Sets up the ship configuration dialog with target configuration
func setup_ship_configuration(ship_config: ShipConfigurationData, batch_mode: bool = false, ship_ids: Array[String] = []) -> void:
	current_configuration = ship_config
	is_batch_editing = batch_mode
	batch_ship_ids = ship_ids.duplicate()
	
	if is_batch_editing:
		title = "Advanced Ship Configuration - Batch Edit (%d ships)" % batch_ship_ids.size()
		batch_edit_button.text = "End Batch Edit"
	else:
		title = "Advanced Ship Configuration - %s" % current_configuration.ship_name
		batch_edit_button.text = "Start Batch Edit"
	
	# Update all panels with configuration data
	_update_all_panels()
	
	# Enable/disable UI based on batch mode
	_update_batch_edit_ui()

## Connects all UI signal handlers
func _connect_ui_signals() -> void:
	# Dialog buttons
	apply_button.pressed.connect(_on_apply_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	batch_edit_button.pressed.connect(_on_batch_edit_pressed)
	
	# Tab container
	tab_container.tab_changed.connect(_on_tab_changed)
	
	# Ship configuration manager signals
	if ship_config_manager:
		ship_config_manager.configuration_updated.connect(_on_configuration_updated)
		ship_config_manager.validation_status_changed.connect(_on_validation_status_changed)
		ship_config_manager.batch_edit_started.connect(_on_batch_edit_started)
		ship_config_manager.batch_edit_completed.connect(_on_batch_edit_completed)

## Sets up initial UI state
func _setup_initial_ui_state() -> void:
	# Initialize validation status
	validation_status_label.text = "Ready"
	validation_indicator.visible = false
	
	# Set initial tab
	tab_container.current_tab = 0
	
	# Configure dialog buttons
	apply_button.text = "Apply Changes"
	reset_button.text = "Reset to Default"
	batch_edit_button.text = "Start Batch Edit"

## Sets up template menu
func _setup_template_menu() -> void:
	var template_popup: PopupMenu = template_button.get_popup()
	template_popup.clear()
	
	# Add configuration templates
	template_popup.add_item("Fighter Template", 0)
	template_popup.add_item("Bomber Template", 1)
	template_popup.add_item("Capital Ship Template", 2)
	template_popup.add_item("Transport Template", 3)
	template_popup.add_separator()
	template_popup.add_item("Custom Template...", 4)
	
	template_popup.id_pressed.connect(_on_template_selected)

## Updates all panel components with current configuration
func _update_all_panels() -> void:
	if not current_configuration:
		return
	
	var start_time: int = Time.get_ticks_msec()
	
	# Update each panel with configuration data
	_update_basic_properties_panel()
	_update_ai_behavior_panel()
	_update_weapon_loadouts_panel()
	_update_damage_system_panel()
	_update_hitpoints_panel()
	_update_ship_flags_panel()
	_update_texture_replacement_panel()
	_update_ship_preview_panel()
	
	# Update validation status
	_validate_current_configuration()
	
	var update_time: int = Time.get_ticks_msec() - start_time
	last_ui_update_time = update_time
	
	# Performance requirement: UI updates should maintain 60+ FPS (< 16ms)
	if update_time > 16:
		print("AdvancedShipConfigurationDialog: UI update took %d ms (> 16ms threshold)" % update_time)

## Updates basic properties panel
func _update_basic_properties_panel() -> void:
	if not basic_properties_panel:
		return
	
	# Get panel controller and update with configuration
	var controller: BasicPropertiesController = basic_properties_panel.get_script() as BasicPropertiesController
	if controller:
		controller.update_with_configuration(current_configuration)

## Updates AI behavior panel
func _update_ai_behavior_panel() -> void:
	if not ai_behavior_panel:
		return
	
	var controller: AIBehaviorController = ai_behavior_panel.get_script() as AIBehaviorController
	if controller:
		controller.update_with_ai_config(current_configuration.ai_behavior)

## Updates weapon loadouts panel
func _update_weapon_loadouts_panel() -> void:
	if not weapon_loadouts_panel:
		return
	
	var controller: WeaponLoadoutsController = weapon_loadouts_panel.get_script() as WeaponLoadoutsController
	if controller:
		controller.update_with_weapon_config(current_configuration.primary_weapons, current_configuration.secondary_weapons)

## Updates damage system panel
func _update_damage_system_panel() -> void:
	if not damage_system_panel:
		return
	
	var controller: DamageSystemController = damage_system_panel.get_script() as DamageSystemController
	if controller:
		controller.update_with_damage_config(current_configuration.damage_config)

## Updates hitpoints panel
func _update_hitpoints_panel() -> void:
	if not hitpoints_panel:
		return
	
	var controller: HitpointsController = hitpoints_panel.get_script() as HitpointsController
	if controller:
		controller.update_with_hitpoint_config(current_configuration.hitpoint_config)

## Updates ship flags panel
func _update_ship_flags_panel() -> void:
	if not ship_flags_panel:
		return
	
	var controller: ShipFlagsController = ship_flags_panel.get_script() as ShipFlagsController
	if controller:
		controller.update_with_flag_config(current_configuration.ship_flags)

## Updates texture replacement panel
func _update_texture_replacement_panel() -> void:
	if not texture_replacement_panel:
		return
	
	var controller: TextureReplacementController = texture_replacement_panel.get_script() as TextureReplacementController
	if controller:
		controller.update_with_texture_config(current_configuration.texture_config)

## Updates ship preview panel
func _update_ship_preview_panel() -> void:
	if not ship_preview_panel:
		return
	
	var controller: ShipPreviewController = ship_preview_panel.get_script() as ShipPreviewController
	if controller:
		controller.update_ship_preview(current_configuration)

## Updates UI for batch editing mode
func _update_batch_edit_ui() -> void:
	if is_batch_editing:
		# In batch edit mode, disable individual ship name editing
		# Enable batch operation controls
		apply_button.text = "Apply to All"
		reset_button.text = "Reset All"
	else:
		# Normal single ship editing mode
		apply_button.text = "Apply Changes"
		reset_button.text = "Reset"

## Validates current configuration
func _validate_current_configuration() -> void:
	if not current_configuration or not ship_config_manager:
		return
	
	# This will trigger the validation_status_changed signal
	ship_config_manager._validate_configuration(current_configuration)

## Applies configuration changes
func _apply_configuration_changes() -> void:
	if not current_configuration or not ship_config_manager:
		return
	
	if is_batch_editing:
		# Apply changes to all selected ships
		var property_mask: Dictionary = _get_batch_edit_property_mask()
		ship_config_manager.apply_batch_edit(current_configuration, property_mask)
	else:
		# Apply to single ship
		ship_config_manager.update_ship_configuration(current_configuration.ship_name, current_configuration)
	
	ship_configuration_updated.emit(current_configuration)

## Gets property mask for batch editing
func _get_batch_edit_property_mask() -> Dictionary:
	var mask: Dictionary = {}
	
	# TODO: Implement UI to select which properties to apply in batch mode
	# For now, apply common properties
	mask["team"] = true
	mask["ship_flags"] = true
	mask["ai_behavior"] = true
	mask["weapon_loadouts"] = true
	
	return mask

## Resets configuration to defaults
func _reset_configuration() -> void:
	if not current_configuration:
		return
	
	if is_batch_editing:
		# Reset all batch configurations
		ship_config_manager.end_batch_edit()
		ship_config_manager.start_batch_edit(batch_ship_ids)
	else:
		# Reset single configuration
		var ship_class: String = current_configuration.ship_class
		current_configuration = ship_config_manager.create_ship_configuration(current_configuration.ship_name, ship_class)
	
	_update_all_panels()

## Signal handlers

func _on_apply_pressed() -> void:
	_apply_configuration_changes()

func _on_reset_pressed() -> void:
	_reset_configuration()

func _on_batch_edit_pressed() -> void:
	if is_batch_editing:
		# End batch edit mode
		ship_config_manager.end_batch_edit()
		is_batch_editing = false
		batch_ship_ids.clear()
		batch_edit_completed.emit()
	else:
		# Start batch edit mode - this would need ship selection UI
		batch_edit_started.emit(batch_ship_ids)

func _on_tab_changed(tab_index: int) -> void:
	# Update specific panel when tab is switched
	match tab_index:
		0: _update_basic_properties_panel()
		1: _update_ai_behavior_panel()
		2: _update_weapon_loadouts_panel()
		3: _update_damage_system_panel()
		4: _update_hitpoints_panel()
		5: _update_ship_flags_panel()
		6: _update_texture_replacement_panel()
		7: _update_ship_preview_panel()

func _on_template_selected(template_id: int) -> void:
	var template_name: String = ""
	
	match template_id:
		0: template_name = "fighter"
		1: template_name = "bomber"
		2: template_name = "capital"
		3: template_name = "transport"
		4: _show_custom_template_dialog()
	
	if not template_name.is_empty() and current_configuration:
		ship_config_manager.apply_template(current_configuration.ship_name, template_name)
		configuration_template_applied.emit(template_name)
		_update_all_panels()

func _show_custom_template_dialog() -> void:
	# TODO: Show custom template creation/selection dialog
	print("AdvancedShipConfigurationDialog: Custom template dialog not yet implemented")

func _on_configuration_updated(config: ShipConfigurationData) -> void:
	if config == current_configuration:
		_update_all_panels()

func _on_validation_status_changed(is_valid: bool, errors: Array[String]) -> void:
	validation_indicator.visible = true
	
	if is_valid:
		validation_status_label.text = "✓ Configuration Valid"
		validation_status_label.add_theme_color_override("font_color", Color.GREEN)
		validation_indicator.modulate = Color.GREEN
	else:
		validation_status_label.text = "✗ %d Validation Errors" % errors.size()
		validation_status_label.add_theme_color_override("font_color", Color.RED)
		validation_indicator.modulate = Color.RED
		
		# Log validation errors
		for error in errors:
			print("Validation Error: %s" % error)

func _on_batch_edit_started(configs: Array[ShipConfigurationData]) -> void:
	print("AdvancedShipConfigurationDialog: Batch edit started for %d ships" % configs.size())

func _on_batch_edit_completed() -> void:
	print("AdvancedShipConfigurationDialog: Batch edit completed")
	_update_batch_edit_ui()

## Public API

## Opens the dialog with ship configuration
func edit_ship_configuration(ship_config: ShipConfigurationData) -> void:
	setup_ship_configuration(ship_config, false, [])
	popup_centered()

## Opens the dialog in batch edit mode
func edit_multiple_ships(ship_configs: Array[ShipConfigurationData], ship_ids: Array[String]) -> void:
	if not ship_configs.is_empty():
		# Use first configuration as template for batch editing
		var template_config: ShipConfigurationData = ship_configs[0].duplicate_for_batch_edit()
		setup_ship_configuration(template_config, true, ship_ids)
		popup_centered()

## Gets current configuration
func get_current_configuration() -> ShipConfigurationData:
	return current_configuration

## Gets performance statistics
func get_performance_stats() -> Dictionary:
	return {
		"dialog_instantiation_time": dialog_instantiation_time,
		"last_ui_update_time": last_ui_update_time,
		"meets_performance_requirements": last_ui_update_time < 16
	}