class_name LoadingScreen
extends Control

## WCS-styled loading screen with progress indicators and background task support.
## Provides visual feedback during asset loading, scene transitions, and long operations.
## Integrates with UIThemeManager for consistent styling and responsive design.

signal loading_completed()
signal loading_cancelled()
signal progress_updated(progress: float, status: String)

# Loading screen types
enum LoadingType {
	SCENE_TRANSITION,   # Scene loading/transition
	ASSET_LOADING,      # Asset preloading
	DATA_PROCESSING,    # Data conversion/processing
	NETWORK_OPERATION,  # Network requests
	MISSION_LOADING,    # Mission/campaign loading
	GENERAL            # General purpose loading
}

# Animation styles for progress indication
enum ProgressStyle {
	BAR,               # Traditional progress bar
	CIRCULAR,          # Circular progress indicator
	DOTS,              # Animated dots
	MILITARY_SCAN,     # Military-style scanning effect
	SPINNER            # Rotating spinner
}

# Loading configuration
@export var loading_type: LoadingType = LoadingType.GENERAL
@export var progress_style: ProgressStyle = ProgressStyle.BAR
@export var show_percentage: bool = true
@export var show_status_text: bool = true
@export var show_cancel_button: bool = false
@export var auto_hide_on_complete: bool = true
@export var minimum_display_time: float = 1.0  # Minimum time to show loading screen

# Visual configuration
@export var background_opacity: float = 0.9
@export var enable_particle_effects: bool = true
@export var enable_progress_animations: bool = true

# Internal components
var background_overlay: ColorRect = null
var main_container: Control = null
var title_label: Label = null
var progress_container: Control = null
var progress_bar: ProgressBar = null
var progress_circle: Control = null
var status_label: Label = null
var percentage_label: Label = null
var cancel_button: MenuButton = null

# Animation components
var progress_animation: AnimationPlayer = null
var particle_system: CPUParticles2D = null
var scanning_line: Control = null

# State management
var current_progress: float = 0.0
var current_status: String = ""
var is_loading_active: bool = false
var loading_start_time: float = 0.0
var background_tasks: Array[Dictionary] = []

# Theme integration
var ui_theme_manager: UIThemeManager = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_loading_screen()

func _initialize_loading_screen() -> void:
	"""Initialize the loading screen with WCS styling and components."""
	print("LoadingScreen: Initializing loading screen")
	
	# Connect to theme manager
	_connect_to_theme_manager()
	
	# Setup loading screen structure
	_create_loading_structure()
	_setup_loading_styling()
	_create_progress_indicators()
	_setup_animations()
	
	# Initially hide the loading screen
	visible = false
	modulate.a = 0.0

func _connect_to_theme_manager() -> void:
	"""Connect to UIThemeManager for consistent styling."""
	var theme_manager: Node = get_tree().get_first_node_in_group("ui_theme_manager")
	if theme_manager and theme_manager is UIThemeManager:
		ui_theme_manager = theme_manager as UIThemeManager
		ui_theme_manager.theme_changed.connect(_on_theme_changed)

func _create_loading_structure() -> void:
	"""Create the loading screen structure with all components."""
	# Set as full-screen overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Create background overlay
	background_overlay = ColorRect.new()
	background_overlay.name = "BackgroundOverlay"
	background_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_overlay.color = Color.BLACK
	background_overlay.color.a = background_opacity
	add_child(background_overlay)
	
	# Create main container
	main_container = Control.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_CENTER)
	main_container.size = Vector2(400, 200)
	main_container.position = Vector2(-200, -100)
	add_child(main_container)
	
	# Create content container
	var content_container: VBoxContainer = VBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_container.alignment = BoxContainer.ALIGNMENT_CENTER
	content_container.add_theme_constant_override("separation", 20)
	main_container.add_child(content_container)
	
	# Create title label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = _get_loading_title()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	content_container.add_child(title_label)
	
	# Create progress container
	progress_container = Control.new()
	progress_container.name = "ProgressContainer"
	progress_container.custom_minimum_size = Vector2(300, 60)
	content_container.add_child(progress_container)
	
	# Create status label
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Initializing..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.visible = show_status_text
	content_container.add_child(status_label)
	
	# Create percentage label
	percentage_label = Label.new()
	percentage_label.name = "PercentageLabel"
	percentage_label.text = "0%"
	percentage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percentage_label.visible = show_percentage
	content_container.add_child(percentage_label)
	
	# Create cancel button
	if show_cancel_button:
		cancel_button = MenuButton.new()
		cancel_button.button_text = "Cancel"
		cancel_button.button_category = MenuButton.ButtonCategory.SECONDARY
		cancel_button.pressed.connect(_on_cancel_pressed)
		content_container.add_child(cancel_button)

