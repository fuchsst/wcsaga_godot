class_name GraphicsOptionsDisplayController
extends Control

## Graphics options display controller for WCS-Godot conversion.
## Handles user interface, real-time preview, and settings interaction.
## Works with graphics_options.tscn scene for complete options interface.

signal settings_changed(settings: GraphicsSettingsData)
signal preset_selected(preset_name: String)
signal settings_applied()
signal settings_cancelled()
signal preview_toggled(enabled: bool)

# UI Controls (from scene)
@onready var resolution_option: OptionButton = $MainContainer/LeftPanel/ResolutionGroup/ResolutionOption
@onready var fullscreen_option: OptionButton = $MainContainer/LeftPanel/ResolutionGroup/FullscreenOption
@onready var vsync_check: CheckBox = $MainContainer/LeftPanel/ResolutionGroup/VsyncCheck
@onready var fps_limit_spin: SpinBox = $MainContainer/LeftPanel/ResolutionGroup/FpsLimitSpin

@onready var texture_quality_option: OptionButton = $MainContainer/LeftPanel/QualityGroup/TextureQualityOption
@onready var shadow_quality_option: OptionButton = $MainContainer/LeftPanel/QualityGroup/ShadowQualityOption
@onready var effects_quality_option: OptionButton = $MainContainer/LeftPanel/QualityGroup/EffectsQualityOption
@onready var model_quality_option: OptionButton = $MainContainer/LeftPanel/QualityGroup/ModelQualityOption

@onready var preset_option: OptionButton = $MainContainer/RightPanel/PresetGroup/PresetOption
@onready var aa_enabled_check: CheckBox = $MainContainer/RightPanel/AdvancedGroup/AntiAliasingCheck
@onready var aa_level_option: OptionButton = $MainContainer/RightPanel/AdvancedGroup/AntiAliasingLevelOption
@onready var motion_blur_check: CheckBox = $MainContainer/RightPanel/AdvancedGroup/MotionBlurCheck
@onready var bloom_check: CheckBox = $MainContainer/RightPanel/AdvancedGroup/BloomCheck

@onready var performance_fps_label: Label = $MainContainer/RightPanel/PerformanceGroup/FpsLabel
@onready var performance_memory_label: Label = $MainContainer/RightPanel/PerformanceGroup/MemoryLabel
@onready var performance_rating_label: Label = $MainContainer/RightPanel/PerformanceGroup/RatingLabel

@onready var preview_button: Button = $MainContainer/ButtonContainer/PreviewButton
@onready var apply_button: Button = $MainContainer/ButtonContainer/ApplyButton
@onready var cancel_button: Button = $MainContainer/ButtonContainer/CancelButton
@onready var reset_button: Button = $MainContainer/ButtonContainer/ResetButton

# Current state
var current_settings: GraphicsSettingsData = null
var original_settings: GraphicsSettingsData = null
var preview_enabled: bool = false
var available_resolutions: Array[Vector2i] = []

# Configuration
@export var enable_real_time_preview: bool = true
@export var enable_performance_monitoring: bool = true
@export var enable_hardware_detection: bool = true

func _ready() -> void:
	"""Initialize graphics options display controller."""
	_setup_ui_controls()
	_setup_signal_connections()
	_detect_available_resolutions()

func _setup_ui_controls() -> void:
	"""Setup UI control options and defaults."""
	# Setup resolution options
	_populate_resolution_options()
	
	# Setup fullscreen mode options
	fullscreen_option.add_item("Windowed", GraphicsSettingsData.FullscreenMode.WINDOWED)
	fullscreen_option.add_item("Borderless Fullscreen", GraphicsSettingsData.FullscreenMode.BORDERLESS)
	fullscreen_option.add_item("Exclusive Fullscreen", GraphicsSettingsData.FullscreenMode.EXCLUSIVE)
	
	# Setup quality options
	for i in range(5):
		var quality_name: String = GraphicsSettingsData.new().get_quality_level_name(i)
		texture_quality_option.add_item(quality_name, i)
		shadow_quality_option.add_item(quality_name, i)
		effects_quality_option.add_item(quality_name, i)
		model_quality_option.add_item(quality_name, i)
	
	# Setup anti-aliasing level options
	aa_level_option.add_item("2x MSAA", 1)
	aa_level_option.add_item("4x MSAA", 2)
	aa_level_option.add_item("8x MSAA", 3)
	
	# Setup preset options
	preset_option.add_item("Low", 0)
	preset_option.add_item("Medium", 1)
	preset_option.add_item("High", 2)
	preset_option.add_item("Ultra", 3)
	preset_option.add_item("Custom", 4)
	
	# Setup FPS limit spinner
	fps_limit_spin.min_value = 0
	fps_limit_spin.max_value = 300
	fps_limit_spin.step = 5

