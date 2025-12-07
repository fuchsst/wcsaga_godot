extends Line2D

# ElbowConnector.gd
# Draws an elbow (L-shaped) connector between a YearMarker and a TimelineNode
# Managed by TimelineController, updates positions dynamically

var year_marker: Control = null
var timeline_node: Control = null
var _is_highlighted: bool = false

const DEFAULT_WIDTH: float = 2.0
const HIGHLIGHT_WIDTH: float = 4.0
const DEFAULT_COLOR: Color = Color(0.4, 0.6, 1.0, 0.8)
const HIGHLIGHT_COLOR: Color = Color(0.6, 1.8, 3.0, 1.0)


func _ready() -> void:
	width = DEFAULT_WIDTH
	default_color = DEFAULT_COLOR
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	antialiased = true # Enable antialiasing for smoother lines


func setup(p_year_marker: Control, p_timeline_node: Control) -> void:
	year_marker = p_year_marker
	timeline_node = p_timeline_node
	update_connection()


func _process(_delta: float) -> void:
	# Update connector positions every frame to track scrolling
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

	# Get node alignment to determine horizontal direction
	var is_right = timeline_node.is_right_aligned() if timeline_node.has_method("is_right_aligned") else true

	# Get bottom edge of year marker
	var year_bottom: Vector2
	if year_marker.has_method("get_bottom_edge"):
		year_bottom = year_marker.get_bottom_edge()
	else:
		year_bottom = year_marker.global_position + Vector2(year_marker.size.x / 2.0, year_marker.size.y)

	# Get top edge of card
	var card_top: Vector2
	if timeline_node.has_method("get_card_edge_global_position"):
		card_top = timeline_node.get_card_edge_global_position()
	else:
		card_top = timeline_node.global_position + Vector2(timeline_node.size.x / 2.0, 0)

	# Draw the elbow connector using global coordinates
	# (parent has top_level=true, so we draw in screen space)
	_draw_vertical_elbow(year_bottom, card_top, is_right)
	visible = true


func _draw_vertical_elbow(start: Vector2, end: Vector2, _is_right: bool) -> void:
	## Draws a vertical elbow connector
	## Path: start (year bottom) -> vertical down -> horizontal -> vertical down -> end (card top)
	var horizontal_dist = abs(end.x - start.x)
	var vertical_dist = end.y - start.y

	# If very close, just draw a straight line
	if horizontal_dist < 10.0 and abs(vertical_dist) < 10.0:
		points = PackedVector2Array([start, end])
		return

	# Calculate elbow midpoint - go down a bit, then horizontal, then down to card
	var mid_y = start.y + vertical_dist * 0.4 # 40% of the way down

	if horizontal_dist > 10.0:
		# Draw: down -> horizontal -> down
		points = PackedVector2Array([
			start,
			Vector2(start.x, mid_y), # First vertical segment down
			Vector2(end.x, mid_y), # Horizontal segment
			end # Final vertical segment down to card
		])
	else:
		# Nearly aligned vertically - just draw straight down
		points = PackedVector2Array([start, end])


func set_highlighted(highlighted: bool) -> void:
	if _is_highlighted == highlighted:
		return
	_is_highlighted = highlighted

	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	if highlighted:
		tween.tween_property(self, "width", HIGHLIGHT_WIDTH, 0.25)
		tween.tween_property(self, "default_color", HIGHLIGHT_COLOR, 0.25)
	else:
		tween.tween_property(self, "width", DEFAULT_WIDTH, 0.35)
		tween.tween_property(self, "default_color", DEFAULT_COLOR, 0.35)
