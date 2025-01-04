@tool
extends HUDGauge
class_name HUDMessageGauge

# Message sources
enum MessageSource {
	COMPUTER,    # System messages
	TRAINING,    # Training messages
	COMMAND,     # Command messages
	IMPORTANT,   # Important alerts
	WINGMAN,     # Wingman comms
	SHIP,        # Ship comms
	FAILED,      # Mission failure
	SATISFIED    # Mission success
}

# Message info
class Message:
	var text: String
	var source: MessageSource
	var source_name: String  # For ship/wingman messages
	var time: float
	var duration: float
	var is_active: bool
	
	func _init(t: String = "", src: MessageSource = MessageSource.COMPUTER,
		name: String = "", dur: float = 5.0) -> void:
		text = t
		source = src
		source_name = name
		time = Time.get_ticks_msec() / 1000.0
		duration = dur
		is_active = true

# Message settings
@export_group("Message Settings")
@export var max_messages := 4:
	set(value):
		max_messages = value
		_adjust_message_list()
		queue_redraw()
@export var message_duration := 5.0
@export var scroll_speed := 50.0

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(400, 100)
@export var message_spacing := 20
@export var source_width := 80

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(450, 150)

# Message tracking
var _messages: Array[Message]
var _scroll_offset := 0.0
var _target_scroll := 0.0

func _init() -> void:
	super._init()
	gauge_id = GaugeType.MESSAGE_LINES

func _ready() -> void:
	super._ready()

# Add a new message
func add_message(text: String, source: MessageSource = MessageSource.COMPUTER,
	source_name: String = "", duration: float = -1.0) -> void:
	# Create new message
	var msg = Message.new(text, source, source_name,
		message_duration if duration < 0 else duration)
	
	# Add to list
	_messages.append(msg)
	
	# Adjust list size if needed
	_adjust_message_list()
	
	# Update scroll
	_update_scroll()
	queue_redraw()

# Add a ship message
func add_ship_message(ship_name: String, text: String) -> void:
	add_message(text, MessageSource.SHIP, ship_name)

# Add a wingman message
func add_wingman_message(wingman_name: String, text: String) -> void:
	add_message(text, MessageSource.WINGMAN, wingman_name)

# Clear all messages
func clear_messages() -> void:
	_messages.clear()
	_scroll_offset = 0.0
	_target_scroll = 0.0
	queue_redraw()

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample messages for preview
		if _messages.is_empty():
			_messages = [
				Message.new("Mission objectives updated", MessageSource.COMPUTER),
				Message.new("Watch your six!", MessageSource.WINGMAN, "Alpha 2"),
				Message.new("Engaging hostiles", MessageSource.SHIP, "TCS Victory"),
				Message.new("Training complete", MessageSource.TRAINING)
			]
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var x = 10
	var y = gauge_size.y - line_height + _scroll_offset
	
	# Draw messages from bottom up
	for msg in _messages:
		if !msg.is_active:
			continue
			
		# Get message color
		var color = _get_message_color(msg)
		
		# Draw source if applicable
		if msg.source_name != "":
			var source_text = msg.source_name + ":"
			draw_string(font, Vector2(x, y), source_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			x += source_width
		
		# Draw message text
		draw_string(font, Vector2(x, y), msg.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		
		# Reset x and move up
		x = 10
		y -= message_spacing

# Get color for message based on source
func _get_message_color(msg: Message) -> Color:
	match msg.source:
		MessageSource.COMPUTER:
			return get_current_color()
		MessageSource.TRAINING:
			return Color.CYAN
		MessageSource.COMMAND:
			return Color.YELLOW
		MessageSource.IMPORTANT:
			return Color.RED
		MessageSource.WINGMAN:
			return Color.GREEN
		MessageSource.SHIP:
			return Color.LIGHT_BLUE
		MessageSource.FAILED:
			return Color.RED
		MessageSource.SATISFIED:
			return Color.GREEN
		_:
			return get_current_color()

# Adjust message list size
func _adjust_message_list() -> void:
	while _messages.size() > max_messages:
		_messages.pop_front()

# Update scroll position
func _update_scroll() -> void:
	var total_height = (_messages.size() - 1) * message_spacing
	_target_scroll = minf(0, -total_height)

func _process(delta: float) -> void:
	super._process(delta)
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var needs_redraw = false
	
	# Update message active states
	for msg in _messages:
		if msg.is_active && current_time - msg.time > msg.duration:
			msg.is_active = false
			needs_redraw = true
	
	# Remove inactive messages from front
	while !_messages.is_empty() && !_messages[0].is_active:
		_messages.pop_front()
		needs_redraw = true
	
	# Update scroll
	if _scroll_offset != _target_scroll:
		var scroll_dir = sign(_target_scroll - _scroll_offset)
		_scroll_offset += scroll_dir * scroll_speed * delta
		
		# Check if we've reached target
		if scroll_dir > 0 && _scroll_offset >= _target_scroll:
			_scroll_offset = _target_scroll
		elif scroll_dir < 0 && _scroll_offset <= _target_scroll:
			_scroll_offset = _target_scroll
			
		needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