func _setup_signal_connections() -> void:
	"""Setup signal connections for UI controls."""
	# Resolution and display settings
	resolution_option.item_selected.connect(_on_resolution_changed)
	fullscreen_option.item_selected.connect(_on_fullscreen_changed)
	vsync_check.toggled.connect(_on_vsync_toggled)
	fps_limit_spin.value_changed.connect(_on_fps_limit_changed)
	
	# Quality settings
	texture_quality_option.item_selected.connect(_on_texture_quality_changed)
	shadow_quality_option.item_selected.connect(_on_shadow_quality_changed)
	effects_quality_option.item_selected.connect(_on_effects_quality_changed)
	model_quality_option.item_selected.connect(_on_model_quality_changed)
	
	# Advanced settings
	preset_option.item_selected.connect(_on_preset_selected)
	aa_enabled_check.toggled.connect(_on_antialiasing_toggled)
	aa_level_option.item_selected.connect(_on_antialiasing_level_changed)
	motion_blur_check.toggled.connect(_on_motion_blur_toggled)
	bloom_check.toggled.connect(_on_bloom_toggled)
	
	# Buttons
	preview_button.pressed.connect(_on_preview_toggled)
	apply_button.pressed.connect(_on_apply_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

func _detect_available_resolutions() -> void:
	"""Detect available screen resolutions."""
	available_resolutions.clear()
	
	# Add common resolutions
	var common_resolutions: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(1366, 768),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160)
	]
	
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	
	# Add resolutions that fit on screen
	for res in common_resolutions:
		if res.x <= screen_size.x and res.y <= screen_size.y:
			available_resolutions.append(res)
	
	# Always add current screen resolution
	if not available_resolutions.has(screen_size):
		available_resolutions.append(screen_size)

func _populate_resolution_options() -> void:
	"""Populate resolution option button."""
	resolution_option.clear()
	
	for i in range(available_resolutions.size()):
		var res: Vector2i = available_resolutions[i]
		var res_text: String = str(res.x) + "x" + str(res.y)
		resolution_option.add_item(res_text, i)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_graphics_options(settings: GraphicsSettingsData) -> void:
	"""Show graphics options with current settings."""
	if not settings:
		push_error("Cannot show graphics options with null settings")
		return
	
	current_settings = settings.clone()
	original_settings = settings.clone()
	
	_update_ui_from_settings(current_settings)
	show()

func update_performance_metrics(metrics: Dictionary) -> void:
	"""Update performance monitoring display."""
	if not enable_performance_monitoring:
		return
	
	var current_fps: float = metrics.get("current_fps", 0.0)
	var current_memory: float = metrics.get("current_memory", 0.0)
	var avg_fps: float = metrics.get("average_fps", 0.0)
	
	# Update FPS display
	performance_fps_label.text = "FPS: %.1f (Avg: %.1f)" % [current_fps, avg_fps]
	
	# Update memory display (convert to MB)
	var memory_mb: float = current_memory / (1024.0 * 1024.0)
	performance_memory_label.text = "Memory: %.1f MB" % memory_mb
	
	# Update performance rating
	var rating: String = _calculate_performance_rating(current_fps, memory_mb)
	performance_rating_label.text = "Rating: " + rating
	
	# Color-code based on performance
	match rating:
		"Excellent":
			performance_rating_label.modulate = Color.GREEN
		"Good":
			performance_rating_label.modulate = Color.YELLOW
		"Fair":
			performance_rating_label.modulate = Color.ORANGE
		"Poor":
			performance_rating_label.modulate = Color.RED

func apply_preset(preset_name: String, settings: GraphicsSettingsData) -> void:
	"""Apply a graphics preset."""
	if not settings:
		return
	
	current_settings = settings.clone()
	_update_ui_from_settings(current_settings)
	
	# Set preset selection
	var preset_names: Array[String] = ["low", "medium", "high", "ultra", "custom"]
	var preset_index: int = preset_names.find(preset_name.to_lower())
	if preset_index >= 0:
		preset_option.selected = preset_index

func get_current_settings() -> GraphicsSettingsData:
	"""Get current settings from UI."""
	return current_settings.clone() if current_settings else null

func close_graphics_options() -> void:
	"""Close graphics options interface."""
	hide()

