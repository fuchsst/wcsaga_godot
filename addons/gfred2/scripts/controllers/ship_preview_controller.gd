@tool
class_name ShipPreviewController
extends Control

## Ship preview controller for GFRED2-009 Advanced Ship Configuration.
## Scene-based UI controller for managing 3D ship preview with real-time updates.
## Scene: addons/gfred2/scenes/dialogs/ship_editor/ship_preview_panel.tscn

signal preview_options_changed(option_name: String, value: Variant)
signal camera_view_changed(view_type: String)
signal preview_captured(texture: ImageTexture)

# Current configuration
var current_ship_config: ShipConfigurationData = null

# Scene node references (populated by .tscn file)
@onready var ship_preview_3d: ShipPreview3D = $VBoxContainer/PreviewContainer/ShipPreview3D
@onready var preview_controls: HBoxContainer = $VBoxContainer/PreviewControls

@onready var view_front_button: Button = $VBoxContainer/PreviewControls/ViewButtons/FrontButton
@onready var view_side_button: Button = $VBoxContainer/PreviewControls/ViewButtons/SideButton
@onready var view_top_button: Button = $VBoxContainer/PreviewControls/ViewButtons/TopButton
@onready var view_iso_button: Button = $VBoxContainer/PreviewControls/ViewButtons/IsoButton

@onready var auto_rotate_check: CheckBox = $VBoxContainer/PreviewControls/Options/AutoRotateCheck
@onready var show_hardpoints_check: CheckBox = $VBoxContainer/PreviewControls/Options/ShowHardpointsCheck
@onready var show_damage_check: CheckBox = $VBoxContainer/PreviewControls/Options/ShowDamageCheck

@onready var zoom_slider: HSlider = $VBoxContainer/PreviewControls/Zoom/ZoomSlider
@onready var zoom_spin: SpinBox = $VBoxContainer/PreviewControls/Zoom/ZoomSpin

@onready var capture_button: Button = $VBoxContainer/PreviewControls/Actions/CaptureButton
@onready var reset_camera_button: Button = $VBoxContainer/PreviewControls/Actions/ResetCameraButton

@onready var performance_label: Label = $VBoxContainer/PreviewControls/Performance/PerformanceLabel

# Preview state
var auto_update_enabled: bool = true
var last_update_time: int = 0

func _ready() -> void:
	name = "ShipPreviewController"
	
	# Setup initial UI state
	_setup_initial_state()
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Connect preview signals
	_connect_preview_signals()
	
	# Setup performance monitoring
	_setup_performance_monitoring()
	
	print("ShipPreviewController: Controller initialized")

## Updates ship preview with configuration
func update_ship_preview(ship_config: ShipConfigurationData) -> void:
	if not ship_config or not ship_preview_3d:
		return
	
	current_ship_config = ship_config
	
	if auto_update_enabled:
		var start_time: int = Time.get_ticks_msec()
		
		# Update 3D preview
		ship_preview_3d.update_ship_preview(ship_config)
		
		last_update_time = Time.get_ticks_msec() - start_time
		_update_performance_display()

## Sets up initial UI state
func _setup_initial_state() -> void:
	# Set default view
	view_iso_button.button_pressed = true
	
	# Set default options
	auto_rotate_check.button_pressed = true
	show_hardpoints_check.button_pressed = false
	show_damage_check.button_pressed = false
	
	# Setup zoom controls
	zoom_slider.min_value = 0.1
	zoom_slider.max_value = 5.0
	zoom_slider.value = 1.0
	zoom_slider.step = 0.1
	
	zoom_spin.min_value = 0.1
	zoom_spin.max_value = 5.0
	zoom_spin.value = 1.0
	zoom_spin.step = 0.1
	
	# Initial performance display
	performance_label.text = "Ready"

