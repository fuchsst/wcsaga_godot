@tool
extends HUDGauge
class_name HUDTargetMonitor

# Target info
@export_group("Target Info")
@export var target_name: String = "":
	set(value):
		target_name = value
		queue_redraw()
@export var target_class: String = "":
	set(value):
		target_class = value
		queue_redraw()
@export var target_team: int = 0:
	set(value):
		target_team = value
		queue_redraw()
@export var target_distance: float = 0.0:
	set(value):
		target_distance = value
		queue_redraw()

# Target status
@export_group("Target Status")
@export var hull_strength: float = 1.0:
	set(value):
		hull_strength = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var shield_strength: Array[float] = [1.0, 1.0, 1.0, 1.0]:
	set(value):
		shield_strength = value
		queue_redraw()
@export var is_disabled: bool = false:
	set(value):
		is_disabled = value
		queue_redraw()

# Subsystem targeting
@export_group("Subsystems")
@export var current_subsystem: String = "":
	set(value):
		current_subsystem = value
		queue_redraw()
@export var subsystem_strength: float = 1.0:
	set(value):
		subsystem_strength = clampf(value, 0.0, 1.0)
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var monitor_size := Vector2(200, 150)
@export var shield_display_size := Vector2(60, 60)
@export var hull_bar_width := 100
@export var hull_bar_height := 10

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(250, 200)

func _init() -> void:
	super._init()
	gauge_id = HUDGauge.TARGET_MONITOR

func _ready() -> void:
	super._ready()

# Update monitor from target ship
func update_from_target(target_ship: ShipBase) -> void:
	# TODO: Update monitor info from target ship
	# This would update:
	# - Name, class, team
	# - Hull/shield status
	# - Subsystem info
	# - Distance
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
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var x = 10
	var y = line_height
	
	# Draw target name and class
	if target_name != "":
		draw_string(font, Vector2(x, y), target_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_height
		
	if target_class != "":
		draw_string(font, Vector2(x, y), target_class,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_height
	
	# Draw distance
	if target_distance > 0:
		var dist_text = "%.1fm" % target_distance
		draw_string(font, Vector2(x, y), dist_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_height
	
	# Draw hull strength bar
	y += 5
	var hull_bg_rect = Rect2(x, y, hull_bar_width, hull_bar_height)
	draw_rect(hull_bg_rect, Color(color, 0.2))
	
	var hull_fill_rect = Rect2(x, y, hull_bar_width * hull_strength, hull_bar_height)
	var hull_color = _get_hull_color(hull_strength)
	draw_rect(hull_fill_rect, hull_color)
	
	draw_string(font, Vector2(x + hull_bar_width + 5, y + hull_bar_height), "HULL",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	y += hull_bar_height + line_height
	
	# Draw shield display
	y += 5
	var shield_center = Vector2(x + shield_display_size.x/2, 
		y + shield_display_size.y/2)
	_draw_shield_display(shield_center, color)
	y += shield_display_size.y + 5
	
	# Draw subsystem info
	if current_subsystem != "":
		draw_string(font, Vector2(x, y), current_subsystem,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_height
		
		# Draw subsystem strength bar
		var sys_bg_rect = Rect2(x, y, hull_bar_width, hull_bar_height)
		draw_rect(sys_bg_rect, Color(color, 0.2))
		
		var sys_fill_rect = Rect2(x, y, hull_bar_width * subsystem_strength, hull_bar_height)
		draw_rect(sys_fill_rect, color)
		y += hull_bar_height + 5
	
	# Draw disabled status if applicable
	if is_disabled:
		draw_string(font, Vector2(x, y), "DISABLED",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.RED)

# Draw shield strength display
func _draw_shield_display(center: Vector2, color: Color) -> void:
	var radius = shield_display_size.x / 2
	
	# Draw shield quadrants
	for i in range(shield_strength.size()):
		var start_angle = i * PI/2 - PI/4
		var end_angle = start_angle + PI/2 - 0.1
		
		# Draw quadrant background
		_draw_shield_arc(center, radius - 5, radius, 
			start_angle, end_angle, Color(color, 0.2))
		
		# Draw shield strength
		if shield_strength[i] > 0:
			var strength_radius = radius - 5 + (5 * shield_strength[i])
			_draw_shield_arc(center, radius - 5, strength_radius,
				start_angle, end_angle, color)

# Helper to draw shield arc (similar to radar gauge)
func _draw_shield_arc(center: Vector2, inner_radius: float, outer_radius: float, 
	start_angle: float, end_angle: float, color: Color, num_points: int = 16) -> void:
	
	var points = PackedVector2Array()
	var angle_step = (end_angle - start_angle) / (num_points - 1)
	
	# Generate outer arc points
	for i in range(num_points):
		var angle = start_angle + i * angle_step
		points.push_back(center + Vector2(
			cos(angle) * outer_radius,
			sin(angle) * outer_radius
		))
	
	# Generate inner arc points (in reverse)
	for i in range(num_points - 1, -1, -1):
		var angle = start_angle + i * angle_step
		points.push_back(center + Vector2(
			cos(angle) * inner_radius,
			sin(angle) * inner_radius
		))
	
	# Draw filled polygon
	draw_colored_polygon(points, color)

# Get hull strength indicator color
func _get_hull_color(strength: float) -> Color:
	if strength <= 0.2:
		return Color.RED
	elif strength <= 0.5:
		return Color.YELLOW
	else:
		return get_current_color()
