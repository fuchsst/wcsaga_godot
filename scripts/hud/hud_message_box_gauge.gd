@tool
extends HUDGauge
class_name HUDMessageBoxGauge

# Message types
enum MessageType {
	NORMAL,     # Standard message
	IMPORTANT,  # Important mission info
	WARNING,    # Warning message
	ALERT,      # Critical alert
	COMM,       # Communication
	OBJECTIVE   # Mission objective
}

# Message info
class Message:
	var text: String
	var type: MessageType
	var duration: float
	var time_left: float
	var flash_time: float
	var source_name: String
	var is_active: bool
	
	func _init(msg: String, msg_type: MessageType, time: float,
		source: String = "") -> void:
		text = msg
		type = msg_type
		duration = time
		time_left = time
		flash_time = 0.0
		source_name = source
		is_active = true

# Message settings
@export_group("Message Settings")
@export var max_messages := 4:
	set(value):
		max_messages = value
		_adjust_message_list()
		queue_redraw()
@export var default_duration := 5.0
@export var important_duration := 8.0
@export var scroll_speed := 50.0

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(400, 150)
@export var line_spacing := 4
@export var flash_rate := 0.2
@export var fade_time := 0.5

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(450, 200)

# Message queue
var messages: Array[Message]
var _scroll_offset := 0.0
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.MESSAGE_BOX
	if flash_duration == 0:
		flash_duration = 1.0
	messages = []

func _ready() -> void:
	super._ready()

# Add a new message
func add_message(text: String, type: MessageType = MessageType.NORMAL,
	duration: float = -1.0, source: String = "") -> void:
	# Set duration based on type if not specified
	if duration < 0:
		duration = important_duration if type > MessageType.NORMAL else default_duration
	
	var message = Message.new(text, type, duration, source)
	messages.append(message)
	
	# Start flash effect for important messages
	if type > MessageType.NORMAL:
		message.flash_time = flash_duration
	
	_adjust_message_list()
	queue_redraw()

# Clear all messages
func clear_messages() -> void:
	messages.clear()
	_scroll_offset = 0.0
	queue_redraw()

# Adjust message list size
func _adjust_message_list() -> void:
	while messages.size() > max_messages:
		messages.pop_front()

# Get color for message type
func _get_message_color(type: MessageType, alpha: float = 1.0) -> Color:
	var color = get_current_color()
	
	match type:
		MessageType.IMPORTANT:
			color = Color.YELLOW
		MessageType.WARNING:
			color = Color.ORANGE
		MessageType.ALERT:
			color = Color.RED
		MessageType.COMM:
			color = Color.LIGHT_BLUE
		MessageType.OBJECTIVE:
			color = Color.GREEN
	
	return Color(color, alpha)

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample messages for preview
		if messages.is_empty():
			add_message("Mission Objective: Protect the convoy", MessageType.OBJECTIVE)
			add_message("Warning: Multiple bogies inbound", MessageType.WARNING)
			add_message("TCS Victory: Reinforcements en route", MessageType.COMM)
			add_message("Scanning target...", MessageType.NORMAL)
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + line_spacing
	var x = 10
	var y = line_height
	
	# Draw messages from bottom up
	for i in range(messages.size() - 1, -1, -1):
		var msg = messages[i]
		if !msg.is_active:
			continue
		
		# Calculate fade alpha
		var alpha = 1.0
		if msg.time_left < fade_time:
			alpha = msg.time_left / fade_time
		
		# Get message color
		var color = _get_message_color(msg.type, alpha)
		if msg.flash_time > 0 && _flash_state:
			color = Color.WHITE
		
		# Draw source name if present
		if msg.source_name:
			draw_string(font, Vector2(x, y), msg.source_name + ":",
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			x += 80
		
		# Draw message text
		draw_string(font, Vector2(x, y), msg.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		
		# Reset x and increment y
		x = 10
		y += line_height

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update message timers
	for msg in messages:
		if msg.is_active:
			msg.time_left -= delta
			if msg.time_left <= 0:
				msg.is_active = false
			if msg.flash_time > 0:
				msg.flash_time -= delta
			needs_redraw = true
	
	# Remove expired messages
	messages = messages.filter(func(msg): return msg.is_active)
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
