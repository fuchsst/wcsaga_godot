@tool
extends HUDGauge
class_name HUDTextFlashGauge

# Flash settings
@export_group("Flash Settings")
@export var flash_text: String:
	set(value):
		flash_text = value
		if value:
			_flash_time_left = flash_duration
		queue_redraw()
@export var auto_center := true:
	set(value):
		auto_center = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(400, 50)
@export var flash_rate := 0.1
@export var fade_time := 0.5
@export var background_padding := Vector2(10, 5)
@export var background_alpha := 0.3

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(450, 80)

# Flash state
var _flash_time_left := 0.0
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.TEXT_FLASH
	if flash_duration == 0:
		flash_duration = 3.0

func _ready() -> void:
	super._ready()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check for pending text flash messages.
	# This might come from various sources:
	# - Missile lock warnings (TargetingComponent?)
	# - EMP effect (PlayerShip?)
	# - Collision warnings (Physics?)
	# - Specific mission events (MissionManager?)

	# Placeholder Logic: Assume a global manager or GameState holds the current flash text.
	var current_flash_text = "" # Placeholder: GameState.get_current_text_flash()
	var current_flash_duration = -1.0 # Placeholder: GameState.get_current_text_flash_duration()

	if not current_flash_text.is_empty():
		# Only show if it's a *new* message or the gauge is currently inactive
		if not is_text_flashing() or flash_text != current_flash_text:
			show_text(current_flash_text, current_flash_duration)
	# else:
		# If no text flash is active in game state, the gauge will fade out on its own.
		# No need to explicitly clear here unless we want immediate removal.
		# if is_flashing():
		#     clear_text() # Optional: Force clear if game state says no flash


# Show flash text
func show_text(text: String, duration: float = -1.0) -> void:
	flash_text = text
	if duration > 0:
		_flash_time_left = duration
	else:
		_flash_time_left = flash_duration
	queue_redraw()

# Clear flash text
func clear_text() -> void:
	flash_text = ""
	_flash_time_left = 0.0
	queue_redraw()

# Check if text is currently flashing
func is_text_flashing() -> bool:
	return _flash_time_left > 0.0 && !flash_text.is_empty()

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample text for preview
		if flash_text.is_empty():
			flash_text = "Warning: Missile Lock Detected!"
			_flash_time_left = flash_duration
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	if flash_text.is_empty() || _flash_time_left <= 0:
		return
		
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	
	# Calculate text position
	var text_size = font.get_string_size(flash_text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size)
	
	var x := 0.0
	var y: float = font_size + background_padding.y
	
	if auto_center:
		x = (gauge_size.x - text_size.x) / 2
		if Engine.is_editor_hint():
			x = (preview_size.x - text_size.x) / 2
	
	# Calculate fade alpha
	var alpha = 1.0
	if _flash_time_left < fade_time:
		alpha = _flash_time_left / fade_time
	
	# Get display color
	var color = get_current_color()
	if _flash_state:
		color = Color.WHITE
	color.a = alpha
	
	# Draw background
	var bg_rect = Rect2(
		Vector2(x - background_padding.x, 0),
		Vector2(text_size.x + background_padding.x * 2,
			text_size.y + background_padding.y * 2)
	)
	draw_rect(bg_rect, Color(0, 0, 0, background_alpha * alpha))
	
	# Draw text
	draw_string(font, Vector2(x, y), flash_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update flash time
	if _flash_time_left > 0:
		_flash_time_left -= delta
		if _flash_time_left <= 0:
			flash_text = ""
		needs_redraw = true
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		if is_text_flashing():
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
