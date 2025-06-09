@tool
extends HUDGauge
class_name HUDOffscreenRangeGauge

# Range categories
enum RangeCategory {
	CLOSE,     # Close range targets
	MEDIUM,    # Medium range targets
	FAR,       # Far range targets
	EXTREME    # Extreme range targets
}

# Range settings
@export_group("Range Settings")
@export var range_active := false:
	set(value):
		range_active = value
		queue_redraw()
@export var target_distance := 0.0:
	set(value):
		target_distance = maxf(0.0, value)
		_update_range_category()
		queue_redraw()

# Range thresholds
@export_group("Range Thresholds")
@export var close_range := 500.0:
	set(value):
		close_range = maxf(0.0, value)
		_update_range_category()
@export var medium_range := 2000.0:
	set(value):
		medium_range = maxf(close_range, value)
		_update_range_category()
@export var far_range := 5000.0:
	set(value):
		far_range = maxf(medium_range, value)
		_update_range_category()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(100, 200)
@export var bar_width := 20.0
@export var show_labels := true:
	set(value):
		show_labels = value
		queue_redraw()
@export var distance_units := "m"
@export var flash_rate := 0.2
@export var flash_extreme := true

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(150, 250)

# Status tracking
var _current_category: RangeCategory
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.OFFSCREEN_RANGE

func _ready() -> void:
	super._ready()
	_update_range_category()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# This gauge depends on the main offscreen indicator being active.
	# We need a way to get the current offscreen target's distance.
	# Option 1: Get it from the HUDOffscreenIndicatorGauge instance.
	# Option 2: Recalculate it here based on GameState.player_ship.target_object_id.

	# Using Option 2 for simplicity, assuming the target check logic is similar
	# to HUDOffscreenIndicatorGauge's update_from_game_state.

	var show_range = false
	var distance = 0.0

	# Check if player ship and target exist
	if GameStateManager.player_ship and is_instance_valid(GameStateManager.player_ship) and GameStateManager.player_ship.target_object_id != -1:
		var target_node = ObjectManager.get_object_by_id(GameStateManager.player_ship.target_object_id)
		if is_instance_valid(target_node):
			var camera = get_viewport().get_camera_3d()
			if camera:
				var target_world_pos = target_node.global_position
				var screen_pos = camera.unproject_position(target_world_pos)
				var viewport_rect = get_viewport_rect()

				# Check if target is off-screen
				if not viewport_rect.has_point(screen_pos) or camera.is_position_behind(target_world_pos):
					distance = GameStateManager.player_ship.global_position.distance_to(target_world_pos)
					show_range = true

	if show_range:
		show_range(distance)
	else:
		clear_range()


# Show range indicator
func show_range(distance: float) -> void:
	range_active = true
	target_distance = distance
	queue_redraw()

# Clear range indicator
func clear_range() -> void:
	range_active = false
	queue_redraw()

# Update current range category
func _update_range_category() -> void:
	if target_distance <= close_range:
		_current_category = RangeCategory.CLOSE
	elif target_distance <= medium_range:
		_current_category = RangeCategory.MEDIUM
	elif target_distance <= far_range:
		_current_category = RangeCategory.FAR
	else:
		_current_category = RangeCategory.EXTREME

# Get color for range category
func _get_range_color() -> Color:
	var color = get_current_color()
	
	match _current_category:
		RangeCategory.CLOSE:
			color = Color.RED
		RangeCategory.MEDIUM:
			color = Color.YELLOW
		RangeCategory.FAR:
			color = Color.GREEN
		RangeCategory.EXTREME:
			color = Color.BLUE
			if flash_extreme && _flash_state:
				color = Color.WHITE
	
	return color

# Draw range bar section
func _draw_range_section(start_y: float, height: float, active: bool, color: Color) -> void:
	var x = (gauge_size.x - bar_width) * 0.5
	var rect = Rect2(x, start_y, bar_width, height)
	
	# Draw background
	draw_rect(rect, Color(color, 0.2))
	
	# Draw active section
	if active:
		draw_rect(rect, Color(color, 0.8))

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample range for preview
		if !range_active:
			show_range(1500.0)
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	if !range_active:
		return
		
	var size = gauge_size
	if Engine.is_editor_hint():
		size = preview_size
	
	var color = _get_range_color()
	var section_height = size.y / 4.0
	
	# Draw range sections from bottom to top
	var y = size.y
	
	# Close range (bottom)
	y -= section_height
	_draw_range_section(y, section_height,
		_current_category == RangeCategory.CLOSE,
		Color.RED)
	
	# Medium range
	y -= section_height
	_draw_range_section(y, section_height,
		_current_category == RangeCategory.MEDIUM,
		Color.YELLOW)
	
	# Far range
	y -= section_height
	_draw_range_section(y, section_height,
		_current_category == RangeCategory.FAR,
		Color.GREEN)
	
	# Extreme range (top)
	y -= section_height
	_draw_range_section(y, section_height,
		_current_category == RangeCategory.EXTREME,
		Color.BLUE)
	
	# Draw distance if enabled
	if show_labels:
		var font = ThemeDB.fallback_font
		var font_size = ThemeDB.fallback_font_size
		
		var dist_text = "%.0f%s" % [target_distance, distance_units]
		var x = size.x * 0.5
		var y_offset = font_size + 5
		
		draw_string(font, Vector2(x, size.y + y_offset), dist_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
		
		# Draw range labels
		var ranges = [
			["FAR+", far_range],
			["MED", medium_range],
			["CLOSE", close_range]
		]
		
		y = size.y - section_height * 0.5
		for range_info in ranges:
			var label = range_info[0]
			var value = range_info[1]
			
			draw_string(font, Vector2(x, y), label,
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(color, 0.7))
			y -= section_height

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		if range_active && _current_category == RangeCategory.EXTREME && flash_extreme:
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