func _create_progress_indicators() -> void:
	"""Create progress indicators based on selected style."""
	# Clear existing progress indicators
	for child in progress_container.get_children():
		child.queue_free()
	
	match progress_style:
		ProgressStyle.BAR:
			_create_progress_bar()
		ProgressStyle.CIRCULAR:
			_create_circular_progress()
		ProgressStyle.DOTS:
			_create_dots_progress()
		ProgressStyle.MILITARY_SCAN:
			_create_military_scan()
		ProgressStyle.SPINNER:
			_create_spinner_progress()

func _create_progress_bar() -> void:
	"""Create traditional progress bar."""
	progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = false  # We handle percentage separately
	progress_container.add_child(progress_bar)

func _create_circular_progress() -> void:
	"""Create circular progress indicator."""
	progress_circle = Control.new()
	progress_circle.name = "CircularProgress"
	progress_circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress_circle.draw.connect(_draw_circular_progress)
	progress_container.add_child(progress_circle)

func _create_dots_progress() -> void:
	"""Create animated dots progress indicator."""
	var dots_container: HBoxContainer = HBoxContainer.new()
	dots_container.name = "DotsContainer"
	dots_container.set_anchors_preset(Control.PRESET_CENTER)
	dots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_container.add_theme_constant_override("separation", 10)
	progress_container.add_child(dots_container)
	
	# Create animated dots
	for i in range(5):
		var dot: ColorRect = ColorRect.new()
		dot.name = "Dot%d" % i
		dot.size = Vector2(12, 12)
		dot.color = Color.WHITE
		dots_container.add_child(dot)

func _create_military_scan() -> void:
	"""Create military-style scanning effect."""
	# Create scanning background
	var scan_bg: ColorRect = ColorRect.new()
	scan_bg.name = "ScanBackground"
	scan_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scan_bg.color = Color.BLACK
	progress_container.add_child(scan_bg)
	
	# Create scanning line
	scanning_line = ColorRect.new()
	scanning_line.name = "ScanningLine"
	scanning_line.size = Vector2(4, progress_container.custom_minimum_size.y)
	scanning_line.color = Color.GREEN
	scan_bg.add_child(scanning_line)

func _create_spinner_progress() -> void:
	"""Create rotating spinner progress indicator."""
	var spinner: Control = Control.new()
	spinner.name = "Spinner"
	spinner.set_anchors_preset(Control.PRESET_CENTER)
	spinner.size = Vector2(40, 40)
	spinner.draw.connect(_draw_spinner)
	progress_container.add_child(spinner)

func _setup_loading_styling() -> void:
	"""Apply WCS styling to loading screen components."""
	if not ui_theme_manager:
		return
	
	# Style background with type-specific colors
	var bg_color: Color = Color.BLACK
	match loading_type:
		LoadingType.SCENE_TRANSITION:
			bg_color = ui_theme_manager.get_wcs_color("blue_primary")
		LoadingType.MISSION_LOADING:
			bg_color = ui_theme_manager.get_wcs_color("green_success")
		LoadingType.NETWORK_OPERATION:
			bg_color = ui_theme_manager.get_wcs_color("orange_highlight")
		_:
			bg_color = Color.BLACK
	
	bg_color.a = background_opacity
	background_overlay.color = bg_color
	
	# Style title label
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", ui_theme_manager.get_responsive_font_size(18))
	
	# Style status and percentage labels
	status_label.add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("gray_light"))
	percentage_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Apply theme to progress bar
	if progress_bar:
		ui_theme_manager.apply_theme_to_control(progress_bar)

func _setup_animations() -> void:
	"""Setup animations for loading screen elements."""
	if not enable_progress_animations:
		return
	
	# Create animation player
	progress_animation = AnimationPlayer.new()
	progress_animation.name = "ProgressAnimation"
	add_child(progress_animation)
	
	# Create animations based on progress style
	_create_progress_animations()

func _create_progress_animations() -> void:
	"""Create animations for different progress styles."""
	if not progress_animation:
		return
	
	var animation_library: AnimationLibrary = AnimationLibrary.new()
	
	match progress_style:
		ProgressStyle.DOTS:
			_create_dots_animation(animation_library)
		ProgressStyle.MILITARY_SCAN:
			_create_scan_animation(animation_library)
		ProgressStyle.SPINNER:
			_create_spinner_animation(animation_library)
	
	progress_animation.add_animation_library("loading", animation_library)

