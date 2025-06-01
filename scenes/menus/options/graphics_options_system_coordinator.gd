class_name GraphicsOptionsSystemCoordinator
extends Control

## Complete graphics options system coordination for WCS-Godot conversion.
## Orchestrates data management, display, and settings application.
## Provides unified interface for graphics configuration workflow.

signal options_applied(settings: GraphicsSettingsData)
signal options_cancelled()
signal preset_changed(preset_name: String, settings: GraphicsSettingsData)
signal hardware_optimization_completed(settings: GraphicsSettingsData)

# System components (from scene)
@onready var graphics_data_manager: GraphicsOptionsDataManager = $GraphicsDataManager
@onready var graphics_display_controller: GraphicsOptionsDisplayController = $GraphicsDisplayController

# Current state
var current_settings: GraphicsSettingsData = null
var available_presets: Array[String] = []
var hardware_info: Dictionary = {}

# Integration helpers
var configuration_manager: ConfigurationManager = null

# Configuration
@export var enable_automatic_hardware_optimization: bool = true
@export var enable_real_time_performance_monitoring: bool = true
@export var enable_settings_validation: bool = true
@export var enable_preset_recommendations: bool = true

func _ready() -> void:
	"""Initialize graphics options system coordinator."""
	_setup_dependencies()
	_setup_signal_connections()

func _setup_dependencies() -> void:
	"""Setup required dependencies."""
	# ConfigurationManager is an autoload, so it's always available
	configuration_manager = ConfigurationManager

func _setup_signal_connections() -> void:
	"""Setup signal connections between components."""
	# Data manager signals
	if graphics_data_manager:
		graphics_data_manager.settings_loaded.connect(_on_settings_loaded)
		graphics_data_manager.settings_saved.connect(_on_settings_saved)
		graphics_data_manager.preset_applied.connect(_on_preset_applied)
		graphics_data_manager.hardware_detected.connect(_on_hardware_detected)
		graphics_data_manager.performance_updated.connect(_on_performance_updated)
	
	# Display controller signals
	if graphics_display_controller:
		graphics_display_controller.settings_changed.connect(_on_settings_changed)
		graphics_display_controller.preset_selected.connect(_on_preset_selected)
		graphics_display_controller.settings_applied.connect(_on_settings_applied)
		graphics_display_controller.settings_cancelled.connect(_on_settings_cancelled)
		graphics_display_controller.preview_toggled.connect(_on_preview_toggled)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_graphics_options() -> void:
	"""Show graphics options interface."""
	if graphics_data_manager:
		# Load current settings
		current_settings = graphics_data_manager.load_graphics_settings()
		available_presets = graphics_data_manager.get_available_presets()
	
	if graphics_display_controller and current_settings:
		graphics_display_controller.show_graphics_options(current_settings)
	
	show()

func close_graphics_options() -> void:
	"""Close graphics options interface."""
	if graphics_display_controller:
		graphics_display_controller.close_graphics_options()
	
	hide()

func apply_graphics_preset(preset_name: String) -> void:
	"""Apply a graphics preset."""
	if not graphics_data_manager:
		push_error("Graphics data manager not available")
		return
	
	var preset_settings: GraphicsSettingsData = graphics_data_manager.apply_preset_configuration(preset_name)
	
	if preset_settings and graphics_display_controller:
		graphics_display_controller.apply_preset(preset_name, preset_settings)

func get_current_graphics_settings() -> GraphicsSettingsData:
	"""Get current graphics settings."""
	return current_settings.clone() if current_settings else null

func get_available_presets() -> Array[String]:
	"""Get list of available graphics presets."""
	return available_presets.duplicate()

func get_recommended_preset() -> String:
	"""Get recommended preset based on hardware."""
	if graphics_data_manager:
		return graphics_data_manager.get_recommended_preset()
	return "medium"

func optimize_for_hardware() -> void:
	"""Automatically optimize settings for detected hardware."""
	if not enable_automatic_hardware_optimization or not graphics_data_manager:
		return
	
	var recommended_preset: String = graphics_data_manager.get_recommended_preset()
	apply_graphics_preset(recommended_preset)
	
	hardware_optimization_completed.emit(current_settings)

