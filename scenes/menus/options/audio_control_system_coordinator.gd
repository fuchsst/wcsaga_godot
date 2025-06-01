class_name AudioControlSystemCoordinator
extends Control

## Complete audio and control configuration system coordination for WCS-Godot conversion.
## Orchestrates audio settings, control mapping, and accessibility features.
## Provides unified interface for comprehensive input and audio configuration.

signal options_applied(audio_settings: AudioSettingsData, control_mapping: ControlMappingData)
signal options_cancelled()
signal preset_changed(preset_type: String, preset_name: String, settings: Variant)
signal device_configuration_completed(devices: Array[Dictionary])

# System components (from scene)
@onready var audio_data_manager: AudioOptionsDataManager = $AudioDataManager
@onready var control_mapping_manager: ControlMappingManager = $ControlMappingManager
@onready var display_controller: AudioControlDisplayController = $AudioControlDisplayController

# Current state
var current_audio_settings: AudioSettingsData = null
var current_control_mapping: ControlMappingData = null
var available_audio_devices: Array[Dictionary] = []
var connected_input_devices: Array[Dictionary] = []

# Integration helpers
var configuration_manager: ConfigurationManager = null

# Configuration
@export var enable_real_time_audio_testing: bool = true
@export var enable_device_detection: bool = true
@export var enable_conflict_resolution: bool = true
@export var enable_accessibility_features: bool = true

func _ready() -> void:
	\"\"\"Initialize audio and control system coordinator.\"\"\"
	_setup_dependencies()
	_setup_signal_connections()

func _setup_dependencies() -> void:
	\"\"\"Setup required dependencies.\"\"\"
	# ConfigurationManager is an autoload, so it's always available
	configuration_manager = ConfigurationManager

func _setup_signal_connections() -> void:
	\"\"\"Setup signal connections between components.\"\"\"
	# Audio data manager signals
	if audio_data_manager:
		audio_data_manager.settings_loaded.connect(_on_audio_settings_loaded)
		audio_data_manager.settings_saved.connect(_on_audio_settings_saved)
		audio_data_manager.device_detected.connect(_on_audio_device_detected)
		audio_data_manager.audio_test_started.connect(_on_audio_test_started)
		audio_data_manager.audio_test_completed.connect(_on_audio_test_completed)
	
	# Control mapping manager signals
	if control_mapping_manager:
		control_mapping_manager.mapping_loaded.connect(_on_control_mapping_loaded)
		control_mapping_manager.mapping_saved.connect(_on_control_mapping_saved)
		control_mapping_manager.device_detected.connect(_on_input_device_detected)
		control_mapping_manager.binding_started.connect(_on_control_binding_started)
		control_mapping_manager.binding_completed.connect(_on_control_binding_completed)
		control_mapping_manager.binding_cancelled.connect(_on_control_binding_cancelled)
		control_mapping_manager.conflict_detected.connect(_on_control_conflicts_detected)
	
	# Display controller signals
	if display_controller:
		display_controller.audio_settings_changed.connect(_on_audio_settings_changed)
		display_controller.control_mapping_changed.connect(_on_control_mapping_changed)
		display_controller.audio_test_requested.connect(_on_audio_test_requested)
		display_controller.control_binding_requested.connect(_on_control_binding_requested)
		display_controller.settings_applied.connect(_on_settings_applied)
		display_controller.settings_cancelled.connect(_on_settings_cancelled)
		display_controller.preset_selected.connect(_on_preset_selected)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_audio_control_options() -> void:
	\"\"\"Show audio and control options interface.\"\"\"
	# Load current settings
	if audio_data_manager:
		current_audio_settings = audio_data_manager.load_audio_settings()
	
	if control_mapping_manager:
		current_control_mapping = control_mapping_manager.load_control_mapping()
	
	# Update display
	if display_controller and current_audio_settings and current_control_mapping:
		display_controller.show_audio_control_options(current_audio_settings, current_control_mapping)
		
		# Update device lists
		if enable_device_detection:
			_update_device_displays()
	
	show()

func close_audio_control_options() -> void:
	\"\"\"Close audio and control options interface.\"\"\"
	if display_controller:
		display_controller.close_audio_control_options()
	
	# Stop any running audio tests
	if audio_data_manager:
		audio_data_manager.stop_all_audio_tests()
	
	# Cancel any active control binding
	if control_mapping_manager:
		control_mapping_manager.cancel_binding()
	
	hide()