## Connects UI signal handlers
func _connect_ui_signals() -> void:
	# View buttons
	view_front_button.pressed.connect(_on_view_front_pressed)
	view_side_button.pressed.connect(_on_view_side_pressed)
	view_top_button.pressed.connect(_on_view_top_pressed)
	view_iso_button.pressed.connect(_on_view_iso_pressed)
	
	# Options
	auto_rotate_check.toggled.connect(_on_auto_rotate_toggled)
	show_hardpoints_check.toggled.connect(_on_show_hardpoints_toggled)
	show_damage_check.toggled.connect(_on_show_damage_toggled)
	
	# Zoom controls
	zoom_slider.value_changed.connect(_on_zoom_changed)
	zoom_spin.value_changed.connect(func(value: float): zoom_slider.value = value)
	
	# Actions
	capture_button.pressed.connect(_on_capture_pressed)
	reset_camera_button.pressed.connect(_on_reset_camera_pressed)

## Connects 3D preview signals
func _connect_preview_signals() -> void:
	if not ship_preview_3d:
		return
	
	ship_preview_3d.preview_ready.connect(_on_preview_ready)
	ship_preview_3d.ship_model_loaded.connect(_on_ship_model_loaded)
	ship_preview_3d.texture_applied.connect(_on_texture_applied)
	ship_preview_3d.weapon_preview_updated.connect(_on_weapon_preview_updated)

## Sets up performance monitoring
func _setup_performance_monitoring() -> void:
	# Create timer for periodic performance updates
	var performance_timer: Timer = Timer.new()
	performance_timer.wait_time = 1.0  # Update every second
	performance_timer.timeout.connect(_update_performance_display)
	performance_timer.autostart = true
	add_child(performance_timer)

## Updates performance display
func _update_performance_display() -> void:
	if not ship_preview_3d:
		performance_label.text = "Preview not available"
		return
	
	var stats: Dictionary = ship_preview_3d.get_performance_stats()
	var fps: int = Engine.get_frames_per_second()
	
	var performance_text: String = "FPS: %d | Update: %dms" % [fps, last_update_time]
	
	if stats.has("model_load_time") and stats["model_load_time"] > 0:
		performance_text += " | Load: %dms" % stats["model_load_time"]
	
	# Color code based on performance
	if fps >= 60 and last_update_time < 16:
		performance_label.modulate = Color.GREEN
	elif fps >= 30 and last_update_time < 33:
		performance_label.modulate = Color.YELLOW
	else:
		performance_label.modulate = Color.RED
	
	performance_label.text = performance_text

## Signal handlers

func _on_view_front_pressed() -> void:
	if ship_preview_3d:
		ship_preview_3d.set_camera_view("front")
		camera_view_changed.emit("front")
	_clear_view_button_states()
	view_front_button.button_pressed = true

func _on_view_side_pressed() -> void:
	if ship_preview_3d:
		ship_preview_3d.set_camera_view("side")
		camera_view_changed.emit("side")
	_clear_view_button_states()
	view_side_button.button_pressed = true

func _on_view_top_pressed() -> void:
	if ship_preview_3d:
		ship_preview_3d.set_camera_view("top")
		camera_view_changed.emit("top")
	_clear_view_button_states()
	view_top_button.button_pressed = true

func _on_view_iso_pressed() -> void:
	if ship_preview_3d:
		ship_preview_3d.set_camera_view("isometric")
		camera_view_changed.emit("isometric")
	_clear_view_button_states()
	view_iso_button.button_pressed = true

func _clear_view_button_states() -> void:
	view_front_button.button_pressed = false
	view_side_button.button_pressed = false
	view_top_button.button_pressed = false
	view_iso_button.button_pressed = false

func _on_auto_rotate_toggled(enabled: bool) -> void:
	if ship_preview_3d:
		ship_preview_3d.auto_rotate = enabled
		preview_options_changed.emit("auto_rotate", enabled)

func _on_show_hardpoints_toggled(enabled: bool) -> void:
	# TODO: Implement weapon hardpoint visualization
	preview_options_changed.emit("show_hardpoints", enabled)
	print("ShipPreviewController: Show hardpoints toggled: %s" % enabled)

func _on_show_damage_toggled(enabled: bool) -> void:
	# TODO: Implement damage visualization
	preview_options_changed.emit("show_damage", enabled)
	print("ShipPreviewController: Show damage toggled: %s" % enabled)

