class_name HUDConfigManager
extends Node

## EPIC-012 HUD-004: HUD Configuration Management System
## Provides comprehensive HUD customization, layout management, and persistence
## Integrates with existing HUDConfig system while adding advanced features

signal config_loaded(config: HUDConfig)
signal config_saved(profile_name: String)
signal layout_changed(layout_name: String)
signal color_scheme_changed(scheme_name: String)
signal visibility_changed(element_id: String, visible: bool)
signal preset_applied(preset_name: String)

# Configuration state
var current_config: HUDConfig
var default_config: HUDConfig
var config_profiles: Dictionary = {}
var active_profile_name: String = "default"

# Configuration components
var layout_presets: HUDLayoutPresets
var color_scheme_manager: HUDColorSchemeManager
var visibility_manager: HUDElementVisibilityManager
var positioning_system: HUDLayoutPositioning
var persistence_handler: HUDConfigPersistence

# Current state
var current_layout_preset: String = "standard"
var current_color_scheme: String = "green"
var is_config_dirty: bool = false
var preview_mode: bool = false

# Configuration paths
var config_base_path: String = "user://hud_configs/"
var default_config_path: String = "res://addons/wcs_asset_core/resources/hud/default_hud_config.tres"

func _ready() -> void:
	print("HUDConfigManager: Initializing configuration system")
	_initialize_config_system()

## Initialize the configuration system
func _initialize_config_system() -> void:
	# Ensure config directory exists
	_ensure_config_directory()
	
	# Initialize components
	_initialize_components()
	
	# Load default configuration
	_load_default_config()
	
	# Load user configuration
	_load_user_config()
	
	# Set up auto-save
	_setup_auto_save()
	
	print("HUDConfigManager: Configuration system initialized - Profile: %s" % active_profile_name)

## Ensure configuration directory exists
func _ensure_config_directory() -> void:
	if not DirAccess.dir_exists_absolute(config_base_path):
		DirAccess.open("user://").make_dir_recursive(config_base_path.get_file())
		print("HUDConfigManager: Created config directory: %s" % config_base_path)

## Initialize configuration components
func _initialize_components() -> void:
	layout_presets = HUDLayoutPresets.new()
	color_scheme_manager = HUDColorSchemeManager.new()
	visibility_manager = HUDElementVisibilityManager.new()
	positioning_system = HUDLayoutPositioning.new()
	persistence_handler = HUDConfigPersistence.new()
	
	# Configure components
	layout_presets.initialize()
	color_scheme_manager.initialize()
	visibility_manager.initialize()
	positioning_system.initialize()
	persistence_handler.setup(config_base_path)
	
	# Connect signals
	_connect_component_signals()

## Connect component signals
func _connect_component_signals() -> void:
	visibility_manager.element_visibility_changed.connect(_on_element_visibility_changed)
	color_scheme_manager.scheme_changed.connect(_on_color_scheme_changed)
	layout_presets.preset_applied.connect(_on_preset_applied)

## Load default configuration
func _load_default_config() -> void:
	if ResourceLoader.exists(default_config_path):
		default_config = ResourceLoader.load(default_config_path) as HUDConfig
		if default_config:
			print("HUDConfigManager: Default config loaded from %s" % default_config_path)
		else:
			print("HUDConfigManager: Warning - Invalid default config, creating fallback")
			_create_fallback_config()
	else:
		print("HUDConfigManager: Default config not found, creating fallback")
		_create_fallback_config()

## Create fallback configuration
func _create_fallback_config() -> void:
	default_config = HUDConfig.new()
	
	# Set basic defaults
	default_config.layout_preset = "standard"
	default_config.color_scheme = "green"
	default_config.hud_scale = 1.0
	default_config.text_scale = 1.0
	default_config.alpha_multiplier = 0.8
	
	# Initialize visibility flags with all elements visible
	default_config.gauge_visibility_flags = HUDConfig.DEFAULT_FLAGS
	
	print("HUDConfigManager: Created fallback default configuration")

## Load user configuration
func _load_user_config(profile_name: String = "default") -> bool:
	var loaded_config = persistence_handler.load_config(profile_name)
	
	if loaded_config:
		current_config = loaded_config
		active_profile_name = profile_name
		_apply_loaded_config()
		config_loaded.emit(current_config)
		print("HUDConfigManager: User config loaded - Profile: %s" % profile_name)
		return true
	else:
		# Use default config
		current_config = default_config.duplicate() if default_config else HUDConfig.new()
		active_profile_name = profile_name
		_apply_loaded_config()
		print("HUDConfigManager: Using default config for profile: %s" % profile_name)
		return false

## Apply loaded configuration
func _apply_loaded_config() -> void:
	if not current_config:
		return
	
	# Update current state
	current_layout_preset = current_config.layout_preset
	current_color_scheme = current_config.color_scheme
	
	# Apply to components
	layout_presets.apply_preset(current_layout_preset)
	color_scheme_manager.apply_color_scheme(current_color_scheme)
	visibility_manager.apply_visibility_flags(current_config.gauge_visibility_flags)
	
	# Emit change signals
	layout_changed.emit(current_layout_preset)
	color_scheme_changed.emit(current_color_scheme)
	
	is_config_dirty = false