func validate_current_settings() -> Array[String]:
	"""Validate current graphics settings."""
	if not enable_settings_validation or not graphics_data_manager or not current_settings:
		return []
	
	return graphics_data_manager.validate_settings(current_settings)

func get_performance_metrics() -> Dictionary:
	"""Get current performance metrics."""
	if graphics_data_manager:
		return graphics_data_manager.get_current_performance_metrics()
	return {}

func get_hardware_info() -> Dictionary:
	"""Get detected hardware information."""
	return hardware_info.duplicate()

# ============================================================================
# WORKFLOW COORDINATION
# ============================================================================

func _on_settings_loaded(settings: GraphicsSettingsData) -> void:
	"""Handle settings loaded from data manager."""
	current_settings = settings
	
	# Update display if visible
	if graphics_display_controller and visible:
		graphics_display_controller.show_graphics_options(settings)

func _on_settings_saved(settings: GraphicsSettingsData) -> void:
	"""Handle settings saved by data manager."""
	current_settings = settings
	
	# Settings have been successfully saved and applied
	options_applied.emit(settings)

func _on_preset_applied(preset_name: String, settings: GraphicsSettingsData) -> void:
	"""Handle preset application completion."""
	current_settings = settings
	
	# Update display controller with new preset settings
	if graphics_display_controller:
		graphics_display_controller.apply_preset(preset_name, settings)
	
	preset_changed.emit(preset_name, settings)

func _on_hardware_detected(hardware_info_dict: Dictionary) -> void:
	"""Handle hardware detection completion."""
	hardware_info = hardware_info_dict.duplicate()
	
	# If preset recommendations are enabled, suggest optimal settings
	if enable_preset_recommendations:
		_suggest_optimal_preset()

func _on_performance_updated(performance_metrics: Dictionary) -> void:
	"""Handle performance metrics update."""
	if enable_real_time_performance_monitoring and graphics_display_controller:
		graphics_display_controller.update_performance_metrics(performance_metrics)

# ============================================================================
# USER INTERACTION HANDLERS
# ============================================================================

func _on_settings_changed(settings: GraphicsSettingsData) -> void:
	"""Handle settings change from display controller."""
	current_settings = settings
	
	# Validate settings if validation is enabled
	if enable_settings_validation:
		var errors: Array[String] = validate_current_settings()
		if not errors.is_empty():
			_show_validation_errors(errors)

func _on_preset_selected(preset_name: String) -> void:
	"""Handle preset selection from display controller."""
	apply_graphics_preset(preset_name)

func _on_settings_applied() -> void:
	"""Handle settings application from display controller."""
	if not graphics_data_manager or not current_settings:
		push_error("Cannot apply settings: missing data manager or settings")
		return
	
	# Validate settings before saving
	if enable_settings_validation:
		var errors: Array[String] = validate_current_settings()
		if not errors.is_empty():
			_show_validation_errors(errors)
			return
	
	# Save settings through data manager
	var save_success: bool = graphics_data_manager.save_graphics_settings(current_settings)
	
	if save_success:
		close_graphics_options()
	else:
		push_error("Failed to save graphics settings")

func _on_settings_cancelled() -> void:
	"""Handle settings cancellation from display controller."""
	options_cancelled.emit()
	close_graphics_options()

func _on_preview_toggled(enabled: bool) -> void:
	"""Handle preview toggle from display controller."""
	# Preview is handled by display controller, just acknowledge
	pass

# ============================================================================
# HELPER METHODS
# ============================================================================

func _suggest_optimal_preset() -> void:
	"""Suggest optimal preset based on hardware detection."""
	if not graphics_data_manager:
		return
	
	var recommended_preset: String = graphics_data_manager.get_recommended_preset()
	
	# Could show a notification or dialog suggesting the optimal preset
	# For now, just log the recommendation
	print("Recommended graphics preset for your hardware: " + recommended_preset)

func _show_validation_errors(errors: Array[String]) -> void:
	"""Show validation errors to user."""
	var error_message: String = "Graphics settings validation errors:\n"
	for error in errors:
		error_message += "- " + error + "\n"
	
	push_warning(error_message)
	
	# Could show a dialog with validation errors
	# For now, just output to console