func apply_audio_preset(preset_name: String) -> void:
	\"\"\"Apply audio preset configuration.\"\"\"
	if not audio_data_manager:
		push_error(\"Audio data manager not available\")
		return
	
	var preset_settings: AudioSettingsData = audio_data_manager.apply_preset_configuration(preset_name)
	
	if preset_settings and display_controller:
		current_audio_settings = preset_settings
		display_controller.show_audio_control_options(current_audio_settings, current_control_mapping)

func apply_control_preset(preset_name: String) -> void:
	\"\"\"Apply control mapping preset.\"\"\"
	if not control_mapping_manager:
		push_error(\"Control mapping manager not available\")
		return
	
	var preset_mapping: ControlMappingData = control_mapping_manager.apply_preset(preset_name)
	
	if preset_mapping and display_controller:
		current_control_mapping = preset_mapping
		display_controller.show_audio_control_options(current_audio_settings, current_control_mapping)

func test_audio_category(category: String) -> void:
	\"\"\"Test audio for specific category or all categories.\"\"\"
	if not audio_data_manager or not enable_real_time_audio_testing:
		return
	
	if category == \"all\":
		for test_category in [\"music\", \"effects\", \"voice\", \"ambient\", \"ui\"]:
			audio_data_manager.test_audio_sample(test_category)
			await get_tree().create_timer(1.0).timeout  # Stagger tests
	else:
		audio_data_manager.test_audio_sample(category)

func start_control_binding(action_name: String, input_type: String = \"any\") -> void:
	\"\"\"Start control binding for specified action.\"\"\"
	if not control_mapping_manager:
		return
	
	control_mapping_manager.start_binding(action_name, input_type)

func get_current_audio_settings() -> AudioSettingsData:
	\"\"\"Get current audio settings.\"\"\"
	return current_audio_settings.clone() if current_audio_settings else null

func get_current_control_mapping() -> ControlMappingData:
	\"\"\"Get current control mapping.\"\"\"
	return current_control_mapping.clone() if current_control_mapping else null

func get_available_audio_presets() -> Array[String]:
	\"\"\"Get available audio presets.\"\"\"
	if audio_data_manager:
		return audio_data_manager.get_available_presets()
	return []

func get_available_control_presets() -> Array[String]:
	\"\"\"Get available control presets.\"\"\"
	if control_mapping_manager:
		return control_mapping_manager.get_available_presets()
	return []

func validate_current_settings() -> Dictionary:
	\"\"\"Validate current audio and control settings.\"\"\"
	var validation_result: Dictionary = {
		\"audio_errors\": [],
		\"control_errors\": [],
		\"conflicts\": [],
		\"is_valid\": true
	}
	
	# Validate audio settings
	if audio_data_manager and current_audio_settings:
		validation_result.audio_errors = audio_data_manager.validate_settings(current_audio_settings)
	
	# Validate control mapping
	if control_mapping_manager and current_control_mapping:
		validation_result.control_errors = control_mapping_manager.validate_mapping(current_control_mapping)
		validation_result.conflicts = control_mapping_manager.detect_conflicts()
	
	# Overall validation
	var total_errors: int = validation_result.audio_errors.size() + validation_result.control_errors.size() + validation_result.conflicts.size()
	validation_result.is_valid = total_errors == 0
	
	return validation_result

func get_system_diagnostics() -> Dictionary:
	\"\"\"Get comprehensive system diagnostics.\"\"\"
	var diagnostics: Dictionary = {
		\"audio_system\": {},
		\"input_system\": {},
		\"device_status\": {},
		\"performance_metrics\": {}
	}
	
	# Audio system diagnostics
	if audio_data_manager:
		diagnostics.audio_system = audio_data_manager.get_audio_performance_metrics()
		diagnostics.device_status[\"audio_devices\"] = audio_data_manager.get_available_devices()
	
	# Input system diagnostics
	if control_mapping_manager:
		diagnostics.input_system = {
			\"connected_devices\": control_mapping_manager.get_connected_devices(),
			\"binding_conflicts\": control_mapping_manager.detect_conflicts(),
			\"current_preset\": \"custom\"  # Would need to detect this
		}
	
	# Performance metrics
	diagnostics.performance_metrics = {
		\"memory_usage\": _estimate_system_memory_usage(),
		\"component_status\": _get_component_status(),
		\"configuration_status\": _get_configuration_status()
	}
	
	return diagnostics

func optimize_for_accessibility() -> void:
	\"\"\"Optimize settings for accessibility features.\"\"\"
	if not enable_accessibility_features:
		return
	
	# Audio accessibility optimizations
	if current_audio_settings:
		current_audio_settings.audio_cues_enabled = true
		current_audio_settings.visual_audio_indicators = true
		current_audio_settings.subtitles_enabled = true
		current_audio_settings.subtitle_size = 2  # Large
		current_audio_settings.subtitle_background = true
		current_audio_settings.audio_ducking = true
	
	# Control accessibility optimizations
	if current_control_mapping:
		current_control_mapping.sticky_keys = true
		current_control_mapping.repeat_delay = 0.8  # Longer delay
		current_control_mapping.repeat_rate = 0.2  # Slower repeat
	
	# Update display
	if display_controller and current_audio_settings and current_control_mapping:
		display_controller.show_audio_control_options(current_audio_settings, current_control_mapping)

# ============================================================================
# WORKFLOW COORDINATION
# ============================================================================

func _on_audio_settings_loaded(settings: AudioSettingsData) -> void:
	\"\"\"Handle audio settings loaded from data manager.\"\"\"
	current_audio_settings = settings
	
	# Update display if visible
	if display_controller and visible and current_control_mapping:
		display_controller.show_audio_control_options(current_audio_settings, current_control_mapping)

func _on_audio_settings_saved(settings: AudioSettingsData) -> void:
	\"\"\"Handle audio settings saved by data manager.\"\"\"
	current_audio_settings = settings
	
	# Check if both audio and control settings are saved
	if current_control_mapping:
		_check_complete_settings_save()

func _on_control_mapping_loaded(mapping: ControlMappingData) -> void:
	\"\"\"Handle control mapping loaded from manager.\"\"\"
	current_control_mapping = mapping
	
	# Update display if visible
	if display_controller and visible and current_audio_settings:
		display_controller.show_audio_control_options(current_audio_settings, current_control_mapping)

func _on_control_mapping_saved(mapping: ControlMappingData) -> void:
	\"\"\"Handle control mapping saved by manager.\"\"\"
	current_control_mapping = mapping
	
	# Check if both audio and control settings are saved
	if current_audio_settings:
		_check_complete_settings_save()

func _on_audio_device_detected(device_info: Dictionary) -> void:
	\"\"\"Handle audio device detection.\"\"\"
	if not available_audio_devices.has(device_info):
		available_audio_devices.append(device_info)
	
	# Update display device list
	if display_controller:
		display_controller.update_audio_devices(available_audio_devices)

func _on_input_device_detected(device_info: Dictionary) -> void:
	\"\"\"Handle input device detection.\"\"\"
	if not connected_input_devices.has(device_info):
		connected_input_devices.append(device_info)
	
	# Update display device list
	if display_controller:
		display_controller.update_input_devices(connected_input_devices)

func _on_audio_test_started(sample_name: String) -> void:
	\"\"\"Handle audio test start.\"\"\"
	# Could show visual feedback for running test
	pass

func _on_audio_test_completed(sample_name: String) -> void:
	\"\"\"Handle audio test completion.\"\"\"
	# Could clear visual feedback for completed test
	pass

# ============================================================================
# USER INTERACTION HANDLERS
# ============================================================================

func _on_audio_settings_changed(settings: AudioSettingsData) -> void:
	\"\"\"Handle audio settings change from display controller.\"\"\"
	current_audio_settings = settings
	
	# Apply real-time preview if enabled
	if enable_real_time_audio_testing and audio_data_manager:
		# Apply settings for preview (without saving)
		pass

func _on_control_mapping_changed(mapping: ControlMappingData) -> void:
	\"\"\"Handle control mapping change from display controller.\"\"\"
	current_control_mapping = mapping
	
	# Check for conflicts
	if enable_conflict_resolution and control_mapping_manager:
		var conflicts: Array[Dictionary] = control_mapping_manager.detect_conflicts()
		if not conflicts.is_empty() and display_controller:
			display_controller.show_conflict_warning(conflicts)

func _on_audio_test_requested(category: String) -> void:
	\"\"\"Handle audio test request from display controller.\"\"\"
	test_audio_category(category)

func _on_control_binding_requested(action_name: String, input_type: String) -> void:
	\"\"\"Handle control binding request from display controller.\"\"\"
	start_control_binding(action_name, input_type)

func _on_control_binding_started(action_name: String, input_type: String) -> void:
	\"\"\"Handle control binding start from manager.\"\"\"
	if display_controller:
		display_controller.show_binding_feedback(action_name, input_type)

func _on_control_binding_completed(action_name: String, binding: ControlMappingData.InputBinding) -> void:
	\"\"\"Handle control binding completion from manager.\"\"\"
	if display_controller:
		display_controller.clear_binding_feedback()
	
	# Update current mapping
	if current_control_mapping:
		current_control_mapping.set_binding(action_name, binding)
		
		# Check for conflicts
		if enable_conflict_resolution:
			var conflicts: Array[Dictionary] = control_mapping_manager.detect_conflicts()
			if not conflicts.is_empty() and display_controller:
				display_controller.show_conflict_warning(conflicts)

func _on_control_binding_cancelled(action_name: String) -> void:
	\"\"\"Handle control binding cancellation from manager.\"\"\"
	if display_controller:
		display_controller.clear_binding_feedback()

func _on_control_conflicts_detected(conflicts: Array[Dictionary]) -> void:
	\"\"\"Handle control conflicts detected from manager.\"\"\"
	if display_controller:
		display_controller.show_conflict_warning(conflicts)

func _on_settings_applied() -> void:
	\"\"\"Handle settings application from display controller.\"\"\"
	var validation: Dictionary = validate_current_settings()
	
	if not validation.is_valid:
		_show_validation_errors(validation)
		return
	
	# Save both audio and control settings
	var audio_saved: bool = false
	var control_saved: bool = false
	
	if audio_data_manager and current_audio_settings:
		audio_saved = audio_data_manager.save_audio_settings(current_audio_settings)
	
	if control_mapping_manager and current_control_mapping:
		control_saved = control_mapping_manager.save_control_mapping(current_control_mapping)
	
	if audio_saved and control_saved:
		options_applied.emit(current_audio_settings, current_control_mapping)
		close_audio_control_options()
	else:
		push_error(\"Failed to save audio and control settings\")

func _on_settings_cancelled() -> void:
	\"\"\"Handle settings cancellation from display controller.\"\"\"
	options_cancelled.emit()
	close_audio_control_options()

func _on_preset_selected(preset_type: String, preset_name: String) -> void:
	\"\"\"Handle preset selection from display controller.\"\"\"
	match preset_type:
		\"audio\":
			apply_audio_preset(preset_name)
			preset_changed.emit(preset_type, preset_name, current_audio_settings)
		\"controls\":
			apply_control_preset(preset_name)
			preset_changed.emit(preset_type, preset_name, current_control_mapping)

# ============================================================================
# HELPER METHODS
# ============================================================================

func _check_complete_settings_save() -> void:
	\"\"\"Check if both settings have been saved and emit completion.\"\"\"
	# This would be called when both audio and control settings are saved
	# Implementation depends on save coordination requirements
	pass

func _update_device_displays() -> void:
	\"\"\"Update device information in display controller.\"\"\"
	if not display_controller:
		return
	
	# Update audio devices
	if audio_data_manager:
		available_audio_devices = audio_data_manager.get_available_devices()
		display_controller.update_audio_devices(available_audio_devices)
	
	# Update input devices
	if control_mapping_manager:
		connected_input_devices = control_mapping_manager.get_connected_devices()
		display_controller.update_input_devices(connected_input_devices)
	
	device_configuration_completed.emit(available_audio_devices + connected_input_devices)

func _show_validation_errors(validation: Dictionary) -> void:
	\"\"\"Show validation errors to user.\"\"\"
	var error_message: String = \"Configuration validation errors:\\n\"
	
	for error in validation.audio_errors:
		error_message += \"Audio: \" + error + \"\\n\"
	
	for error in validation.control_errors:
		error_message += \"Controls: \" + error + \"\\n\"
	
	for conflict in validation.conflicts:
		error_message += \"Conflict: \" + conflict.action1 + \" conflicts with \" + conflict.action2 + \"\\n\"
	
	push_warning(error_message)
	
	# Could show a dialog with validation errors
	# For now, just output to console

func _estimate_system_memory_usage() -> float:
	\"\"\"Estimate system memory usage in MB.\"\"\"
	var base_usage: float = 20.0  # Base system memory
	
	if current_audio_settings:
		base_usage += current_audio_settings.get_estimated_memory_usage()
	
	# Add memory for UI components
	base_usage += 15.0
	
	return base_usage

func _get_component_status() -> Dictionary:
	\"\"\"Get status of all system components.\"\"\"
	return {
		\"audio_data_manager\": audio_data_manager != null,
		\"control_mapping_manager\": control_mapping_manager != null,
		\"display_controller\": display_controller != null,
		\"audio_settings_loaded\": current_audio_settings != null,
		\"control_mapping_loaded\": current_control_mapping != null,
		\"device_detection_enabled\": enable_device_detection,
		\"real_time_testing_enabled\": enable_real_time_audio_testing
	}

func _get_configuration_status() -> Dictionary:
	\"\"\"Get configuration status.\"\"\"
	var validation: Dictionary = validate_current_settings()
	
	return {
		\"configuration_valid\": validation.is_valid,
		\"audio_errors_count\": validation.audio_errors.size(),
		\"control_errors_count\": validation.control_errors.size(),
		\"conflicts_count\": validation.conflicts.size(),
		\"accessibility_optimized\": _check_accessibility_optimization()
	}

func _check_accessibility_optimization() -> bool:
	\"\"\"Check if accessibility features are optimized.\"\"\"
	if not current_audio_settings or not current_control_mapping:
		return false
	
	return (current_audio_settings.audio_cues_enabled and 
			current_audio_settings.subtitles_enabled and 
			current_control_mapping.sticky_keys)

# ============================================================================
# INTEGRATION WITH MAIN MENU SYSTEM
# ============================================================================

func integrate_with_main_menu(main_menu_controller: Node) -> void:
	\"\"\"Integrate with main menu system.\"\"\"
	if main_menu_controller.has_signal(\"audio_control_options_requested\"):
		main_menu_controller.audio_control_options_requested.connect(_on_audio_control_options_requested)

func integrate_with_options_menu(options_coordinator: Node) -> void:
	\"\"\"Integrate with options menu coordinator.\"\"\"
	if options_coordinator:
		options_applied.connect(options_coordinator._on_audio_control_options_applied)
		options_cancelled.connect(options_coordinator._on_audio_control_options_cancelled)

func _on_audio_control_options_requested() -> void:
	\"\"\"Handle audio control options request from main menu.\"\"\"
	show_audio_control_options()

# ============================================================================
# DEBUGGING AND TESTING SUPPORT
# ============================================================================

func debug_show_test_options() -> void:
	\"\"\"Show test audio and control options for debugging.\"\"\"
	var test_audio_settings: AudioSettingsData = _create_test_audio_settings()
	var test_control_mapping: ControlMappingData = _create_test_control_mapping()
	
	current_audio_settings = test_audio_settings
	current_control_mapping = test_control_mapping
	
	if display_controller:
		display_controller.show_audio_control_options(test_audio_settings, test_control_mapping)
	
	show()

func _create_test_audio_settings() -> AudioSettingsData:
	\"\"\"Create test audio settings.\"\"\"
	var settings: AudioSettingsData = AudioSettingsData.new()
	settings.master_volume = 0.8
	settings.music_volume = 0.7
	settings.effects_volume = 0.9
	settings.voice_volume = 1.0
	settings.enable_3d_audio = true
	settings.voice_enabled = true
	settings.subtitles_enabled = false
	return settings

func _create_test_control_mapping() -> ControlMappingData:
	\"\"\"Create test control mapping.\"\"\"
	var mapping: ControlMappingData = ControlMappingData.new()
	mapping.mouse_sensitivity = 1.2
	mapping.gamepad_sensitivity = 1.0
	mapping.mouse_invert_y = false
	mapping.gamepad_vibration_enabled = true
	return mapping

func debug_get_system_info() -> Dictionary:
	\"\"\"Get debugging information about the audio and control system.\"\"\"
	return get_system_diagnostics()

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_audio_control_system() -> AudioControlSystemCoordinator:
	\"\"\"Create a new audio control system coordinator instance from scene.\"\"\"
	var scene: PackedScene = preload(\"res://scenes/menus/options/audio_control_system.tscn\")
	var coordinator: AudioControlSystemCoordinator = scene.instantiate() as AudioControlSystemCoordinator
	return coordinator

static func launch_audio_control_options(parent_node: Node) -> AudioControlSystemCoordinator:
	\"\"\"Launch audio control options system.\"\"\"
	var coordinator: AudioControlSystemCoordinator = create_audio_control_system()
	parent_node.add_child(coordinator)
	coordinator.show_audio_control_options()
	return coordinator