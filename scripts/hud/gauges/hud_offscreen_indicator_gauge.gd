@tool
extends HUDGauge
class_name HUDOffscreenIndicatorGauge

# Target settings
@export_group("Target Settings")
@export var target_active := false:
	set(value):
		target_active = value
		queue_redraw()
@export var target_position := Vector2.ZERO:
	set(value):
		target_position = value
		queue_redraw()
@export var target_distance := 0.0:
	set(value):
		target_distance = maxf(0.0, value)
		queue_redraw()
@export var target_friendly := false:
	set(value):
		target_friendly = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(600, 400)
@export var indicator_size := 30.0
@export var edge_padding := 40.0
@export var show_distance := true:
	set(value):
		show_distance = value
		queue_redraw()
@export var distance_units := "m"
@export var flash_rate := 0.2
@export var flash_hostile := true

# Arrow settings
@export_group("Arrow Settings")
@export var arrow_width := 20.0
@export var arrow_length := 30.0
@export var arrow_head_size := 10.0

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(650, 450)

# Status tracking
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.OFFSCREEN_INDICATOR

func _ready() -> void:
	super._ready()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship and target exist
	if not GameState.player_ship or not is_instance_valid(GameState.player_ship) or GameState.player_ship.target_object_id == -1:
		clear_target()
		return

	var target_node = ObjectManager.get_object_by_id(GameState.player_ship.target_object_id)
	if not is_instance_valid(target_node):
		clear_target()
		return

	var camera = get_viewport().get_camera_3d()
	if not camera:
		clear_target()
		return

	var target_world_pos = target_node.global_position
	var screen_pos = camera.unproject_position(target_world_pos)
	var viewport_rect = get_viewport_rect()

	# Check if target is off-screen (or behind camera)
	if not viewport_rect.has_point(screen_pos) or camera.is_position_behind(target_world_pos):
		var distance = GameState.player_ship.global_position.distance_to(target_world_pos)
		var friendly = false
		if target_node.has_method("get_team"): # Check if target has team info
			friendly = IFFManager.is_friendly(GameState.player_ship.team, target_node.get_team()) # Assuming IFFManager

		# Calculate position relative to gauge center for _get_edge_point
		# Note: This assumes the gauge itself might not be centered on the screen.
		# We need the direction from the screen center towards the offscreen target.
		# A simpler way might be to use the 3D direction vector projected onto the camera plane.

		# Alternative approach: Use the 3D direction vector relative to camera forward
		var direction_to_target = (target_world_pos - camera.global_position).normalized()
		var local_direction = camera.global_transform.basis.inverse() * direction_to_target

		# Use the local X/Y direction for positioning the indicator.
		# The _get_edge_point function expects a vector pointing from center towards the target's screen projection.
		# We can simulate this using the local_direction's X/Y components.
		var gauge_relative_direction = Vector2(local_direction.x, -local_direction.y).normalized() # Invert Y for screen coords
		# Scale it arbitrarily large so _get_edge_point finds the edge intersection
		var far_point_relative_to_gauge = gauge_relative_direction * 10000.0

		show_target(far_point_relative_to_gauge, distance, friendly)

	else:
		# Target is on-screen
		clear_target()


# Show target indicator
func show_target(position: Vector2, distance: float, friendly: bool = false) -> void:
	target_active = true
	target_position = position
	target_distance = distance
	target_friendly = friendly
	queue_redraw()

# Clear target indicator
func clear_target() -> void:
	target_active = false
	queue_redraw()

# Draw arrow shape
func _draw_arrow(pos: Vector2, dir: Vector2, size: float, color: Color) -> void:
	# Calculate arrow points
	var right = dir.rotated(PI/2)
	var arrow_tip = pos + dir * size
	var arrow_base = pos - dir * (size * 0.5)
	var arrow_left = arrow_base + right * (size * 0.3)
	var arrow_right = arrow_base - right * (size * 0.3)
	
	# Draw arrow
	var points = PackedVector2Array([
		arrow_tip,
		arrow_left,
		arrow_right
	])
	draw_colored_polygon(points, color)

# Get screen edge intersection point
func _get_edge_point(center: Vector2, target: Vector2, size: Vector2, padding: float) -> Vector2:
	var dir = (target - center).normalized()
	var bounds = size * 0.5
	bounds.x -= padding
	bounds.y -= padding
	
	# Calculate intersection with screen edges
	var t_horizontal = bounds.x / abs(dir.x) if dir.x != 0 else INF
	var t_vertical = bounds.y / abs(dir.y) if dir.y != 0 else INF
	var t = minf(t_horizontal, t_vertical)
	
	return center + dir * t

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample target for preview
		if !target_active:
			show_target(Vector2(500, -300), 1500.0)
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	if !target_active:
		return
		
	# Get display color
	var color = get_current_color()
	if target_friendly:
		color = Color.GREEN
	else:
		color = Color.RED
		if flash_hostile && _flash_state:
			color = Color.WHITE
	
	# Calculate screen center and target direction
	var center = gauge_size * 0.5
	if Engine.is_editor_hint():
		center = preview_size * 0.5
	
	var screen_pos = _get_edge_point(center, target_position, gauge_size, edge_padding)
	var direction = (target_position - center).normalized()
	
	# Draw direction arrow
	_draw_arrow(screen_pos, direction, indicator_size, color)
	
	# Draw distance if enabled
	if show_distance:
		var font = ThemeDB.fallback_font
		var font_size = ThemeDB.fallback_font_size
		
		var dist_text = "%.0f%s" % [target_distance, distance_units]
		var text_offset = Vector2(0, -font_size - 5)
		
		if direction.y > 0:
			text_offset.y = font_size + 15
		
		draw_string(font, screen_pos + text_offset, dist_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		if target_active && (!target_friendly || !flash_hostile):
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