func _get_settings_summary() -> Dictionary:
	"""Get summary of current settings."""
	var summary: Dictionary = {
		"has_settings": current_settings != null,
		"current_preset": "unknown",
		"hardware_detected": not hardware_info.is_empty(),
		"performance_monitoring": enable_real_time_performance_monitoring,
		"validation_enabled": enable_settings_validation
	}
	
	if graphics_display_controller:
		var display_summary: Dictionary = graphics_display_controller.get_options_summary()
		summary.merge(display_summary)
	
	return summary

# ============================================================================
# INTEGRATION WITH MAIN MENU SYSTEM
# ============================================================================

func integrate_with_main_menu(main_menu_controller: Node) -> void:
	"""Integrate with main menu system."""
	if main_menu_controller.has_signal("graphics_options_requested"):
		main_menu_controller.graphics_options_requested.connect(_on_graphics_options_requested)

func integrate_with_options_menu(options_coordinator: Node) -> void:
	"""Integrate with options menu coordinator."""
	if options_coordinator:
		options_applied.connect(options_coordinator._on_graphics_options_applied)
		options_cancelled.connect(options_coordinator._on_graphics_options_cancelled)

func _on_graphics_options_requested() -> void:
	"""Handle graphics options request from main menu."""
	show_graphics_options()

# ============================================================================
# DEBUGGING AND TESTING SUPPORT
# ============================================================================

func debug_show_test_options() -> void:
	"""Show test graphics options for debugging."""
	var test_settings: GraphicsSettingsData = _create_test_settings()
	current_settings = test_settings
	
	if graphics_display_controller:
		graphics_display_controller.show_graphics_options(test_settings)
	
	show()

func _create_test_settings() -> GraphicsSettingsData:
	"""Create test graphics settings."""
	var settings: GraphicsSettingsData = GraphicsSettingsData.new()
	settings.resolution_width = 1920
	settings.resolution_height = 1080
	settings.fullscreen_mode = GraphicsSettingsData.FullscreenMode.WINDOWED
	settings.vsync_enabled = true
	settings.max_fps = 60
	settings.texture_quality = 2
	settings.shadow_quality = 2
	settings.effects_quality = 2
	settings.antialiasing_enabled = true
	settings.antialiasing_level = 1
	return settings

func debug_get_system_info() -> Dictionary:
	"""Get debugging information about the graphics options system."""
	var info: Dictionary = {
		"has_data_manager": graphics_data_manager != null,
		"has_display_controller": graphics_display_controller != null,
		"current_settings_loaded": current_settings != null,
		"hardware_info_available": not hardware_info.is_empty(),
		"available_presets_count": available_presets.size(),
		"system_visible": visible,
		"automatic_optimization_enabled": enable_automatic_hardware_optimization,
		"performance_monitoring_enabled": enable_real_time_performance_monitoring,
		"settings_validation_enabled": enable_settings_validation,
		"preset_recommendations_enabled": enable_preset_recommendations
	}
	
	var summary: Dictionary = _get_settings_summary()
	info.merge(summary)
	
	if graphics_data_manager:
		var performance_metrics: Dictionary = graphics_data_manager.get_current_performance_metrics()
		info["performance_metrics"] = performance_metrics
	
	return info

func debug_apply_preset(preset_name: String) -> void:
	"""Debug method to apply specific preset."""
	apply_graphics_preset(preset_name)

func debug_force_hardware_optimization() -> void:
	"""Debug method to force hardware optimization."""
	optimize_for_hardware()

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_graphics_options_system() -> GraphicsOptionsSystemCoordinator:
	"""Create a new graphics options system coordinator instance from scene."""
	var scene: PackedScene = preload("res://scenes/menus/options/graphics_options_system.tscn")
	var coordinator: GraphicsOptionsSystemCoordinator = scene.instantiate() as GraphicsOptionsSystemCoordinator
	return coordinator

static func launch_graphics_options(parent_node: Node) -> GraphicsOptionsSystemCoordinator:
	"""Launch graphics options system."""
	var coordinator: GraphicsOptionsSystemCoordinator = create_graphics_options_system()
	parent_node.add_child(coordinator)
	coordinator.show_graphics_options()
	return coordinator