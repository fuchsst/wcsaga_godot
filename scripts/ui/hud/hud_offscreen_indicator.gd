# HUDOffscreenIndicator - Arrow indicators for off-screen targets
# Shows direction arrows pointing to targets outside the viewport
# Port of hudtarget.cpp::hud_draw_offscreen_indicator()

class_name HUDOffscreenIndicator
extends Control

# === CONSTANTS ===
const ARROW_SIZE: float = 15.0
const EDGE_PADDING: float = 40.0
const MIN_DISTANCE_TO_SHOW: float = 50.0

# === CONFIGURATION ===
@export var arrow_color: Color = Color(1.0, 0.0, 0.0, 0.8) # Default red for hostile
@export var friendly_color: Color = Color(0.0, 1.0, 0.0, 0.8)
@export var neutral_color: Color = Color(1.0, 1.0, 0.0, 0.8)
@export var show_distance: bool = true

# === STATE ===
var _player: Node = null
var _target: Node = null
var _camera: Camera3D = null
var _arrow_points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	# Ensure we fill the viewport
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	_camera = get_viewport().get_camera_3d()
	if not _camera or not _player or not _target:
		visible = false
		return

	if not is_instance_valid(_target):
		visible = false
		return

	_update_indicator()


func _draw() -> void:
	if not _target or not is_instance_valid(_target):
		return

	var target_pos = _target.global_position

	# Check if target is behind camera or outside viewport
	if _camera.is_position_behind(target_pos):
		_draw_arrow_for_behind_target(target_pos)
	else:
		var screen_pos = _camera.unproject_position(target_pos)
		var viewport_rect = get_viewport_rect()

		if not viewport_rect.has_point(screen_pos):
			_draw_arrow_for_offscreen_target(screen_pos, target_pos)


func _update_indicator() -> void:
	"""Update indicator visibility"""
	if not _target or not is_instance_valid(_target):
		visible = false
		return

	var target_pos = _target.global_position
	var is_behind = _camera.is_position_behind(target_pos)
	var screen_pos = Vector2.ZERO if is_behind else _camera.unproject_position(target_pos)
	var viewport_rect = get_viewport_rect()

	visible = is_behind or not viewport_rect.has_point(screen_pos)
	if visible:
		queue_redraw()


func _draw_arrow_for_behind_target(target_pos: Vector3) -> void:
	"""Draw arrow pointing to target behind the camera"""
	var player_pos = _player.global_position
	var to_target = target_pos - player_pos

	# Project to 2D using camera orientation
	var cam_right = _camera.global_transform.basis.x
	var cam_up = _camera.global_transform.basis.y

	var x_component = to_target.dot(cam_right)
	var y_component = to_target.dot(cam_up)

	var angle = atan2(-y_component, x_component)
	var center = size / 2.0
	var arrow_pos = _get_edge_position(angle, center)

	_draw_arrow_at_position(arrow_pos, angle + PI, target_pos)


func _draw_arrow_for_offscreen_target(screen_pos: Vector2, target_pos: Vector3) -> void:
	"""Draw arrow pointing to target outside viewport"""
	var center = size / 2.0
	var direction = (screen_pos - center).normalized()
	var angle = atan2(direction.y, direction.x)

	var arrow_pos = _get_edge_position(angle, center)
	_draw_arrow_at_position(arrow_pos, angle, target_pos)


func _get_edge_position(angle: float, center: Vector2) -> Vector2:
	"""Calculate position on the edge of the screen for the given angle"""
	var half_width = size.x / 2.0 - EDGE_PADDING
	var half_height = size.y / 2.0 - EDGE_PADDING

	var cos_a = cos(angle)
	var sin_a = sin(angle)

	# Calculate intersection with screen edges
	var t_x = half_width / absf(cos_a) if absf(cos_a) > 0.001 else INF
	var t_y = half_height / absf(sin_a) if absf(sin_a) > 0.001 else INF
	var t = minf(t_x, t_y)

	return center + Vector2(cos_a * t, sin_a * t)


func _draw_arrow_at_position(pos: Vector2, angle: float, target_pos: Vector3) -> void:
	"""Draw the arrow indicator at the given position"""
	var color = _get_target_color()

	# Build arrow triangle
	var arrow_points = PackedVector2Array()
	arrow_points.append(Vector2(ARROW_SIZE, 0)) # Tip
	arrow_points.append(Vector2(-ARROW_SIZE * 0.6, -ARROW_SIZE * 0.5)) # Left
	arrow_points.append(Vector2(-ARROW_SIZE * 0.6, ARROW_SIZE * 0.5)) # Right

	# Rotate and translate
	var transform = Transform2D(angle, pos)
	for i in range(arrow_points.size()):
		arrow_points[i] = transform * arrow_points[i]

	draw_colored_polygon(arrow_points, color)

	# Draw distance text if enabled
	if show_distance and _player:
		var dist = _player.global_position.distance_to(target_pos)
		var dist_text = _format_distance(dist)
		var text_offset = Vector2(cos(angle), sin(angle)) * -25.0
		draw_string(
			ThemeDB.fallback_font,
			pos + text_offset,
			dist_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			11,
			color
		)


func _get_target_color() -> Color:
	"""Get color based on target IFF"""
	if not _target or not _player:
		return arrow_color

	var iff_manager = _get_iff_manager()
	if not iff_manager:
		return arrow_color

	var player_team = _get_property(_player, "team", 0)
	var target_team = _get_property(_target, "team", 0)

	if iff_manager.has_method("is_hostile"):
		if iff_manager.is_hostile(player_team, target_team):
			return arrow_color
		if player_team == target_team:
			return friendly_color

	return neutral_color


func _format_distance(dist: float) -> String:
	"""Format distance for display"""
	if dist >= 1000:
		return "%.1fk" % (dist / 1000.0)
	return "%dm" % int(dist)


func _get_property(obj: Node, prop: String, default = null):
	"""Safely get a property from an object"""
	if prop in obj:
		return obj.get(prop)
	return default


func _get_iff_manager() -> Node:
	"""Get IFFManager autoload"""
	if Engine.has_singleton("IFFManager"):
		return Engine.get_singleton("IFFManager")
	return null


# === PUBLIC API ===

func set_player(player: Node) -> void:
	"""Set the player ship reference"""
	_player = player


func set_target(target: Node) -> void:
	"""Set the target to track"""
	_target = target
