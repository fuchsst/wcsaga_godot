@tool
extends HUDGauge
class_name HUDAttackingCountGauge

# Count settings
@export_group("Count Settings")
@export var count_active := false:
	set(value):
		count_active = value
		queue_redraw()
@export var attack_count := 0:
	set(value):
		attack_count = maxi(0, value)
		_update_priority()
		queue_redraw()
@export var max_display_count := 8

# Priority thresholds
@export_group("Priority Thresholds")
@export var high_priority := 4:
	set(value):
		high_priority = maxi(1, value)
		_update_priority()
@export var critical_priority := 6:
	set(value):
		critical_priority = maxi(high_priority, value)
		_update_priority()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(120, 40)
@export var icon_size := 20.0
@export var icon_spacing := 5.0
@export var flash_rate := 0.2
@export var flash_critical := true

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(150, 60)

# Priority tracking
enum PriorityLevel {
	NORMAL,
	HIGH,
	CRITICAL
}

# Status tracking
var _current_priority: PriorityLevel
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = HUDGauge.ATTACKING_TARGET_COUNT

func _ready() -> void:
	super._ready()
	_update_priority()

# Show attack count
func show_count(count: int) -> void:
	count_active = true
	attack_count = count
	queue_redraw()

# Clear attack count
func clear_count() -> void:
	count_active = false
	queue_redraw()

# Update current priority level
func _update_priority() -> void:
	if attack_count >= critical_priority:
		_current_priority = PriorityLevel.CRITICAL
	elif attack_count >= high_priority:
		_current_priority = PriorityLevel.HIGH
	else:
		_current_priority = PriorityLevel.NORMAL

# Get color based on priority
func _get_priority_color() -> Color:
	var color = get_current_color()
	
	match _current_priority:
		PriorityLevel.HIGH:
			color = Color.YELLOW
		PriorityLevel.CRITICAL:
			color = Color.RED
			if flash_critical && _flash_state:
				color = Color.WHITE
	
	return color

# Draw attack icon
func _draw_attack_icon(pos: Vector2, color: Color) -> void:
	var half_size = icon_size * 0.5
	var points = PackedVector2Array([
		pos + Vector2(0, -half_size),           # Top
		pos + Vector2(half_size, half_size),    # Bottom right
		pos + Vector2(-half_size, half_size)    # Bottom left
	])
	draw_colored_polygon(points, color)

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample count for preview
		if !count_active:
			show_count(5)
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	if !count_active:
		return
		
	var size = gauge_size
	if Engine.is_editor_hint():
		size = preview_size
	
	var color = _get_priority_color()
	var display_count = mini(attack_count, max_display_count)
	
	# Calculate icon positions
	var total_width = (icon_size + icon_spacing) * display_count - icon_spacing
	var start_x = (size.x - total_width) * 0.5
	var y = size.y * 0.5
	
	# Draw attack icons
	for i in range(display_count):
		var x = start_x + (icon_size + icon_spacing) * i
		_draw_attack_icon(Vector2(x + icon_size * 0.5, y), color)
	
	# Draw count if enabled and exceeding max display
	if count_active && attack_count > max_display_count:
		var font = ThemeDB.fallback_font
		var font_size = ThemeDB.fallback_font_size
		
		var count_text = "+%d" % (attack_count - max_display_count)
		var text_pos = Vector2(
			start_x + total_width + icon_spacing + font_size * 0.5,
			y + font_size * 0.3
		)
		
		draw_string(font, text_pos, count_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		if count_active && _current_priority == PriorityLevel.CRITICAL && flash_critical:
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
