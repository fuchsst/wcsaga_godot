@tool
extends HUDGauge
class_name HUDAutoGauges

# Auto status settings
@export_group("Auto Status")
@export var auto_target_active := false:
	set(value):
		if auto_target_active != value:
			auto_target_active = value
			_target_flash_time = 0.0
			queue_redraw()
@export var auto_speed_active := false:
	set(value):
		if auto_speed_active != value:
			auto_speed_active = value
			_speed_flash_time = 0.0
			queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(120, 60)
@export var icon_size := 24.0
@export var icon_spacing := 10.0
@export var show_labels := true:
	set(value):
		show_labels = value
		queue_redraw()
@export var flash_rate := 0.1

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(150, 80)

# Status tracking
var _target_flash_time := 0.0
var _speed_flash_time := 0.0
var _flash_state := false
var _flash_timer := 0.0

func _init() -> void:
	super._init()
	if flash_duration == 0:
		flash_duration = 0.5
	gauge_id = GaugeType.AUTO_TARGET

# Update gauge based on current game state
func update_from_game_state() -> void:
	if GameState.player_ship: # Check if player ship exists
		set_auto_target(GameState.player_ship.auto_target_on) # Placeholder property name
		set_auto_speed(GameState.player_ship.auto_speed_on) # Placeholder property name
	else:
		# Default state if no player ship
		set_auto_target(false)
		set_auto_speed(false)

# Set auto target status
func set_auto_target(active: bool) -> void:
	auto_target_active = active

# Set auto speed status
func set_auto_speed(active: bool) -> void:
	auto_speed_active = active

# Draw auto icon
func _draw_auto_icon(pos: Vector2, color: Color, is_target: bool) -> void:
	var half_size = icon_size * 0.5
	var quarter_size = icon_size * 0.25
	
	if is_target:
		# Draw target icon (crosshair)
		var inner_size = half_size * 0.6
		
		# Outer circle
		draw_arc(pos, half_size, 0, TAU, 32, color, 2.0)
		
		# Inner lines
		draw_line(pos + Vector2(-inner_size, 0), pos + Vector2(inner_size, 0), color, 2.0)
		draw_line(pos + Vector2(0, -inner_size), pos + Vector2(0, inner_size), color, 2.0)
	else:
		# Draw speed icon (speedometer)
		var start_angle = -PI * 0.75
		var end_angle = PI * 0.25
		
		# Outer arc
		draw_arc(pos, half_size, start_angle, end_angle, 24, color, 2.0)
		
		# Speed needle
		var needle_angle = lerp(start_angle, end_angle, 0.8)  # Point to ~80% speed
		var needle_length = half_size * 0.8
		var needle_end = pos + Vector2(
			cos(needle_angle) * needle_length,
			sin(needle_angle) * needle_length
		)
		draw_line(pos, needle_end, color, 2.0)
		
		# Center dot
		draw_circle(pos, 2.0, color)

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample status for preview
		if !auto_target_active && !auto_speed_active:
			set_auto_target(true)
			set_auto_speed(true)
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	if !auto_target_active && !auto_speed_active:
		return
		
	var size = gauge_size
	if Engine.is_editor_hint():
		size = preview_size
	
	var base_color = get_current_color()
	var target_color = base_color
	var speed_color = base_color
	
	# Handle activation flash effects
	if _target_flash_time < flash_duration:
		target_color = Color.WHITE
	if _speed_flash_time < flash_duration:
		speed_color = Color.WHITE
	
	# Calculate icon positions
	var center_y = size.y * 0.5
	var total_width = 0.0
	
	if auto_target_active:
		total_width += icon_size
	if auto_speed_active:
		if auto_target_active:
			total_width += icon_spacing
		total_width += icon_size
	
	var start_x = (size.x - total_width) * 0.5
	var x = start_x
	
	# Draw auto target icon
	if auto_target_active:
		_draw_auto_icon(Vector2(x + icon_size * 0.5, center_y), target_color, true)
		
		if show_labels:
			var font = ThemeDB.fallback_font
			var font_size = ThemeDB.fallback_font_size
			
			draw_string(font, Vector2(x + icon_size * 0.5, size.y - 5),
				"TARGET",
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, target_color)
		
		x += icon_size + icon_spacing
	
	# Draw auto speed icon
	if auto_speed_active:
		_draw_auto_icon(Vector2(x + icon_size * 0.5, center_y), speed_color, false)
		
		if show_labels:
			var font = ThemeDB.fallback_font
			var font_size = ThemeDB.fallback_font_size
			
			draw_string(font, Vector2(x + icon_size * 0.5, size.y - 5),
				"SPEED",
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, speed_color)

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update activation flash timers
	if _target_flash_time < flash_duration:
		_target_flash_time += delta
		needs_redraw = true
	
	if _speed_flash_time < flash_duration:
		_speed_flash_time += delta
		needs_redraw = true
	
	# Update flash state
	_flash_timer += delta
	if _flash_timer >= flash_rate:
		_flash_timer = 0.0
		_flash_state = !_flash_state
		if auto_target_active || auto_speed_active:
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