## Save current configuration
func save_current_config(profile_name: String = "") -> bool:
	if profile_name.is_empty():
		profile_name = active_profile_name
	
	if not current_config:
		print("HUDConfigManager: Error - No current config to save")
		return false
	
	# Update config with current state
	_update_config_from_current_state()
	
	# Save configuration
	var success = persistence_handler.save_config(current_config, profile_name)
	
	if success:
		active_profile_name = profile_name
		is_config_dirty = false
		config_saved.emit(profile_name)
		print("HUDConfigManager: Configuration saved - Profile: %s" % profile_name)
	else:
		print("HUDConfigManager: Error saving configuration - Profile: %s" % profile_name)
	
	return success

## Update config from current state
func _update_config_from_current_state() -> void:
	if not current_config:
		return
	
	current_config.layout_preset = current_layout_preset
	current_config.color_scheme = current_color_scheme
	current_config.gauge_visibility_flags = visibility_manager.get_current_visibility_flags()
	current_config.element_positions = positioning_system.get_current_positions()
	current_config.custom_colors = color_scheme_manager.get_custom_colors()

## Apply layout preset
func apply_layout_preset(preset_name: String) -> bool:
	if not layout_presets.has_preset(preset_name):
		print("HUDConfigManager: Error - Unknown layout preset: %s" % preset_name)
		return false
	
	# Apply preset
	var preset_data = layout_presets.get_preset(preset_name)
	layout_presets.apply_preset(preset_name)
	
	# Update current state
	current_layout_preset = preset_name
	is_config_dirty = true
	
	# Apply visibility flags if preset includes them
	if preset_data.has("visibility_flags"):
		visibility_manager.apply_visibility_flags(preset_data.visibility_flags)
	
	# Apply positions if preset includes them
	if preset_data.has("element_positions"):
		positioning_system.apply_positions(preset_data.element_positions)
	
	layout_changed.emit(preset_name)
	preset_applied.emit(preset_name)
	
	print("HUDConfigManager: Applied layout preset: %s" % preset_name)
	return true

## Apply color scheme
func apply_color_scheme(scheme_name: String) -> bool:
	if not color_scheme_manager.has_scheme(scheme_name):
		print("HUDConfigManager: Error - Unknown color scheme: %s" % scheme_name)
		return false
	
	# Apply color scheme
	color_scheme_manager.apply_color_scheme(scheme_name)
	
	# Update current state
	current_color_scheme = scheme_name
	is_config_dirty = true
	
	color_scheme_changed.emit(scheme_name)
	
	print("HUDConfigManager: Applied color scheme: %s" % scheme_name)
	return true

## Set element visibility
func set_element_visibility(element_id: String, visible: bool) -> void:
	visibility_manager.set_element_visibility(element_id, visible)
	is_config_dirty = true
	visibility_changed.emit(element_id, visible)

## Get element visibility
func is_element_visible(element_id: String) -> bool:
	return visibility_manager.is_element_visible(element_id)

## Get available layout presets
func get_available_layout_presets() -> Array[String]:
	return layout_presets.get_preset_names()

## Get available color schemes
func get_available_color_schemes() -> Array[String]:
	return color_scheme_manager.get_scheme_names()

## Get current configuration summary
func get_config_summary() -> Dictionary:
	return {
		"profile_name": active_profile_name,
		"layout_preset": current_layout_preset,
		"color_scheme": current_color_scheme,
		"is_dirty": is_config_dirty,
		"preview_mode": preview_mode,
		"visible_elements": visibility_manager.get_visible_element_count(),
		"total_elements": visibility_manager.get_total_element_count(),
		"custom_positions": positioning_system.get_custom_position_count(),
		"custom_colors": color_scheme_manager.get_custom_color_count()
	}

## Reset to default configuration
func reset_to_defaults() -> void:
	if not default_config:
		print("HUDConfigManager: Error - No default config available")
		return
	
	# Reset current config to defaults
	current_config = default_config.duplicate()
	
	# Apply default configuration
	_apply_loaded_config()
	
	is_config_dirty = true
	
	print("HUDConfigManager: Reset to default configuration")

## Enter preview mode
func enter_preview_mode() -> void:
	if not preview_mode:
		# Store current state for restoration
		_store_preview_backup()
		preview_mode = true
		print("HUDConfigManager: Entered preview mode")

## Exit preview mode
func exit_preview_mode(apply_changes: bool = false) -> void:
	if preview_mode:
		if not apply_changes:
			# Restore backup
			_restore_preview_backup()
		
		preview_mode = false
		print("HUDConfigManager: Exited preview mode - Applied: %s" % str(apply_changes))

var _preview_backup: Dictionary = {}

