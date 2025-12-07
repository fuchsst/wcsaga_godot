extends Line2D

# ElbowConnector.gd
# Draws an elbow (L-shaped) connector between a YearMarker and a TimelineNode
# Uses multiple glow lines for smooth fade perpendicular to the line

var year_marker: Control = null
var timeline_node: Control = null
var _is_highlighted: bool = false

# Glow layers - innermost to outermost (4 layers for smoother fade)
var _glow_layer1: Line2D = null
var _glow_layer2: Line2D = null
var _glow_layer3: Line2D = null
var _glow_layer4: Line2D = null

const DEFAULT_WIDTH: float = 2.0
const HIGHLIGHT_WIDTH: float = 3.0

const DEFAULT_COLOR: Color = Color(0.3, 0.5, 0.9, 0.8)
const HIGHLIGHT_COLOR: Color = Color(0.5, 0.8, 1.0, 1.0)

# Tighter glow layer settings (width multiplier, default alpha, highlight alpha)
const GLOW1_WIDTH: float = 1.8
const GLOW2_WIDTH: float = 2.8
const GLOW3_WIDTH: float = 4.0
const GLOW4_WIDTH: float = 5.5

const GLOW_COLOR_BASE: Color = Color(0.3, 0.6, 1.0)
const GLOW1_ALPHA: float = 0.35
const GLOW2_ALPHA: float = 0.22
const GLOW3_ALPHA: float = 0.12
const GLOW4_ALPHA: float = 0.05
const GLOW1_ALPHA_HIGHLIGHT: float = 0.6
const GLOW2_ALPHA_HIGHLIGHT: float = 0.4
const GLOW3_ALPHA_HIGHLIGHT: float = 0.22
const GLOW4_ALPHA_HIGHLIGHT: float = 0.1


func _ready() -> void:
	# Main line settings
	width = DEFAULT_WIDTH
	default_color = DEFAULT_COLOR
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	antialiased = true

	# Create four glow layers for smoother perpendicular fade (tighter around core)
	_glow_layer4 = _create_glow_line(GLOW4_WIDTH, GLOW4_ALPHA, -4)
	_glow_layer3 = _create_glow_line(GLOW3_WIDTH, GLOW3_ALPHA, -3)
	_glow_layer2 = _create_glow_line(GLOW2_WIDTH, GLOW2_ALPHA, -2)
	_glow_layer1 = _create_glow_line(GLOW1_WIDTH, GLOW1_ALPHA, -1)


func _create_glow_line(line_width: float, alpha: float, z: int) -> Line2D:
	var glow = Line2D.new()
	glow.width = DEFAULT_WIDTH * line_width
	glow.default_color = Color(GLOW_COLOR_BASE.r, GLOW_COLOR_BASE.g, GLOW_COLOR_BASE.b, alpha)
	glow.joint_mode = Line2D.LINE_JOINT_ROUND
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.antialiased = true
	glow.z_index = z
	add_child(glow)
	return glow


func setup(p_year_marker: Control, p_timeline_node: Control) -> void:
	year_marker = p_year_marker
	timeline_node = p_timeline_node
	update_connection()


func _process(_delta: float) -> void:
	if year_marker and timeline_node:
		update_connection()


func update_connection() -> void:
	if not year_marker or not timeline_node:
		visible = false
		return

	if not is_instance_valid(year_marker) or not is_instance_valid(timeline_node):
		visible = false
		return

	if not year_marker.is_inside_tree() or not timeline_node.is_inside_tree():
		visible = false
		return

	var is_right = true
	if timeline_node.has_method("is_right_aligned"):
		is_right = timeline_node.is_right_aligned()

	var year_bottom: Vector2
	if year_marker.has_method("get_bottom_edge"):
		year_bottom = year_marker.get_bottom_edge()
	else:
		year_bottom = year_marker.global_position + Vector2(year_marker.size.x / 2.0, year_marker.size.y)

	var card_top: Vector2
	if timeline_node.has_method("get_card_edge_global_position"):
		card_top = timeline_node.get_card_edge_global_position()
	else:
		card_top = timeline_node.global_position + Vector2(timeline_node.size.x / 2.0, 0)

	_draw_vertical_elbow(year_bottom, card_top, is_right)
	visible = true


