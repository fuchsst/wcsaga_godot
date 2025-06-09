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
	var time: float          # Timestamp when the *first line* of the message was added
	var duration: float
	var is_active: bool
	var x_pos: int = 10      # X position for drawing this specific line (handles indentation)

	func _init(t: String = "", src: MessageSource = MessageSource.COMPUTER,
		name: String = "", dur: float = 5.0, p_x_pos: int = 10) -> void:
		text = t
		source = src
		source_name = name
		time = Time.get_ticks_msec() / 1000.0
		duration = dur
		is_active = true
		x_pos = p_x_pos

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
@export var source_width := 80 # Estimated width for source name prefix

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
	_messages = [] # Ensure initialized

func _ready() -> void:
	super._ready()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if MessageManager exists (assuming it's an Autoload)
	if Engine.has_singleton("MessageManager"):
		var message_manager = Engine.get_singleton("MessageManager")
		# Assuming MessageManager has a method to get new messages since last check
		var new_messages_data = message_manager.get_new_hud_messages() # Placeholder method

		if not new_messages_data.is_empty():
			for msg_data in new_messages_data:
				# Assuming msg_data is a Dictionary like:
				# { text: "...", source: MessageSource.COMPUTER, source_name: "", duration: 5.0 }
				_add_and_split_message(
					msg_data.get("text", ""),
					msg_data.get("source", MessageSource.COMPUTER),
					msg_data.get("source_name", ""),
					msg_data.get("duration", message_duration)
				)
			queue_redraw() # Redraw if new messages were added
	else:
		# No MessageManager available
		pass

# Helper to split long messages and add lines
func _add_and_split_message(text: String, source: MessageSource, source_name: String, duration: float=5.0):
	var font = ThemeDB.fallback_font
	if not font:
		printerr("HUDMessageGauge: Fallback font not found in ThemeDB!")
		# Add the message without splitting as a fallback
		add_message_line(text, source, source_name, duration, 10)
		return

	var font_size = ThemeDB.fallback_font_size
	var max_width = gauge_size.x - 20 # Available width minus padding
	var t = Time.get_ticks_msec() / 1000.0 # Timestamp for the first line
	var x_start = 10
	var x_indent = 10
	var offset = 0

	# Handle source prefix width for indentation
	if source_name != "":
		var source_text = source_name + ":"
		var source_width = font.get_string_size(source_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		offset = source_width + 5 # Add some spacing
		x_indent += offset # Indent subsequent lines

	var current_line = text
	var first_line = true

	while not current_line.is_empty():
		var split_index = -1
		var current_max_width = max_width - (offset if first_line else 0)

		# Manual width check (approximate)
		var current_width = 0
		for i in range(current_line.length()):
			current_width = font.get_string_size(current_line.substr(0, i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if current_width > current_max_width:
				# Find last space before this point to split nicely
				var last_space = current_line.rfind(" ", i)
				# Split at space if it's reasonably close, otherwise force split
				if last_space > 0 and last_space > i - 20:
					split_index = last_space + 1 # Split after the space
				else:
					split_index = i # Split mid-word
				break

		var line_to_add: String
		if split_index != -1:
			line_to_add = current_line.substr(0, split_index).strip_edges()
			current_line = current_line.substr(split_index).strip_edges()
		else:
			line_to_add = current_line
			current_line = "" # No more text left

		# Add the line
		var line_source = source # Keep original source for color
		var line_source_name = source_name if first_line else ""
		var line_x_pos = x_start if first_line else x_indent
		add_message_line(line_to_add, line_source, line_source_name, duration, line_x_pos, t if first_line else 0)

		first_line = false


# Add a single formatted line to the internal list
# Added timestamp parameter to ensure all parts of a split message expire together
func add_message_line(text: String, source: MessageSource, source_name: String, duration: float, x_pos: int, p_time: float = 0.0):
	var msg = Message.new(text, source, source_name, duration, x_pos)
	if p_time > 0: # Use provided timestamp for the first line
		msg.time = p_time
	# Subsequent lines will use their own creation time from Message.new()
	# but expire based on the duration set from the original message.
	_messages.append(msg)
	_adjust_message_list()
	_update_scroll()


# Add a new message (original function, now calls splitter)
func add_message(text: String, source: MessageSource = MessageSource.COMPUTER,
	source_name: String = "", duration: float = -1.0) -> void:
	# Use the splitter function instead
	_add_and_split_message(text, source, source_name, message_duration if duration < 0 else duration)
	queue_redraw()

# Add a ship message
func add_ship_message(ship_name: String, text: String) -> void:
	_add_and_split_message(text, MessageSource.SHIP, ship_name, message_duration)
	queue_redraw()

# Add a wingman message
func add_wingman_message(wingman_name: String, text: String) -> void:
	_add_and_split_message(text, MessageSource.WINGMAN, wingman_name, message_duration)
	queue_redraw()

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
			# Use the splitter to add sample messages correctly
			_add_and_split_message("Mission objectives updated: Destroy the Kilrathi carrier before it launches fighters.", MessageSource.COMPUTER, "", 8.0)
			_add_and_split_message("Watch your six!", MessageSource.WINGMAN, "Alpha 2")
			_add_and_split_message("Engaging hostiles near Nav Point 1.", MessageSource.SHIP, "TCS Victory")
			_add_and_split_message("Training complete. Proceed to next objective.", MessageSource.TRAINING, "")

	if !can_draw() && !Engine.is_editor_hint():
		return

	var font = ThemeDB.fallback_font
	if not font: return # Cannot draw without font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var y = gauge_size.y - line_height + _scroll_offset

	# Draw messages from bottom up
	for msg in _messages:
		if !msg.is_active:
			continue

		# Get message color
		var color = _get_message_color(msg)

		# Draw source if applicable (only for first line of a message group)
		var x = msg.x_pos # Use stored x position
		if msg.source_name != "":
			var source_text = msg.source_name + ":"
			draw_string(font, Vector2(x, y), source_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			x += source_width # Adjust x for the message text

		# Draw message text
		draw_string(font, Vector2(x, y), msg.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

		# Move up for next line
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

	# Update message active states based on the timestamp of the *first* line
	# This requires knowing which message group a line belongs to, or storing expiry time directly.
	# Let's simplify: assume all lines added from one original message expire together based on the first line's time.
	# We need to iterate backwards to safely remove items while iterating.
	for i in range(_messages.size() - 1, -1, -1):
		var msg = _messages[i]
		if msg.is_active and current_time - msg.time > msg.duration:
			msg.is_active = false
			needs_redraw = true

	# Remove inactive messages from front (more efficient than filter)
	while !_messages.is_empty() and !_messages[0].is_active:
		_messages.pop_front()
		needs_redraw = true
		_update_scroll() # Recalculate scroll target after removal

	# Update scroll animation
	if abs(_scroll_offset - _target_scroll) > 0.1: # Add tolerance
		var scroll_dir = sign(_target_scroll - _scroll_offset)
		_scroll_offset += scroll_dir * scroll_speed * delta

		# Clamp to target
		if (scroll_dir > 0 and _scroll_offset >= _target_scroll) or \
		   (scroll_dir < 0 and _scroll_offset <= _target_scroll):
			_scroll_offset = _target_scroll

		needs_redraw = true

	if needs_redraw:
		queue_redraw()
