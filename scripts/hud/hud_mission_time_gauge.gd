@tool
extends HUDGauge
class_name HUDMissionTimeGauge

# Time settings
@export_group("Time Settings")
@export var mission_time := 0.0:
	set(value):
		mission_time = value
		queue_redraw()
@export var time_compression := 1.0:
	set(value):
		time_compression = value
		queue_redraw()
@export var show_compression := true:
	set(value):
		show_compression = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(150, 50)
@export var time_format := TimeFormat.MMSS:
	set(value):
		time_format = value
		queue_redraw()
@export var flash_rate := 0.5

# Time format options
enum TimeFormat {
	MMSS,      # Minutes:Seconds
	HHMMSS,    # Hours:Minutes:Seconds
	DECIMAL    # Decimal hours
}

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(200, 80)

# Status tracking
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.MISSION_TIME

func _ready() -> void:
	super._ready()

# Update mission time
func update_time(time: float, compression: float = -1.0) -> void:
	mission_time = time
	if compression >= 0:
		time_compression = compression
	queue_redraw()

# Format time string based on current format
func _format_time() -> String:
	var hours := floori(mission_time / 3600.0)
	var minutes := floori(fmod(mission_time, 3600.0) / 60.0)
	var seconds := floori(fmod(mission_time, 60.0))
	
	match time_format:
		TimeFormat.MMSS:
			return "%02d:%02d" % [minutes + hours * 60, seconds]
		TimeFormat.HHMMSS:
			return "%02d:%02d:%02d" % [hours, minutes, seconds]
		TimeFormat.DECIMAL:
			return "%.1fh" % (mission_time / 3600.0)
		_:
			return "00:00"

# Format compression string
func _format_compression() -> String:
	if time_compression < 1.0:
		return "%.2f" % time_compression
	else:
		return "x%.1f" % time_compression

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample time for preview
		if mission_time == 0:
			mission_time = 3723.5  # 1h 2m 3.5s
			time_compression = 2.0
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var x = 10
	var y = line_height
	
	# Get display color
	var color = get_current_color()
	if time_compression != 1.0 && _flash_state:
		color = Color.YELLOW
	
	# Draw mission time
	var time_text = _format_time()
	draw_string(font, Vector2(x, y), time_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	
	# Draw time compression if enabled
	if show_compression && time_compression != 1.0:
		var comp_text = _format_compression()
		draw_string(font, Vector2(x, y + line_height), comp_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		if time_compression != 1.0:
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
