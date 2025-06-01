class_name SettingsSystemCoordinator
extends Node

## Complete settings system coordination for WCS-Godot conversion.
## Manages all settings (menu, graphics, audio, controls) with unified validation, backup, and import/export.
## Provides comprehensive settings management workflow orchestration.

signal settings_system_initialized()
signal settings_loaded(settings_type: String, settings: Resource)
signal settings_saved(settings_type: String, settings: Resource)
signal settings_validated(settings_type: String, is_valid: bool, errors: Array[String])
signal settings_exported(export_path: String, settings_types: Array[String])
signal settings_imported(import_path: String, success: bool)
signal backup_created(backup_path: String, settings_types: Array[String])
signal corruption_detected(settings_type: String, corruption_details: Dictionary)
signal reset_completed(reset_type: String, affected_settings: Array[String])

# Component references (assigned via scene or code)
@onready var menu_settings_manager: MenuSettingsManager = $MenuSettingsManager
@onready var validation_framework: SettingsValidationFramework = $ValidationFramework

# Current settings state
var current_menu_settings: MenuSettingsData = null
var current_graphics_settings: GraphicsSettingsData = null
var current_audio_settings: AudioSettingsData = null
var current_control_mapping: ControlMappingData = null

# System state
var is_system_initialized: bool = false
var pending_validations: Dictionary = {}
var backup_in_progress: bool = false

# Configuration
@export var enable_unified_validation: bool = true
@export var enable_cross_settings_validation: bool = true
@export var enable_automatic_corruption_recovery: bool = true
@export var unified_backup_enabled: bool = true

func _ready() -> void:
	"""Initialize settings system coordinator."""
	name = "SettingsSystemCoordinator"
	_setup_component_connections()
	_initialize_settings_system()

func _setup_component_connections() -> void:
	"""Setup connections between components."""
	# Create components if not assigned via scene
	if not menu_settings_manager:
		menu_settings_manager = MenuSettingsManager.create_menu_settings_manager()
		add_child(menu_settings_manager)
	
	if not validation_framework:
		validation_framework = SettingsValidationFramework.create_validation_framework()
		add_child(validation_framework)
	
	# Connect menu settings manager signals
	menu_settings_manager.settings_loaded.connect(_on_menu_settings_loaded)
	menu_settings_manager.settings_saved.connect(_on_menu_settings_saved)
	menu_settings_manager.settings_validated.connect(_on_menu_settings_validated)
	menu_settings_manager.settings_corrupted.connect(_on_menu_settings_corrupted)
	menu_settings_manager.backup_created.connect(_on_menu_backup_created)
	
	# Connect validation framework signals
	validation_framework.validation_completed.connect(_on_validation_completed)
	validation_framework.real_time_feedback_updated.connect(_on_real_time_feedback_updated)

# ============================================================================
# PUBLIC API
# ============================================================================

func initialize_complete_settings_system() -> void:
	"""Initialize complete settings system."""
	if is_system_initialized:
		return
	
	# Initialize all settings managers
	current_menu_settings = menu_settings_manager.initialize_settings()
	
	# Load existing settings for graphics, audio, and controls
	_load_graphics_settings()
	_load_audio_settings()
	_load_control_settings()
	
	# Perform unified validation
	if enable_unified_validation:
		_perform_unified_validation()
	
	is_system_initialized = true
	settings_system_initialized.emit()

func save_all_settings() -> bool:
	"""Save all current settings."""
	var success: bool = true
	
	if current_menu_settings:
		success = success and menu_settings_manager.save_settings(current_menu_settings)
	
	if current_graphics_settings:
		success = success and _save_graphics_settings(current_graphics_settings)
	
	if current_audio_settings:
		success = success and _save_audio_settings(current_audio_settings)
	
	if current_control_mapping:
		success = success and _save_control_mapping(current_control_mapping)
	
	# Create unified backup after successful save
	if success and unified_backup_enabled:
		create_unified_backup("save_all")
	
	return success

func validate_all_settings() -> Dictionary:
	"""Validate all settings and return comprehensive results."""
	var validation_results: Dictionary = {}
	
	if current_menu_settings:
		var menu_result = validation_framework.validate_settings(current_menu_settings, "menu_system")
		validation_results["menu_system"] = menu_result
	
	if current_graphics_settings:
		var graphics_result = validation_framework.validate_settings(current_graphics_settings, "graphics")
		validation_results["graphics"] = graphics_result
	
	if current_audio_settings:
		var audio_result = validation_framework.validate_settings(current_audio_settings, "audio")
		validation_results["audio"] = audio_result
	
	if current_control_mapping:
		var control_result = validation_framework.validate_settings(current_control_mapping, "controls")
		validation_results["controls"] = control_result
	
	# Perform cross-settings validation
	if enable_cross_settings_validation:
		var cross_validation_result = _perform_cross_settings_validation()
		validation_results["cross_validation"] = cross_validation_result
	
	return validation_results