## Store preview backup
func _store_preview_backup() -> void:
	_preview_backup = {
		"layout_preset": current_layout_preset,
		"color_scheme": current_color_scheme,
		"visibility_flags": visibility_manager.get_current_visibility_flags(),
		"element_positions": positioning_system.get_current_positions(),
		"custom_colors": color_scheme_manager.get_custom_colors()
	}

## Restore preview backup
func _restore_preview_backup() -> void:
	if _preview_backup.is_empty():
		return
	
	# Restore previous state
	current_layout_preset = _preview_backup.layout_preset
	current_color_scheme = _preview_backup.color_scheme
	
	# Apply restored state
	layout_presets.apply_preset(current_layout_preset)
	color_scheme_manager.apply_color_scheme(current_color_scheme)
	visibility_manager.apply_visibility_flags(_preview_backup.visibility_flags)
	positioning_system.apply_positions(_preview_backup.element_positions)
	color_scheme_manager.apply_custom_colors(_preview_backup.custom_colors)
	
	# Clear backup
	_preview_backup.clear()

## Get list of available configuration profiles
func get_available_profiles() -> Array[String]:
	return persistence_handler.get_available_profiles()

## Delete configuration profile
func delete_profile(profile_name: String) -> bool:
	if profile_name == "default":
		print("HUDConfigManager: Cannot delete default profile")
		return false
	
	var success = persistence_handler.delete_profile(profile_name)
	
	if success:
		print("HUDConfigManager: Deleted profile: %s" % profile_name)
		
		# Switch to default if active profile was deleted
		if profile_name == active_profile_name:
			_load_user_config("default")
	
	return success

## Export configuration to file
func export_config(file_path: String, profile_name: String = "") -> bool:
	if profile_name.is_empty():
		profile_name = active_profile_name
	
	var config_to_export = current_config if profile_name == active_profile_name else persistence_handler.load_config(profile_name)
	
	if not config_to_export:
		print("HUDConfigManager: Error - Cannot load config for export: %s" % profile_name)
		return false
	
	var success = ResourceSaver.save(config_to_export, file_path)
	
	if success:
		print("HUDConfigManager: Exported config to: %s" % file_path)
	else:
		print("HUDConfigManager: Error exporting config to: %s" % file_path)
	
	return success == OK

## Import configuration from file
func import_config(file_path: String, profile_name: String) -> bool:
	if not ResourceLoader.exists(file_path):
		print("HUDConfigManager: Error - Import file not found: %s" % file_path)
		return false
	
	var imported_config = ResourceLoader.load(file_path) as HUDConfig
	
	if not imported_config:
		print("HUDConfigManager: Error - Invalid config file: %s" % file_path)
		return false
	
	# Validate imported config
	var validation_result = persistence_handler.validate_config(imported_config)
	
	if not validation_result.is_valid:
		print("HUDConfigManager: Error - Invalid imported config: %s" % str(validation_result.errors))
		return false
	
	# Save imported config
	var success = persistence_handler.save_config(imported_config, profile_name)
	
	if success:
		print("HUDConfigManager: Imported config as profile: %s" % profile_name)
	
	return success

## Setup auto-save functionality
func _setup_auto_save() -> void:
	# Create timer for auto-save
	var auto_save_timer = Timer.new()
	auto_save_timer.wait_time = 30.0  # Auto-save every 30 seconds
	auto_save_timer.timeout.connect(_auto_save)
	add_child(auto_save_timer)
	auto_save_timer.start()

## Auto-save if configuration is dirty
func _auto_save() -> void:
	if is_config_dirty and not preview_mode:
		print("HUDConfigManager: Auto-saving configuration")
		save_current_config()

## Signal handlers
func _on_element_visibility_changed(element_id: String, visible: bool) -> void:
	is_config_dirty = true
	visibility_changed.emit(element_id, visible)

func _on_color_scheme_changed(scheme_name: String) -> void:
	current_color_scheme = scheme_name
	is_config_dirty = true
	color_scheme_changed.emit(scheme_name)

func _on_preset_applied(preset_name: String) -> void:
	current_layout_preset = preset_name
	is_config_dirty = true
	preset_applied.emit(preset_name)

## Get configuration for specific element
func get_element_config(element_id: String) -> Dictionary:
	return {
		"visible": visibility_manager.is_element_visible(element_id),
		"position": positioning_system.get_element_position(element_id),
		"color": color_scheme_manager.get_element_color(element_id),
		"scale": positioning_system.get_element_scale(element_id)
	}

## Apply element configuration
func apply_element_config(element_id: String, config: Dictionary) -> void:
	if config.has("visible"):
		visibility_manager.set_element_visibility(element_id, config.visible)
	
	if config.has("position"):
		positioning_system.set_element_position(element_id, config.position)
	
	if config.has("color"):
		color_scheme_manager.set_element_color(element_id, config.color)
	
	if config.has("scale"):
		positioning_system.set_element_scale(element_id, config.scale)
	
	is_config_dirty = true

## Cleanup
func _exit_tree() -> void:
	# Save configuration if dirty
	if is_config_dirty and not preview_mode:
		save_current_config()
	
	print("HUDConfigManager: Configuration system cleanup complete")