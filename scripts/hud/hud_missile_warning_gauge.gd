@tool
extends HUDGauge
class_name HUDMissileWarningGauge

# Warning settings
@export_group("Warning Settings")
@export var warning_active := false:
	set(value):
		warning_active = value
		queue_redraw()
@export var direction := Vector2.ZERO:
	set(value):
		direction = value.normalized()
		queue_redraw()
@export_range(0.0, 1.0) var threat_level := 1.0:
	set(value):
		threat_level = clampf(value, 0.0, 1.0)
		_update_warning_status()
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(400, 400)
@export var arrow_size := 30.0
@export var arrow_thickness := 3.0
@export var arrow_spacing := 40.0
@export var flash_rate := 0.1
@export var flash_warning := true
@export var show_distance := true:
	set(value):
		show_distance = value
		queue_redraw()
@export var warning_distance := 0.0:
	set(value):
		warning_distance = maxf(0.0, value)
		queue_redraw()

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(500, 500)

# Status tracking
enum WarningStatus {
	DISTANT,   # Far threat
	CLOSE,     # Near threat
	CRITICAL   # Immediate threat
}

var _warning_status: WarningStatus
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = HUDGauge.MISSILE_WARNING_ARROW

func _ready() -> void:
	super._ready()
	_update_warning_status()

# Show missile warning
func show_warning(dir: Vector2, distance: float, threat: float = 1.0) -> void:
	warning_active = true
	direction = dir
	warning_distance = distance
	threat_level = threat
	queue_redraw()

# Clear missile warning
func clear_warning() -> void:
	warning_active = false
	queue_redraw()

# Update warning status
func _update_warning_status() -> void:
	if threat_level <= 0.3:
		_warning_status = WarningStatus.DISTANT
	elif threat_level <= 0.7:
		_warning_status = WarningStatus.CLOSE
	else:
		_warning_status = WarningStatus.CRITICAL

# Get color based on warning status
func _get_warning_color() -> Color:
	var color = get_current_color()
	
	match _warning_status:
		WarningStatus.DISTANT:
			color = Color.YELLOW
		WarningStatus.CLOSE:
			color = Color.ORANGE
		WarningStatus.CRITICAL:
			color = Color.RED
			if flash_warning && _flash_state:
				color = Color.WHITE
	
	return color

# Draw warning arrow
func _draw_warning_arrow(pos: Vector2, dir: Vector2, size: float, color: Color) -> void:
	var angle = dir.angle()
	var points = PackedVector2Array([
		pos + dir * size,                                    # Tip
		pos + dir.rotated(PI * 0.8) * (size * 0.6),         # Left wing
		pos + dir * (size * 0.3),                           # Base
		pos + dir.rotated(-PI * 0.8) * (size * 0.6)         # Right wing
	])
	
	# Draw arrow fill
	draw_colored_polygon(points, Color(color, 0.3))
	
	# Draw arrow outline
	for i in range(points.size()):
		var next = (i + 1) % points.size()
		draw_line(points[i], points[next], color, arrow_thickness)

# Draw warning arrows
func _draw_warning_arrows(center: Vector2, color: Color) -> void:
	var base_size = arrow_size * (1.0 + threat_level * 0.5)
	
	# Draw main arrow
	_draw_warning_arrow(center, direction, base_size, color)
	
	# Draw additional arrows based on threat level
	if threat_level > 0.5:
		var side_dir = direction.rotated(PI * 0.2)
		var side_size = base_size * 0.8
		var side_offset = direction * arrow_spacing
		
		_draw_warning_arrow(center - side_offset, side_dir, side_size, color)
		_draw_warning_arrow(center - side_offset, side_dir.reflect(direction), side_size, color)
	
	if threat_level > 0.8:
		var outer_dir = direction.rotated(PI * 0.3)
		var outer_size = base_size * 0.6
		var outer_offset = direction * (arrow_spacing * 2)
		
		_draw_warning_arrow(center - outer_offset, outer_dir, outer_size, color)
		_draw_warning_arrow(center - outer_offset, outer_dir.reflect(direction), outer_size, color)

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample warning for preview
		if !warning_active:
			show_warning(Vector2(0.7, -0.7), 1000.0, 0.8)
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	if !warning_active:
		return
		
	var size = gauge_size
	if Engine.is_editor_hint():
		size = preview_size
	
	var center = size * 0.5
	var color = _get_warning_color()
	
	# Draw warning arrows
	_draw_warning_arrows(center, color)
	
	# Draw distance if enabled
	if show_distance:
		var font = ThemeDB.fallback_font
		var font_size = ThemeDB.fallback_font_size
		
		var dist_text = "%.0fm" % warning_distance
		var text_pos = center + direction * (arrow_size * 2 + font_size)
		
		draw_string(font, text_pos, dist_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		if warning_active && flash_warning && _warning_status == WarningStatus.CRITICAL:
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
