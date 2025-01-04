@tool
extends HUDGauge
class_name HUDTalkingHeadGauge

# Animation settings
@export_group("Animation Settings")
@export var animation_frames: SpriteFrames:
	set(value):
		animation_frames = value
		queue_redraw()
@export var current_animation := "default":
	set(value):
		current_animation = value
		_frame_time = 0.0
		_current_frame = 0
		queue_redraw()
@export var play_rate := 1.0

# Message settings
@export_group("Message Settings")
@export var source_name: String:
	set(value):
		source_name = value
		queue_redraw()
@export var message_duration := 5.0
@export var fade_time := 0.5

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(200, 150)
@export var border_width := 2.0
@export var border_flash_rate := 0.2
@export var source_label_offset := Vector2(5, -20)

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(250, 200)

# Animation state
var _frame_time := 0.0
var _current_frame := 0
var _time_left := 0.0
var _flash_time := 0.0
var _flash_state := false
var _is_playing := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.TALKING_HEAD

func _ready() -> void:
	super._ready()

# Start playing animation with message
func play_message(anim_name: String, source: String = "", duration: float = -1.0) -> void:
	current_animation = anim_name
	source_name = source
	_is_playing = true
	_frame_time = 0.0
	_current_frame = 0
	
	if duration > 0:
		_time_left = duration
	else:
		_time_left = message_duration
	
	queue_redraw()

# Stop current animation
func stop_message() -> void:
	_is_playing = false
	_time_left = 0.0
	source_name = ""
	queue_redraw()

# Check if animation is currently playing
func is_playing() -> bool:
	return _is_playing && _time_left > 0.0

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample animation for preview
		if !animation_frames:
			return
		if source_name.is_empty():
			source_name = "Wing Commander"
		_is_playing = true
		_time_left = message_duration
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	if !_is_playing || !animation_frames:
		return
		
	# Calculate fade alpha
	var alpha = 1.0
	if _time_left < fade_time:
		alpha = _time_left / fade_time
	
	# Get display color
	var color = get_current_color()
	color.a = alpha
	
	# Draw border
	var border_color = color
	if _flash_state:
		border_color = Color.WHITE
		border_color.a = alpha
	
	var border_rect = Rect2(Vector2.ZERO, gauge_size)
	if Engine.is_editor_hint():
		border_rect.size = preview_size
	
	draw_rect(border_rect, border_color, false, border_width)
	
	# Draw current animation frame
	if animation_frames.has_animation(current_animation):
		var frame_texture = animation_frames.get_frame_texture(current_animation, _current_frame)
		if frame_texture:
			var frame_rect = border_rect
			frame_rect = frame_rect.grow(-border_width)
			draw_texture_rect(frame_texture, frame_rect, false, Color(1, 1, 1, alpha))
	
	# Draw source name if present
	if !source_name.is_empty():
		var font = ThemeDB.fallback_font
		var font_size = ThemeDB.fallback_font_size
		
		draw_string(font,
			Vector2(source_label_offset.x, source_label_offset.y + font_size),
			source_name + ":",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update message time
	if _time_left > 0:
		_time_left -= delta
		if _time_left <= 0:
			stop_message()
		needs_redraw = true
	
	# Update animation frame
	if _is_playing && animation_frames && animation_frames.has_animation(current_animation):
		_frame_time += delta * play_rate
		var frame_duration = 1.0 / animation_frames.get_animation_speed(current_animation)
		
		if _frame_time >= frame_duration:
			_frame_time -= frame_duration
			_current_frame = (_current_frame + 1) % animation_frames.get_frame_count(current_animation)
			needs_redraw = true
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= border_flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		if _is_playing:
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
