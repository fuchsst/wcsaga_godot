@tool
extends HUDGauge
class_name HUDReticleGauge

# Reticle styles
enum ReticleStyle {
	CLASSIC,  # Original WC style
	MODERN    # Modern style
}

# Lock states
enum LockState {
	NONE,
	SEEKING,
	LOCKED
}

# Reticle settings
@export_group("Reticle Settings")
@export var style: ReticleStyle = ReticleStyle.CLASSIC:
	set(value):
		style = value
		queue_redraw()
@export var lock_state: LockState = LockState.NONE:
	set(value):
		lock_state = value
		queue_redraw()
@export var lock_progress: float = 0.0:
	set(value):
		lock_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

# Target info
@export_group("Target Info")
@export var has_target: bool = false:
	set(value):
		has_target = value
		queue_redraw()
@export var target_in_range: bool = false:
	set(value):
		target_in_range = value
		queue_redraw()
@export var target_distance: float = 0.0:
	set(value):
		target_distance = value
		queue_redraw()
@export var lead_position := Vector2.ZERO:
	set(value):
		lead_position = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var reticle_size := 40.0
@export var lead_indicator_size := 10.0
@export var bracket_padding := 5.0
@export var lock_ring_size := 50.0

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(200, 200)

# Animation
var _rotation_angle := 0.0
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.CENTER_RETICLE

func _ready() -> void:
	super._ready()

# Update reticle from ship state
func update_from_ship(ship: ShipBase) -> void:
	# TODO: Update reticle info from ship
	# This would update:
	# - Target status
	# - Lock state
	# - Lead position
	# - Range info
	pass

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var color = get_current_color()
	var center = get_center_position()
	
	# Draw center reticle
	match style:
		ReticleStyle.CLASSIC:
			_draw_classic_reticle(center, color)
		ReticleStyle.MODERN:
			_draw_modern_reticle(center, color)
	
	# Draw lock indicator if locking/locked
	if lock_state != LockState.NONE:
		_draw_lock_indicator(center, color)
	
	# Draw lead indicator if we have a target
	if has_target && lead_position != Vector2.ZERO:
		_draw_lead_indicator(lead_position, color)
		
		# Draw target brackets
		if target_in_range:
			_draw_target_brackets(lead_position, color)
		
		# Draw range indicator
		if target_distance > 0:
			_draw_range_indicator(lead_position, target_distance, color)

# Get center position (either screen center or custom position)
func get_center_position() -> Vector2:
	if Engine.is_editor_hint():
		return preview_size / 2
	else:
		return Vector2(get_viewport_rect().size / 2)

# Draw classic style reticle
func _draw_classic_reticle(center: Vector2, color: Color) -> void:
	# Draw outer circle
	draw_arc(center, reticle_size, 0, TAU, 32, color)
	
	# Draw crosshairs
	var line_length = reticle_size * 0.7
	draw_line(center - Vector2(line_length, 0), center + Vector2(line_length, 0), color)
	draw_line(center - Vector2(0, line_length), center + Vector2(0, line_length), color)
	
	# Draw corner marks
	var corner_size = reticle_size * 0.3
	var corner_dist = reticle_size * 0.7
	for i in range(4):
		var angle = i * PI/2
		var dir = Vector2(cos(angle), sin(angle))
		var corner_pos = center + dir * corner_dist
		var perp = Vector2(-dir.y, dir.x)
		draw_line(corner_pos, corner_pos + dir * corner_size, color)
		draw_line(corner_pos, corner_pos + perp * corner_size, color)

# Draw modern style reticle
func _draw_modern_reticle(center: Vector2, color: Color) -> void:
	# Draw diamond shape
	var points = PackedVector2Array([
		center + Vector2(0, -reticle_size),
		center + Vector2(reticle_size, 0),
		center + Vector2(0, reticle_size),
		center + Vector2(-reticle_size, 0)
	])
	draw_polyline(points + [points[0]], color)
	
	# Draw center dot
	draw_circle(center, 2, color)
	
	# Draw tick marks
	var tick_size = reticle_size * 0.2
	for i in range(4):
		var angle = i * PI/2
		var dir = Vector2(cos(angle), sin(angle))
		var tick_start = center + dir * (reticle_size * 0.5)
		var tick_end = tick_start + dir * tick_size
		draw_line(tick_start, tick_end, color)

# Draw lock indicator
func _draw_lock_indicator(center: Vector2, color: Color) -> void:
	# Draw rotating elements for seeking state
	if lock_state == LockState.SEEKING:
		_rotation_angle += PI * get_process_delta_time()
		
		for i in range(4):
			var angle = _rotation_angle + i * PI/2
			var pos = center + Vector2(cos(angle), sin(angle)) * lock_ring_size
			draw_circle(pos, 3, color)
		
		# Draw progress arc
		draw_arc(center, lock_ring_size, -PI/2, -PI/2 + TAU * lock_progress, 32, color)
	
	# Draw locked indicator
	elif lock_state == LockState.LOCKED:
		# Update flash state
		_flash_time += get_process_delta_time()
		if _flash_time >= 0.5:
			_flash_time = 0.0
			_flash_state = !_flash_state
		
		if _flash_state:
			# Draw corners
			var corner_size = lock_ring_size * 0.3
			for i in range(4):
				var angle = i * PI/2
				var dir = Vector2(cos(angle), sin(angle))
				var corner_pos = center + dir * lock_ring_size
				draw_line(corner_pos, corner_pos + dir * corner_size, color)
				
			# Draw lock text
			var font = ThemeDB.fallback_font
			var font_size = ThemeDB.fallback_font_size
			draw_string(font, center + Vector2(0, lock_ring_size + font_size),
				"LOCKED", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

# Draw lead indicator
func _draw_lead_indicator(pos: Vector2, color: Color) -> void:
	var size = lead_indicator_size
	
	# Draw diamond shape
	var points = PackedVector2Array([
		pos + Vector2(0, -size),
		pos + Vector2(size, 0),
		pos + Vector2(0, size),
		pos + Vector2(-size, 0)
	])
	draw_polyline(points + [points[0]], color)

# Draw target brackets
func _draw_target_brackets(pos: Vector2, color: Color) -> void:
	var size = lead_indicator_size + bracket_padding
	var bracket_length = size * 0.5
	
	# Draw corner brackets
	for i in range(4):
		var angle = i * PI/2
		var dir = Vector2(cos(angle), sin(angle))
		var perp = Vector2(-dir.y, dir.x)
		var corner_pos = pos + (dir + perp) * size
		draw_line(corner_pos, corner_pos - dir * bracket_length, color)
		draw_line(corner_pos, corner_pos - perp * bracket_length, color)

# Draw range indicator
func _draw_range_indicator(pos: Vector2, distance: float, color: Color) -> void:
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var range_text = "%.0fm" % distance
	draw_string(font, pos + Vector2(lead_indicator_size + 5, font_size/2),
		range_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _process(delta: float) -> void:
	super._process(delta)
	
	# Update animations
	if lock_state != LockState.NONE || _flash_state:
		queue_redraw()