func _create_dots_animation(library: AnimationLibrary) -> void:
	"""Create dots pulsing animation."""
	var animation: Animation = Animation.new()
	animation.length = 1.5
	animation.loop_mode = Animation.LOOP_LINEAR
	
	# Animate each dot with a delay
	var dots_container: Node = progress_container.get_node_or_null("DotsContainer")
	if dots_container:
		for i in range(dots_container.get_child_count()):
			var dot: Node = dots_container.get_child(i)
			var track_index: int = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track_index, NodePath(str(dots_container.get_path_to(dot)) + ":modulate:a"))
			
			var delay: float = i * 0.2
			animation.track_insert_key(track_index, delay, 0.3)
			animation.track_insert_key(track_index, delay + 0.3, 1.0)
			animation.track_insert_key(track_index, delay + 0.6, 0.3)
	
	library.add_animation("dots_pulse", animation)

func _create_scan_animation(library: AnimationLibrary) -> void:
	"""Create scanning line animation."""
	var animation: Animation = Animation.new()
	animation.length = 2.0
	animation.loop_mode = Animation.LOOP_LINEAR
	
	if scanning_line:
		var track_index: int = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_index, NodePath(str(get_path_to(scanning_line)) + ":position:x"))
		
		animation.track_insert_key(track_index, 0.0, -4.0)
		animation.track_insert_key(track_index, 1.0, progress_container.custom_minimum_size.x)
		animation.track_insert_key(track_index, 2.0, -4.0)
	
	library.add_animation("scan_sweep", animation)

func _create_spinner_animation(library: AnimationLibrary) -> void:
	"""Create spinner rotation animation."""
	var animation: Animation = Animation.new()
	animation.length = 1.0
	animation.loop_mode = Animation.LOOP_LINEAR
	
	var spinner: Node = progress_container.get_node_or_null("Spinner")
	if spinner:
		var track_index: int = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_index, NodePath(str(get_path_to(spinner)) + ":rotation"))
		
		animation.track_insert_key(track_index, 0.0, 0.0)
		animation.track_insert_key(track_index, 1.0, TAU)
	
	library.add_animation("spinner_rotate", animation)

# ============================================================================
# DRAWING METHODS
# ============================================================================

func _draw_circular_progress() -> void:
	"""Draw circular progress indicator."""
	if not progress_circle:
		return
	
	var center: Vector2 = progress_circle.size / 2
	var radius: float = min(center.x, center.y) - 10
	var start_angle: float = -PI / 2  # Start from top
	var end_angle: float = start_angle + (current_progress / 100.0) * TAU
	
	# Draw background circle
	progress_circle.draw_arc(center, radius, 0, TAU, 32, Color.GRAY, 4.0)
	
	# Draw progress arc
	if current_progress > 0:
		var progress_color: Color = Color.GREEN
		if ui_theme_manager:
			progress_color = ui_theme_manager.get_wcs_color("green_success")
		progress_circle.draw_arc(center, radius, start_angle, end_angle, 32, progress_color, 6.0)

func _draw_spinner() -> void:
	"""Draw rotating spinner."""
	var spinner: Control = progress_container.get_node_or_null("Spinner")
	if not spinner:
		return
	
	var center: Vector2 = spinner.size / 2
	var radius: float = center.x - 5
	
	# Draw spinner segments
	for i in range(8):
		var angle: float = (i * TAU / 8) + spinner.rotation
		var start_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius * 0.6)
		var end_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		var alpha: float = (i + 1) / 8.0
		
		spinner.draw_line(start_pos, end_pos, Color(1, 1, 1, alpha), 3.0)

# ============================================================================
# PROGRESS MANAGEMENT
# ============================================================================

func start_loading(title: String = "", initial_status: String = "Loading...") -> void:
	"""Start the loading screen with specified parameters."""
	if not title.is_empty():
		title_label.text = title
	else:
		title_label.text = _get_loading_title()
	
	current_status = initial_status
	current_progress = 0.0
	loading_start_time = Time.get_time_dict_from_system()["unix"]
	is_loading_active = true
	
	# Update UI
	_update_progress_display()
	
	# Show loading screen
	_show_loading_screen()
	
	# Start animations
	if progress_animation and enable_progress_animations:
		match progress_style:
			ProgressStyle.DOTS:
				progress_animation.play("loading/dots_pulse")
			ProgressStyle.MILITARY_SCAN:
				progress_animation.play("loading/scan_sweep")
			ProgressStyle.SPINNER:
				progress_animation.play("loading/spinner_rotate")