func _draw_vertical_elbow(start: Vector2, end: Vector2, _is_right: bool) -> void:
	var horizontal_dist = abs(end.x - start.x)
	var vertical_dist = end.y - start.y

	var line_points: PackedVector2Array

	if horizontal_dist < 10.0 and abs(vertical_dist) < 10.0:
		line_points = PackedVector2Array([start, end])
	elif horizontal_dist > 10.0:
		var mid_y = start.y + vertical_dist * 0.4
		line_points = PackedVector2Array([
			start,
			Vector2(start.x, mid_y),
			Vector2(end.x, mid_y),
			end
		])
	else:
		line_points = PackedVector2Array([start, end])

	# Set points on main line and all glow layers
	points = line_points
	if _glow_layer1:
		_glow_layer1.points = line_points
	if _glow_layer2:
		_glow_layer2.points = line_points
	if _glow_layer3:
		_glow_layer3.points = line_points
	if _glow_layer4:
		_glow_layer4.points = line_points


func set_highlighted(highlighted: bool) -> void:
	if _is_highlighted == highlighted:
		return
	_is_highlighted = highlighted

	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	if highlighted:
		# Main line
		tween.tween_property(self, "width", HIGHLIGHT_WIDTH, 0.25)
		tween.tween_property(self, "default_color", HIGHLIGHT_COLOR, 0.25)
		# Glow layers - brighter and wider
		if _glow_layer1:
			tween.tween_property(_glow_layer1, "width", HIGHLIGHT_WIDTH * GLOW1_WIDTH * 1.2, 0.2)
			tween.tween_property(_glow_layer1, "default_color",
				Color(GLOW_COLOR_BASE.r, GLOW_COLOR_BASE.g, GLOW_COLOR_BASE.b, GLOW1_ALPHA_HIGHLIGHT), 0.2)
		if _glow_layer2:
			tween.tween_property(_glow_layer2, "width", HIGHLIGHT_WIDTH * GLOW2_WIDTH * 1.2, 0.22)
			tween.tween_property(_glow_layer2, "default_color",
				Color(GLOW_COLOR_BASE.r, GLOW_COLOR_BASE.g, GLOW_COLOR_BASE.b, GLOW2_ALPHA_HIGHLIGHT), 0.22)
		if _glow_layer3:
			tween.tween_property(_glow_layer3, "width", HIGHLIGHT_WIDTH * GLOW3_WIDTH * 1.2, 0.25)
			tween.tween_property(_glow_layer3, "default_color",
				Color(GLOW_COLOR_BASE.r, GLOW_COLOR_BASE.g, GLOW_COLOR_BASE.b, GLOW3_ALPHA_HIGHLIGHT), 0.25)
		if _glow_layer4:
			tween.tween_property(_glow_layer4, "width", HIGHLIGHT_WIDTH * GLOW4_WIDTH * 1.2, 0.28)
			tween.tween_property(_glow_layer4, "default_color",
				Color(GLOW_COLOR_BASE.r, GLOW_COLOR_BASE.g, GLOW_COLOR_BASE.b, GLOW4_ALPHA_HIGHLIGHT), 0.28)
	else:
		# Main line
		tween.tween_property(self, "width", DEFAULT_WIDTH, 0.35)
		tween.tween_property(self, "default_color", DEFAULT_COLOR, 0.35)
		# Glow layers
		if _glow_layer1:
			tween.tween_property(_glow_layer1, "width", DEFAULT_WIDTH * GLOW1_WIDTH, 0.3)
			tween.tween_property(_glow_layer1, "default_color",
				Color(GLOW_COLOR_BASE.r, GLOW_COLOR_BASE.g, GLOW_COLOR_BASE.b, GLOW1_ALPHA), 0.3)
		if _glow_layer2:
			tween.tween_property(_glow_layer2, "width", DEFAULT_WIDTH * GLOW2_WIDTH, 0.32)
			tween.tween_property(_glow_layer2, "default_color",
				Color(GLOW_COLOR_BASE.r, GLOW_COLOR_BASE.g, GLOW_COLOR_BASE.b, GLOW2_ALPHA), 0.32)
		if _glow_layer3:
			tween.tween_property(_glow_layer3, "width", DEFAULT_WIDTH * GLOW3_WIDTH, 0.35)
			tween.tween_property(_glow_layer3, "default_color",
				Color(GLOW_COLOR_BASE.r, GLOW_COLOR_BASE.g, GLOW_COLOR_BASE.b, GLOW3_ALPHA), 0.35)
		if _glow_layer4:
			tween.tween_property(_glow_layer4, "width", DEFAULT_WIDTH * GLOW4_WIDTH, 0.38)
			tween.tween_property(_glow_layer4, "default_color",
				Color(GLOW_COLOR_BASE.r, GLOW_COLOR_BASE.g, GLOW_COLOR_BASE.b, GLOW4_ALPHA), 0.38)