# ============================================================================
# UI UPDATE METHODS
# ============================================================================

func _update_ui_from_settings(settings: GraphicsSettingsData) -> void:
	"""Update UI controls to reflect current settings."""
	if not settings:
		return
	
	# Update resolution
	var resolution_index: int = _find_resolution_index(settings.resolution_width, settings.resolution_height)
	if resolution_index >= 0:
		resolution_option.selected = resolution_index
	
	# Update display settings
	fullscreen_option.selected = settings.fullscreen_mode
	vsync_check.button_pressed = settings.vsync_enabled
	fps_limit_spin.value = settings.max_fps
	
	# Update quality settings
	texture_quality_option.selected = settings.texture_quality
	shadow_quality_option.selected = settings.shadow_quality
	effects_quality_option.selected = settings.effects_quality
	model_quality_option.selected = settings.model_quality
	
	# Update advanced settings
	aa_enabled_check.button_pressed = settings.antialiasing_enabled
	aa_level_option.selected = settings.antialiasing_level - 1  # Convert to 0-based index
	motion_blur_check.button_pressed = settings.motion_blur_enabled
	bloom_check.button_pressed = settings.bloom_enabled
	
	# Enable/disable anti-aliasing level based on checkbox
	aa_level_option.disabled = not settings.antialiasing_enabled

func _find_resolution_index(width: int, height: int) -> int:
	"""Find index of resolution in available resolutions."""
	for i in range(available_resolutions.size()):
		var res: Vector2i = available_resolutions[i]
		if res.x == width and res.y == height:
			return i
	return -1

func _calculate_performance_rating(fps: float, memory_mb: float) -> String:
	"""Calculate performance rating based on metrics."""
	if fps >= 120 and memory_mb < 2000:
		return "Excellent"
	elif fps >= 60 and memory_mb < 4000:
		return "Good"
	elif fps >= 30 and memory_mb < 6000:
		return "Fair"
	else:
		return "Poor"

# ============================================================================
# SIGNAL HANDLERS - RESOLUTION AND DISPLAY
# ============================================================================

func _on_resolution_changed(index: int) -> void:
	"""Handle resolution selection change."""
	if not current_settings or index < 0 or index >= available_resolutions.size():
		return
	
	var resolution: Vector2i = available_resolutions[index]
	current_settings.resolution_width = resolution.x
	current_settings.resolution_height = resolution.y
	
	_mark_as_custom_preset()
	_apply_real_time_preview()

func _on_fullscreen_changed(index: int) -> void:
	"""Handle fullscreen mode change."""
	if not current_settings:
		return
	
	current_settings.fullscreen_mode = index as GraphicsSettingsData.FullscreenMode
	
	_mark_as_custom_preset()
	_apply_real_time_preview()

func _on_vsync_toggled(enabled: bool) -> void:
	"""Handle V-Sync toggle."""
	if not current_settings:
		return
	
	current_settings.vsync_enabled = enabled
	
	_mark_as_custom_preset()
	_apply_real_time_preview()

func _on_fps_limit_changed(value: float) -> void:
	"""Handle FPS limit change."""
	if not current_settings:
		return
	
	current_settings.max_fps = int(value)
	
	_mark_as_custom_preset()
	_apply_real_time_preview()

# ============================================================================
# SIGNAL HANDLERS - QUALITY SETTINGS
# ============================================================================

func _on_texture_quality_changed(index: int) -> void:
	"""Handle texture quality change."""
	if not current_settings:
		return
	
	current_settings.texture_quality = index
	
	_mark_as_custom_preset()
	_apply_real_time_preview()

func _on_shadow_quality_changed(index: int) -> void:
	"""Handle shadow quality change."""
	if not current_settings:
		return
	
	current_settings.shadow_quality = index
	
	_mark_as_custom_preset()
	_apply_real_time_preview()

func _on_effects_quality_changed(index: int) -> void:
	"""Handle effects quality change."""
	if not current_settings:
		return
	
	current_settings.effects_quality = index
	
	_mark_as_custom_preset()
	_apply_real_time_preview()

func _on_model_quality_changed(index: int) -> void:
	"""Handle model quality change."""
	if not current_settings:
		return
	
	current_settings.model_quality = index
	
	_mark_as_custom_preset()
	_apply_real_time_preview()

# ============================================================================
# SIGNAL HANDLERS - ADVANCED SETTINGS
# ============================================================================