func update_progress(progress: float, status: String = "") -> void:
	"""Update loading progress and status."""
	if not is_loading_active:
		return
	
	current_progress = clamp(progress, 0.0, 100.0)
	
	if not status.is_empty():
		current_status = status
	
	_update_progress_display()
	progress_updated.emit(current_progress, current_status)
	
	# Check for completion
	if current_progress >= 100.0:
		_handle_loading_completion()

func complete_loading(final_status: String = "Complete") -> void:
	"""Complete the loading process."""
	current_progress = 100.0
	current_status = final_status
	_update_progress_display()
	_handle_loading_completion()

func cancel_loading() -> void:
	"""Cancel the loading process."""
	is_loading_active = false
	loading_cancelled.emit()
	_hide_loading_screen()

func _update_progress_display() -> void:
	"""Update progress display elements."""
	# Update progress bar
	if progress_bar:
		progress_bar.value = current_progress
	
	# Update circular progress (triggers redraw)
	if progress_circle:
		progress_circle.queue_redraw()
	
	# Update status text
	if status_label and show_status_text:
		status_label.text = current_status
	
	# Update percentage
	if percentage_label and show_percentage:
		percentage_label.text = "%d%%" % int(current_progress)

func _handle_loading_completion() -> void:
	"""Handle loading completion with minimum display time."""
	var elapsed_time: float = Time.get_time_dict_from_system()["unix"] - loading_start_time
	var remaining_time: float = max(0.0, minimum_display_time - elapsed_time)
	
	if remaining_time > 0.0:
		get_tree().create_timer(remaining_time).timeout.connect(_complete_loading_process)
	else:
		_complete_loading_process()

func _complete_loading_process() -> void:
	"""Complete the loading process and hide screen."""
	is_loading_active = false
	loading_completed.emit()
	
	if auto_hide_on_complete:
		_hide_loading_screen()

func _get_loading_title() -> String:
	"""Get appropriate loading title based on type."""
	match loading_type:
		LoadingType.SCENE_TRANSITION: return "Loading Scene..."
		LoadingType.ASSET_LOADING: return "Loading Assets..."
		LoadingType.DATA_PROCESSING: return "Processing Data..."
		LoadingType.NETWORK_OPERATION: return "Connecting..."
		LoadingType.MISSION_LOADING: return "Loading Mission..."
		_: return "Loading..."

# ============================================================================
# SHOW/HIDE ANIMATIONS
# ============================================================================

func _show_loading_screen() -> void:
	"""Show loading screen with fade animation."""
	visible = true
	
	var show_tween: Tween = create_tween()
	show_tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _hide_loading_screen() -> void:
	"""Hide loading screen with fade animation."""
	var hide_tween: Tween = create_tween()
	hide_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	hide_tween.tween_callback(_on_hide_complete)

func _on_hide_complete() -> void:
	"""Called when hide animation completes."""
	visible = false
	
	# Stop animations
	if progress_animation:
		progress_animation.stop()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_cancel_pressed() -> void:
	"""Handle cancel button press."""
	cancel_loading()

func _on_theme_changed(theme_name: String) -> void:
	"""Handle theme changes."""
	_setup_loading_styling()

# ============================================================================
# PUBLIC API
# ============================================================================

func set_loading_type(type: LoadingType) -> void:
	"""Set loading type and update styling."""
	loading_type = type
	_setup_loading_styling()

func set_progress_style(style: ProgressStyle) -> void:
	"""Set progress style and recreate indicators."""
	progress_style = style
	_create_progress_indicators()
	_setup_animations()

func is_loading() -> bool:
	"""Check if loading is currently active."""
	return is_loading_active

func get_current_progress() -> float:
	"""Get current progress percentage."""
	return current_progress

func get_current_status() -> String:
	"""Get current status text."""
	return current_status

# ============================================================================
# STATIC CONVENIENCE METHODS
# ============================================================================

static func show_scene_loading(parent: Node, scene_name: String = "") -> LoadingScreen:
	"""Show scene loading screen."""
	var loading: LoadingScreen = LoadingScreen.new()
	loading.loading_type = LoadingType.SCENE_TRANSITION
	loading.progress_style = ProgressStyle.BAR
	parent.add_child(loading)
	
	var title: String = "Loading Scene..." if scene_name.is_empty() else "Loading %s..." % scene_name
	loading.start_loading(title)
	return loading

static func show_asset_loading(parent: Node) -> LoadingScreen:
	"""Show asset loading screen."""
	var loading: LoadingScreen = LoadingScreen.new()
	loading.loading_type = LoadingType.ASSET_LOADING
	loading.progress_style = ProgressStyle.MILITARY_SCAN
	loading.show_cancel_button = true
	parent.add_child(loading)
	loading.start_loading("Loading Assets...")
	return loading