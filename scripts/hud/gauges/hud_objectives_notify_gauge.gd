@tool
extends HUDGauge
class_name HUDObjectivesNotifyGauge

# Objective types
enum ObjectiveType {
	PRIMARY,    # Primary mission objectives
	SECONDARY,  # Secondary mission objectives
	BONUS      # Bonus objectives
}

# Objective status
enum ObjectiveStatus {
	INCOMPLETE, # Not yet completed
	COMPLETE,   # Successfully completed
	FAILED      # Failed to complete
}

# Objective info
class ObjectiveInfo:
	var type: ObjectiveType
	var status: ObjectiveStatus
	var text: String
	var total: int
	var completed: int
	var display_time: float
	
	func _init(obj_type: ObjectiveType, obj_status: ObjectiveStatus,
		obj_text: String, total_count: int = 0, complete_count: int = 0) -> void:
		type = obj_type
		status = obj_status
		text = obj_text
		total = total_count
		completed = complete_count
		display_time = 0.0

# Notify settings
@export_group("Notify Settings")
@export var display_duration := 5.0
@export var fade_time := 0.5
@export var show_counts := true:
	set(value):
		show_counts = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(400, 60)
@export var flash_rate := 0.2
@export var success_flash_duration := 1.0
@export var fail_flash_duration := 2.0

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(450, 100)

# Status tracking
var _current_objective: ObjectiveInfo
var _flash_time := 0.0
var _flash_state := false
var _flash_duration := 0.0

func _init() -> void:
	super._init()
	gauge_id = GaugeType.OBJECTIVES_NOTIFY_GAUGE

func _ready() -> void:
	super._ready()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if MissionManager exists (assuming it's an Autoload)
	if Engine.has_singleton("MissionManager"):
		var mission_manager = Engine.get_singleton("MissionManager")
		# Assuming MissionManager has a method to get the *next* objective update
		# that needs to be displayed as a notification. This method should ideally
		# return the data only once per update to avoid re-triggering.
		var notification_data = mission_manager.get_pending_objective_notification() # Placeholder method

		if notification_data:
			# Assuming notification_data is a Dictionary like:
			# { text: "...", type: ObjectiveType.PRIMARY, status: ObjectiveStatus.COMPLETE, total: 1, completed: 1 }

			# Check if this notification is different from the one currently fading out
			# or if no notification is currently active.
			if not _current_objective or _current_objective.text != notification_data.get("text", "") or _current_objective.status != notification_data.get("status", -1):
				show_objective(
					notification_data.get("type", ObjectiveType.PRIMARY),
					notification_data.get("status", ObjectiveStatus.INCOMPLETE),
					notification_data.get("text", ""),
					notification_data.get("total", 0),
					notification_data.get("completed", 0)
				)
	# Note: This gauge automatically clears itself after the display duration in _process.
	# No explicit clear needed here unless triggered by another game state change.


# Show objective update
func show_objective(type: ObjectiveType, status: ObjectiveStatus,
	text: String, total: int = 0, completed: int = 0) -> void:
	_current_objective = ObjectiveInfo.new(type, status, text, total, completed)
	_current_objective.display_time = display_duration
	
	# Set flash duration based on status
	match status:
		ObjectiveStatus.COMPLETE:
			_flash_duration = success_flash_duration
		ObjectiveStatus.FAILED:
			_flash_duration = fail_flash_duration
		_:
			_flash_duration = 0.0
	
	queue_redraw()

# Clear current objective
func clear_objective() -> void:
	_current_objective = null
	_flash_duration = 0.0
	queue_redraw()

# Get color for objective type and status
func _get_objective_color() -> Color:
	if !_current_objective:
		return get_current_color()
	
	var color: Color
	
	# Set base color by type
	match _current_objective.type:
		ObjectiveType.PRIMARY:
			color = Color.GREEN
		ObjectiveType.SECONDARY:
			color = Color.YELLOW
		ObjectiveType.BONUS:
			color = Color.LIGHT_BLUE
		_:
			color = get_current_color()
	
	# Modify based on status
	match _current_objective.status:
		ObjectiveStatus.COMPLETE:
			color = Color.GREEN
		ObjectiveStatus.FAILED:
			color = Color.RED
	
	# Flash effect
	if _flash_duration > 0 && _flash_state:
		color = Color.WHITE
	
	return color

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample objective for preview
		if !_current_objective:
			show_objective(ObjectiveType.PRIMARY, ObjectiveStatus.COMPLETE,
				"Protect the convoy", 3, 2)
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	if !_current_objective:
		return
		
	# Calculate fade alpha
	var alpha = 1.0
	if _current_objective.display_time < fade_time:
		alpha = _current_objective.display_time / fade_time
	
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var x = 10
	var y = line_height
	
	# Get display color
	var color = _get_objective_color()
	color.a = alpha
	
	# Draw objective type
	var type_text = ""
	match _current_objective.type:
		ObjectiveType.PRIMARY:
			type_text = "Primary Objective"
		ObjectiveType.SECONDARY:
			type_text = "Secondary Objective"
		ObjectiveType.BONUS:
			type_text = "Bonus Objective"
	
	draw_string(font, Vector2(x, y), type_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	
	# Draw status and counts
	y += line_height
	var status_text = _current_objective.text
	
	if show_counts && _current_objective.total > 0:
		status_text += " (%d/%d)" % [_current_objective.completed, _current_objective.total]
	
	match _current_objective.status:
		ObjectiveStatus.COMPLETE:
			status_text += " - Complete"
		ObjectiveStatus.FAILED:
			status_text += " - Failed"
	
	draw_string(font, Vector2(x, y), status_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update display time
	if _current_objective:
		_current_objective.display_time -= delta
		if _current_objective.display_time <= 0:
			clear_objective()
		needs_redraw = true
	
	# Update flash state
	if _flash_duration > 0:
		_flash_duration -= delta
		
		_flash_time += delta
		if _flash_time >= flash_rate:
			_flash_time = 0.0
			_flash_state = !_flash_state
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
