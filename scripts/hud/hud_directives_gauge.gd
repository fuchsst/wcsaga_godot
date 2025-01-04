@tool
extends HUDGauge
class_name HUDDirectivesGauge

# Objective types
enum ObjectiveType {
	PRIMARY,
	SECONDARY,
	BONUS
}

# Objective status
enum ObjectiveStatus {
	INCOMPLETE,
	COMPLETE,
	FAILED
}

# Objective info
class Objective:
	var text: String
	var type: ObjectiveType
	var status: ObjectiveStatus
	var notify_time: float
	var total_count: int
	var current_count: int
	
	func _init(t: String = "", ty: ObjectiveType = ObjectiveType.PRIMARY,
		s: ObjectiveStatus = ObjectiveStatus.INCOMPLETE, total: int = 1, current: int = 0) -> void:
		text = t
		type = ty
		status = s
		notify_time = 0.0
		total_count = total
		current_count = current

# Directives settings
@export_group("Directives Settings")
@export var objectives: Array[Objective]:
	set(value):
		objectives = value
		queue_redraw()
@export var show_complete: bool = true:
	set(value):
		show_complete = value
		queue_redraw()
@export var show_failed: bool = true:
	set(value):
		show_failed = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(300, 200)
@export var objective_spacing := 20
@export var notify_duration := 3.0
@export var notify_flash_rate := 0.5

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(350, 250)

# Notification tracking
var _notify_objectives: Array[Objective]
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = HUDGauge.DIRECTIVES_VIEW

func _ready() -> void:
	super._ready()

# Add a new objective
func add_objective(text: String, type: ObjectiveType, total_count: int = 1) -> void:
	var obj = Objective.new(text, type, ObjectiveStatus.INCOMPLETE, total_count)
	objectives.append(obj)
	_notify_objectives.append(obj)
	queue_redraw()

# Update objective status
func update_objective_status(index: int, status: ObjectiveStatus, current_count: int = -1) -> void:
	if index >= 0 && index < objectives.size():
		var obj = objectives[index]
		if obj.status != status:
			obj.status = status
			_notify_objectives.append(obj)
		if current_count >= 0:
			obj.current_count = current_count
		queue_redraw()

# Clear all objectives
func clear_objectives() -> void:
	objectives.clear()
	_notify_objectives.clear()
	queue_redraw()

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample objectives for preview
		if objectives.is_empty():
			objectives = [
				Objective.new("Destroy all hostiles", ObjectiveType.PRIMARY, ObjectiveStatus.INCOMPLETE, 5, 2),
				Objective.new("Protect convoy", ObjectiveType.PRIMARY, ObjectiveStatus.COMPLETE),
				Objective.new("Scan debris", ObjectiveType.SECONDARY, ObjectiveStatus.INCOMPLETE),
				Objective.new("Find easter egg", ObjectiveType.BONUS, ObjectiveStatus.FAILED)
			]
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var x = 10
	var y = line_height
	
	# Sort objectives by type
	var sorted_objectives = objectives.duplicate()
	sorted_objectives.sort_custom(func(a, b): return a.type < b.type)
	
	# Draw objectives
	var current_type = -1
	for obj in sorted_objectives:
		# Skip if hidden
		if (!show_complete && obj.status == ObjectiveStatus.COMPLETE) ||
			(!show_failed && obj.status == ObjectiveStatus.FAILED):
			continue
		
		# Draw type header if changed
		if obj.type != current_type:
			current_type = obj.type
			y += 5
			var header = _get_type_header(obj.type)
			draw_string(font, Vector2(x, y), header,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_current_color())
			y += line_height
		
		# Get objective color
		var color = _get_objective_color(obj)
		
		# Check if objective is being notified
		var notify_active = false
		if obj in _notify_objectives:
			var elapsed = Time.get_ticks_msec() / 1000.0 - obj.notify_time
			if elapsed < notify_duration:
				notify_active = _flash_state
			else:
				_notify_objectives.erase(obj)
		
		# Draw status indicator
		var status_char = _get_status_char(obj.status)
		if notify_active:
			draw_string(font, Vector2(x, y), status_char,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, bright_color)
		else:
			draw_string(font, Vector2(x, y), status_char,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		
		# Draw objective text
		var text_x = x + font_size * 2
		draw_string(font, Vector2(text_x, y), obj.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		
		# Draw count if applicable
		if obj.total_count > 1:
			var count_text = "(%d/%d)" % [obj.current_count, obj.total_count]
			var count_width = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, Vector2(gauge_size.x - count_width - 10, y), count_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		
		y += objective_spacing

# Get header text for objective type
func _get_type_header(type: ObjectiveType) -> String:
	match type:
		ObjectiveType.PRIMARY:
			return "PRIMARY OBJECTIVES"
		ObjectiveType.SECONDARY:
			return "SECONDARY OBJECTIVES"
		ObjectiveType.BONUS:
			return "BONUS OBJECTIVES"
		_:
			return ""

# Get status character for objective status
func _get_status_char(status: ObjectiveStatus) -> String:
	match status:
		ObjectiveStatus.COMPLETE:
			return "✓"
		ObjectiveStatus.FAILED:
			return "✗"
		_:
			return "•"

# Get color for objective based on status
func _get_objective_color(obj: Objective) -> Color:
	match obj.status:
		ObjectiveStatus.COMPLETE:
			return Color.GREEN
		ObjectiveStatus.FAILED:
			return Color.RED
		_:
			match obj.type:
				ObjectiveType.PRIMARY:
					return get_current_color()
				ObjectiveType.SECONDARY:
					return Color(get_current_color(), 0.8)
				ObjectiveType.BONUS:
					return Color(get_current_color(), 0.6)
				_:
					return get_current_color()

func _process(delta: float) -> void:
	super._process(delta)
	
	# Update flash state
	if !_notify_objectives.is_empty():
		_flash_time += delta
		if _flash_time >= notify_flash_rate:
			_flash_time = 0.0
			_flash_state = !_flash_state
			queue_redraw()