func export_complete_settings(export_path: String) -> bool:
	"""Export all settings to unified file."""
	var export_data: Dictionary = {
		"export_timestamp": Time.get_unix_time_from_system(),
		"export_version": "1.0.0",
		"wcs_godot_version": ProjectSettings.get_setting("application/config/version", "unknown")
	}
	
	# Add all settings data
	if current_menu_settings:
		export_data["menu_settings"] = current_menu_settings.to_dictionary()
	
	if current_graphics_settings:
		export_data["graphics_settings"] = current_graphics_settings.to_dictionary()
	
	if current_audio_settings:
		export_data["audio_settings"] = current_audio_settings.to_dictionary()
	
	if current_control_mapping:
		export_data["control_mapping"] = current_control_mapping.to_dictionary()
	
	# Write to file
	var file: FileAccess = FileAccess.open(export_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to create export file: " + export_path)
		return false
	
	var json_string: String = JSON.stringify(export_data, "\t")
	file.store_string(json_string)
	file.close()
	
	var exported_types: Array[String] = export_data.keys().filter(func(key: String) -> bool: return key.ends_with("_settings") or key.ends_with("_mapping"))
	settings_exported.emit(export_path, exported_types)
	
	return true

func import_complete_settings(import_path: String) -> bool:
	"""Import all settings from unified file."""
	if not FileAccess.file_exists(import_path):
		push_error("Import file does not exist: " + import_path)
		settings_imported.emit(import_path, false)
		return false
	
	var file: FileAccess = FileAccess.open(import_path, FileAccess.READ)
	if not file:
		push_error("Failed to open import file: " + import_path)
		settings_imported.emit(import_path, false)
		return false
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse import JSON: " + import_path)
		settings_imported.emit(import_path, false)
		return false
	
	var import_data: Dictionary = json.data
	var success: bool = true
	
	# Create backup before importing
	create_unified_backup("pre_import")
	
	# Import each settings type
	if import_data.has("menu_settings"):
		var menu_settings: MenuSettingsData = MenuSettingsData.create_from_dictionary(import_data.menu_settings)
		if menu_settings.is_valid():
			current_menu_settings = menu_settings
			menu_settings_manager.save_settings(menu_settings)
		else:
			success = false
	
	if import_data.has("graphics_settings"):
		success = success and _import_graphics_settings(import_data.graphics_settings)
	
	if import_data.has("audio_settings"):
		success = success and _import_audio_settings(import_data.audio_settings)
	
	if import_data.has("control_mapping"):
		success = success and _import_control_mapping(import_data.control_mapping)
	
	# Validate after import
	if success:
		var validation_results: Dictionary = validate_all_settings()
		success = _all_validations_passed(validation_results)
	
	settings_imported.emit(import_path, success)
	return success

func create_unified_backup(backup_type: String = "manual") -> String:
	"""Create unified backup of all settings."""
	if backup_in_progress:
		push_warning("Backup already in progress")
		return ""
	
	backup_in_progress = true
	
	var timestamp: int = Time.get_unix_time_from_system()
	var backup_filename: String = "unified_settings_backup_%s_%d.json" % [backup_type, timestamp]
	var backup_path: String = "user://settings_backups/" + backup_filename
	
	# Ensure backup directory exists
	var dir: DirAccess = DirAccess.open("user://")
	if dir and not dir.dir_exists("settings_backups"):
		dir.make_dir("settings_backups")
	
	var success: bool = export_complete_settings(backup_path)
	
	if success:
		var backed_up_types: Array[String] = []
		if current_menu_settings: backed_up_types.append("menu_settings")
		if current_graphics_settings: backed_up_types.append("graphics_settings")
		if current_audio_settings: backed_up_types.append("audio_settings")
		if current_control_mapping: backed_up_types.append("control_mapping")
		
		backup_created.emit(backup_path, backed_up_types)
	
	backup_in_progress = false
	return backup_path if success else ""

func reset_all_settings(reset_type: String = "full") -> bool:
	"""Reset all settings to defaults."""
	var affected_settings: Array[String] = []
	var success: bool = true
	
	# Create backup before reset
	create_unified_backup("pre_reset")
	
	match reset_type:
		"full":
			if current_menu_settings:
				current_menu_settings.reset_to_defaults()
				success = success and menu_settings_manager.save_settings(current_menu_settings)
				affected_settings.append("menu_settings")
			
			if current_graphics_settings:
				success = success and _reset_graphics_settings()
				affected_settings.append("graphics_settings")
			
			if current_audio_settings:
				success = success and _reset_audio_settings()
				affected_settings.append("audio_settings")
			
			if current_control_mapping:
				success = success and _reset_control_mapping()
				affected_settings.append("control_mapping")
		
		"interface":
			if current_menu_settings:
				menu_settings_manager.reset_to_defaults("interface")
				affected_settings.append("menu_settings")
		
		"performance":
			if current_menu_settings:
				menu_settings_manager.reset_to_defaults("performance")
				affected_settings.append("menu_settings")
			
			if current_graphics_settings:
				success = success and _reset_graphics_settings()
				affected_settings.append("graphics_settings")
		
		"accessibility":
			if current_menu_settings:
				menu_settings_manager.reset_to_defaults("accessibility")
				affected_settings.append("menu_settings")
		
		_:
			push_error("Unknown reset type: " + reset_type)
			return false
	
	if success:
		reset_completed.emit(reset_type, affected_settings)
	
	return success

func get_system_status() -> Dictionary:
	"""Get comprehensive system status."""
	var validation_results: Dictionary = validate_all_settings()
	
	return {
		"is_initialized": is_system_initialized,
		"menu_settings_valid": current_menu_settings != null and current_menu_settings.is_valid(),
		"graphics_settings_valid": current_graphics_settings != null and current_graphics_settings.is_valid(),
		"audio_settings_valid": current_audio_settings != null and current_audio_settings.is_valid(),
		"control_mapping_valid": current_control_mapping != null and current_control_mapping.is_valid(),
		"overall_validation_passed": _all_validations_passed(validation_results),
		"pending_validations": pending_validations.size(),
		"backup_in_progress": backup_in_progress,
		"validation_statistics": validation_framework.get_validation_statistics()
	}

func get_current_settings(settings_type: String) -> Resource:
	"""Get current settings for specified type."""
	match settings_type:
		"menu_system":
			return current_menu_settings
		"graphics":
			return current_graphics_settings
		"audio":
			return current_audio_settings
		"controls":
			return current_control_mapping
		_:
			push_error("Unknown settings type: " + settings_type)
			return null

# ============================================================================
# HELPER METHODS
# ============================================================================

func _initialize_settings_system() -> void:
	"""Initialize the complete settings system."""
	initialize_complete_settings_system()

func _load_graphics_settings() -> void:
	"""Load graphics settings from existing system."""
	# Try to get from existing graphics options manager
	var graphics_managers: Array[Node] = get_tree().get_nodes_in_group("graphics_options_managers")
	if not graphics_managers.is_empty():
		var graphics_manager = graphics_managers[0]
		if graphics_manager.has_method("load_graphics_settings"):
			current_graphics_settings = graphics_manager.load_graphics_settings()
			settings_loaded.emit("graphics", current_graphics_settings)

func _load_audio_settings() -> void:
	"""Load audio settings from existing system."""
	# Try to get from existing audio options manager
	var audio_managers: Array[Node] = get_tree().get_nodes_in_group("audio_options_managers")
	if not audio_managers.is_empty():
		var audio_manager = audio_managers[0]
		if audio_manager.has_method("load_audio_settings"):
			current_audio_settings = audio_manager.load_audio_settings()
			settings_loaded.emit("audio", current_audio_settings)

func _load_control_settings() -> void:
	"""Load control mapping from existing system."""
	# Try to get from existing control mapping manager
	var control_managers: Array[Node] = get_tree().get_nodes_in_group("control_mapping_managers")
	if not control_managers.is_empty():
		var control_manager = control_managers[0]
		if control_manager.has_method("load_control_mapping"):
			current_control_mapping = control_manager.load_control_mapping()
			settings_loaded.emit("controls", current_control_mapping)

func _save_graphics_settings(settings: GraphicsSettingsData) -> bool:
	"""Save graphics settings through existing system."""
	var graphics_managers: Array[Node] = get_tree().get_nodes_in_group("graphics_options_managers")
	if not graphics_managers.is_empty():
		var graphics_manager = graphics_managers[0]
		if graphics_manager.has_method("save_graphics_settings"):
			return graphics_manager.save_graphics_settings(settings)
	return false

func _save_audio_settings(settings: AudioSettingsData) -> bool:
	"""Save audio settings through existing system."""
	var audio_managers: Array[Node] = get_tree().get_nodes_in_group("audio_options_managers")
	if not audio_managers.is_empty():
		var audio_manager = audio_managers[0]
		if audio_manager.has_method("save_audio_settings"):
			return audio_manager.save_audio_settings(settings)
	return false

func _save_control_mapping(mapping: ControlMappingData) -> bool:
	"""Save control mapping through existing system."""
	var control_managers: Array[Node] = get_tree().get_nodes_in_group("control_mapping_managers")
	if not control_managers.is_empty():
		var control_manager = control_managers[0]
		if control_manager.has_method("save_control_mapping"):
			return control_manager.save_control_mapping(mapping)
	return false

func _import_graphics_settings(data: Dictionary) -> bool:
	"""Import graphics settings from data."""
	if not current_graphics_settings:
		current_graphics_settings = GraphicsSettingsData.new()
	
	current_graphics_settings.from_dictionary(data)
	return _save_graphics_settings(current_graphics_settings)

func _import_audio_settings(data: Dictionary) -> bool:
	"""Import audio settings from data."""
	if not current_audio_settings:
		current_audio_settings = AudioSettingsData.new()
	
	current_audio_settings.from_dictionary(data)
	return _save_audio_settings(current_audio_settings)

func _import_control_mapping(data: Dictionary) -> bool:
	"""Import control mapping from data."""
	if not current_control_mapping:
		current_control_mapping = ControlMappingData.new()
	
	current_control_mapping.from_dictionary(data)
	return _save_control_mapping(current_control_mapping)

func _reset_graphics_settings() -> bool:
	"""Reset graphics settings to defaults."""
	if current_graphics_settings and current_graphics_settings.has_method("reset_to_defaults"):
		current_graphics_settings.reset_to_defaults()
		return _save_graphics_settings(current_graphics_settings)
	return false

func _reset_audio_settings() -> bool:
	"""Reset audio settings to defaults."""
	if current_audio_settings and current_audio_settings.has_method("reset_to_defaults"):
		current_audio_settings.reset_to_defaults()
		return _save_audio_settings(current_audio_settings)
	return false

func _reset_control_mapping() -> bool:
	"""Reset control mapping to defaults."""
	if current_control_mapping and current_control_mapping.has_method("reset_to_defaults"):
		current_control_mapping.reset_to_defaults()
		return _save_control_mapping(current_control_mapping)
	return false

func _perform_unified_validation() -> void:
	"""Perform unified validation of all settings."""
	validate_all_settings()

func _perform_cross_settings_validation() -> SettingsValidationFramework.ValidationResult:
	"""Perform cross-settings validation."""
	var result: SettingsValidationFramework.ValidationResult = SettingsValidationFramework.ValidationResult.new()
	result.settings_type = "cross_validation"
	
	# Check for conflicts between settings
	if current_menu_settings and current_graphics_settings:
		if current_menu_settings.max_menu_fps != current_graphics_settings.target_fps:
			result.errors.append("Menu FPS and graphics target FPS mismatch")
	
	if current_menu_settings and current_audio_settings:
		if not current_menu_settings.menu_music_enabled and current_audio_settings.music_volume > 0.0:
			result.errors.append("Menu music disabled but audio music volume set")
	
	result.is_valid = result.errors.is_empty()
	return result

func _all_validations_passed(validation_results: Dictionary) -> bool:
	"""Check if all validations passed."""
	for result in validation_results.values():
		if not result.is_valid:
			return false
	return true

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_menu_settings_loaded(settings: MenuSettingsData) -> void:
	"""Handle menu settings loaded."""
	current_menu_settings = settings
	settings_loaded.emit("menu_system", settings)

func _on_menu_settings_saved(settings: MenuSettingsData) -> void:
	"""Handle menu settings saved."""
	current_menu_settings = settings
	settings_saved.emit("menu_system", settings)

func _on_menu_settings_validated(is_valid: bool, errors: Array[String]) -> void:
	"""Handle menu settings validation."""
	settings_validated.emit("menu_system", is_valid, errors)

func _on_menu_settings_corrupted(corruption_details: Dictionary) -> void:
	"""Handle menu settings corruption."""
	corruption_detected.emit("menu_system", corruption_details)

func _on_menu_backup_created(backup_path: String) -> void:
	"""Handle menu settings backup created."""
	backup_created.emit(backup_path, ["menu_settings"])

func _on_validation_completed(settings_type: String, is_valid: bool, errors: Array[String]) -> void:
	"""Handle validation framework completion."""
	settings_validated.emit(settings_type, is_valid, errors)

func _on_real_time_feedback_updated(field_name: String, is_valid: bool, error_message: String) -> void:
	"""Handle real-time validation feedback."""
	# Forward to any listening UI components
	pass

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_settings_system_coordinator() -> SettingsSystemCoordinator:
	"""Create a new settings system coordinator instance."""
	var coordinator: SettingsSystemCoordinator = SettingsSystemCoordinator.new()
	return coordinator

static func launch_unified_settings_system(parent_node: Node) -> SettingsSystemCoordinator:
	"""Launch complete unified settings system."""
	var coordinator: SettingsSystemCoordinator = create_settings_system_coordinator()
	parent_node.add_child(coordinator)
	coordinator.initialize_complete_settings_system()
	return coordinator