func _on_zoom_changed(value: float) -> void:
	zoom_spin.value = value
	
	if ship_preview_3d:
		ship_preview_3d.zoom_camera(value)
		preview_options_changed.emit("zoom", value)

func _on_capture_pressed() -> void:
	if not ship_preview_3d:
		return
	
	var preview_texture: ImageTexture = ship_preview_3d.capture_preview()
	if preview_texture:
		preview_captured.emit(preview_texture)
		print("ShipPreviewController: Preview captured")
	else:
		print("ShipPreviewController: Failed to capture preview")

func _on_reset_camera_pressed() -> void:
	if ship_preview_3d:
		ship_preview_3d.set_camera_view("isometric")
		zoom_slider.value = 1.0
		zoom_spin.value = 1.0
		
		_clear_view_button_states()
		view_iso_button.button_pressed = true
		
		camera_view_changed.emit("reset")

func _on_preview_ready() -> void:
	print("ShipPreviewController: 3D preview ready")
	
	# Enable preview controls
	preview_controls.modulate = Color.WHITE
	
	# Apply current preview options
	if ship_preview_3d:
		ship_preview_3d.auto_rotate = auto_rotate_check.button_pressed
		ship_preview_3d.set_camera_view("isometric")

func _on_ship_model_loaded(model_path: String) -> void:
	print("ShipPreviewController: Ship model loaded: %s" % model_path)
	_update_performance_display()

func _on_texture_applied(texture_path: String) -> void:
	print("ShipPreviewController: Texture applied: %s" % texture_path)

func _on_weapon_preview_updated() -> void:
	print("ShipPreviewController: Weapon preview updated")

## Public API

## Gets current ship configuration
func get_current_ship_config() -> ShipConfigurationData:
	return current_ship_config

## Enables or disables auto-update
func set_auto_update(enabled: bool) -> void:
	auto_update_enabled = enabled
	
	if enabled and current_ship_config:
		update_ship_preview(current_ship_config)

## Checks if auto-update is enabled
func is_auto_update_enabled() -> bool:
	return auto_update_enabled

## Forces preview update
func force_update() -> void:
	if current_ship_config:
		update_ship_preview(current_ship_config)

## Sets preview options
func set_preview_options(options: Dictionary) -> void:
	if options.has("auto_rotate"):
		auto_rotate_check.button_pressed = options["auto_rotate"]
		_on_auto_rotate_toggled(options["auto_rotate"])
	
	if options.has("show_hardpoints"):
		show_hardpoints_check.button_pressed = options["show_hardpoints"]
		_on_show_hardpoints_toggled(options["show_hardpoints"])
	
	if options.has("show_damage"):
		show_damage_check.button_pressed = options["show_damage"]
		_on_show_damage_toggled(options["show_damage"])
	
	if options.has("zoom"):
		zoom_slider.value = options["zoom"]
		zoom_spin.value = options["zoom"]
		_on_zoom_changed(options["zoom"])

## Gets current preview options
func get_preview_options() -> Dictionary:
	return {
		"auto_rotate": auto_rotate_check.button_pressed,
		"show_hardpoints": show_hardpoints_check.button_pressed,
		"show_damage": show_damage_check.button_pressed,
		"zoom": zoom_slider.value
	}

## Gets preview performance statistics
func get_preview_performance() -> Dictionary:
	var stats: Dictionary = {
		"last_update_time": last_update_time,
		"current_fps": Engine.get_frames_per_second(),
		"preview_ready": ship_preview_3d != null and ship_preview_3d.is_preview_ready()
	}
	
	if ship_preview_3d:
		var preview_stats: Dictionary = ship_preview_3d.get_performance_stats()
		stats.merge(preview_stats)
	
	return stats

## Checks if preview is ready
func is_preview_ready() -> bool:
	return ship_preview_3d != null and ship_preview_3d.is_preview_ready()

## Gets preview texture for external use
func get_preview_texture() -> Texture2D:
	if ship_preview_3d:
		return ship_preview_3d.get_preview_texture()
	return null