func _on_preset_selected(index: int) -> void:
	"""Handle preset selection."""
	var preset_names: Array[String] = ["low", "medium", "high", "ultra", "custom"]
	
	if index < 0 or index >= preset_names.size():
		return
	
	var preset_name: String = preset_names[index]
	
	if preset_name != "custom":
		preset_selected.emit(preset_name)

func _on_antialiasing_toggled(enabled: bool) -> void:
	"""Handle anti-aliasing toggle."""
	if not current_settings:
		return
	
	current_settings.antialiasing_enabled = enabled
	aa_level_option.disabled = not enabled
	
	_mark_as_custom_preset()
	_apply_real_time_preview()

func _on_antialiasing_level_changed(index: int) -> void:
	"""Handle anti-aliasing level change."""
	if not current_settings:
		return
	
	current_settings.antialiasing_level = index + 1  # Convert to 1-based
	
	_mark_as_custom_preset()
	_apply_real_time_preview()

func _on_motion_blur_toggled(enabled: bool) -> void:
	"""Handle motion blur toggle."""
	if not current_settings:
		return
	
	current_settings.motion_blur_enabled = enabled
	
	_mark_as_custom_preset()
	_apply_real_time_preview()

func _on_bloom_toggled(enabled: bool) -> void:
	"""Handle bloom toggle."""
	if not current_settings:
		return
	
	current_settings.bloom_enabled = enabled
	
	_mark_as_custom_preset()
	_apply_real_time_preview()

# ============================================================================
# SIGNAL HANDLERS - BUTTONS
# ============================================================================

func _on_preview_toggled() -> void:
	"""Handle preview button toggle."""
	preview_enabled = not preview_enabled
	
	if preview_enabled:
		preview_button.text = "Disable Preview"
		_apply_real_time_preview()
	else:
		preview_button.text = "Enable Preview"
		# Revert to original settings for preview
		if original_settings:
			_apply_settings_immediately(original_settings)
	
	preview_toggled.emit(preview_enabled)

func _on_apply_pressed() -> void:
	"""Handle apply button press."""
	if current_settings:
		settings_applied.emit()
		original_settings = current_settings.clone()
	close_graphics_options()

func _on_cancel_pressed() -> void:
	"""Handle cancel button press."""
	# Revert to original settings if preview was enabled
	if preview_enabled and original_settings:
		_apply_settings_immediately(original_settings)
	
	settings_cancelled.emit()
	close_graphics_options()

func _on_reset_pressed() -> void:
	"""Handle reset button press."""
	if original_settings:
		current_settings = original_settings.clone()
		_update_ui_from_settings(current_settings)
		_apply_real_time_preview()

# ============================================================================
# HELPER METHODS
# ============================================================================

func _mark_as_custom_preset() -> void:
	"""Mark settings as custom preset."""
	preset_option.selected = 4  # Custom preset index
	
	if current_settings:
		settings_changed.emit(current_settings)

func _apply_real_time_preview() -> void:
	"""Apply real-time preview if enabled."""
	if enable_real_time_preview and preview_enabled and current_settings:
		_apply_settings_immediately(current_settings)

func _apply_settings_immediately(settings: GraphicsSettingsData) -> void:
	"""Apply settings immediately for preview."""
	if not settings:
		return
	
	# Only apply safe preview settings (avoid resolution changes in preview)
	# Full settings application happens in the data manager
	
	# Apply V-Sync
	if settings.vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	# Apply frame rate limit
	if settings.max_fps > 0:
		Engine.max_fps = settings.max_fps
	else:
		Engine.max_fps = 0

func get_options_summary() -> Dictionary:
	"""Get summary of current options for display."""
	if not current_settings:
		return {}
	
	return {
		"resolution": current_settings.get_resolution_string(),
		"fullscreen_mode": current_settings.get_fullscreen_mode_name(current_settings.fullscreen_mode),
		"quality_level": "Custom" if preset_option.selected == 4 else preset_option.get_item_text(preset_option.selected),
		"antialiasing": current_settings.get_antialiasing_name(current_settings.antialiasing_level) if current_settings.antialiasing_enabled else "Disabled",
		"vsync": "Enabled" if current_settings.vsync_enabled else "Disabled",
		"fps_limit": str(current_settings.max_fps) if current_settings.max_fps > 0 else "Unlimited",
		"performance_impact": current_settings.get_estimated_performance_impact()
	}

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_graphics_options_display_controller() -> GraphicsOptionsDisplayController:
	"""Create a new graphics options display controller instance."""
	var controller: GraphicsOptionsDisplayController = GraphicsOptionsDisplayController.new()
	return controller