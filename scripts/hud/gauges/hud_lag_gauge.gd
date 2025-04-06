@tool
extends HUDGauge
class_name HUDLagGauge

# Lag status levels
enum LagStatus {
	GOOD,      # Good connection
	WARNING,   # Minor lag issues
	CRITICAL   # Severe lag issues
}

# Lag settings
@export_group("Lag Settings")
@export var lag_active := false:
	set(value):
		lag_active = value
		queue_redraw()
@export var ping_ms := 0:
	set(value):
		ping_ms = maxi(0, value)
		_update_lag_status()
		queue_redraw()

# Warning thresholds
@export_group("Warning Thresholds")
@export var warning_threshold := 150:
	set(value):
		warning_threshold = maxi(0, value)
		_update_lag_status()
@export var critical_threshold := 300:
	set(value):
		critical_threshold = maxi(warning_threshold, value)
		_update_lag_status()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(80, 40)
@export var icon_size := 24.0
@export var show_ping := true:
	set(value):
		show_ping = value
		queue_redraw()
@export var flash_rate := 0.2
@export var flash_critical := true

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(100, 60)

# Status tracking
var _current_status: LagStatus
var _flash_time := 0.0
var _flash_state := false
var _packet_loss := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.LAG_GAUGE

func _ready() -> void:
	super._ready()
	_update_lag_status()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if in multiplayer mode (assuming MultiplayerAPI or a NetworkManager)
	if multiplayer.is_server() or multiplayer.has_multiplayer_peer():
		# TODO: Replace with actual network status query
		var current_ping = 0 # Placeholder: NetworkManager.get_ping()
		var packet_loss_detected = false # Placeholder: NetworkManager.has_packet_loss()

		# Get ping to server if client, or maybe average ping if server?
		if multiplayer.get_multiplayer_peer() and multiplayer.get_multiplayer_peer().get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			# Godot 4 doesn't have a direct ping API easily accessible here.
			# This would likely need to be tracked via custom network messages or a NetworkManager singleton.
			# For now, use placeholder values.
			# Example placeholder logic:
			# current_ping = NetworkManager.get_average_ping() if multiplayer.is_server() else NetworkManager.get_server_ping()
			# packet_loss_detected = NetworkManager.is_experiencing_packet_loss()
			pass # Keep placeholders for now

		# Only show if ping is non-zero or packet loss is detected
		if current_ping > 0 or packet_loss_detected:
			show_lag(current_ping, packet_loss_detected)
		else:
			# Optionally clear if ping is 0 and no loss, or keep showing 0ms?
			# Let's clear it if ping is 0 and no loss.
			clear_lag()
	else:
		# Not in multiplayer, clear the gauge
		clear_lag()

# Show lag status
func show_lag(ping: int, packet_loss: bool = false) -> void:
	lag_active = true
	ping_ms = ping
	_packet_loss = packet_loss
	queue_redraw()

# Clear lag status
func clear_lag() -> void:
	lag_active = false
	_packet_loss = false
	queue_redraw()

# Update current lag status
func _update_lag_status() -> void:
	if _packet_loss || ping_ms >= critical_threshold:
		_current_status = LagStatus.CRITICAL
	elif ping_ms >= warning_threshold:
		_current_status = LagStatus.WARNING
	else:
		_current_status = LagStatus.GOOD

# Get color based on lag status
func _get_status_color() -> Color:
	var color = get_current_color()
	
	match _current_status:
		LagStatus.GOOD:
			color = Color.GREEN
		LagStatus.WARNING:
			color = Color.YELLOW
		LagStatus.CRITICAL:
			color = Color.RED
			if flash_critical && _flash_state:
				color = Color.WHITE
	
	return color

# Draw lag icon
func _draw_lag_icon(pos: Vector2, color: Color) -> void:
	var half_size = icon_size * 0.5
	var quarter_size = icon_size * 0.25
	
	# Draw signal bars based on status
	match _current_status:
		LagStatus.GOOD:
			# Three bars
			draw_rect(Rect2(
				pos.x - half_size,
				pos.y - quarter_size,
				quarter_size,
				half_size
			), color)
			draw_rect(Rect2(
				pos.x - quarter_size,
				pos.y - quarter_size * 2,
				quarter_size,
				half_size + quarter_size
			), color)
			draw_rect(Rect2(
				pos.x,
				pos.y - half_size,
				quarter_size,
				icon_size
			), color)
		
		LagStatus.WARNING:
			# Two bars
			draw_rect(Rect2(
				pos.x - half_size,
				pos.y - quarter_size,
				quarter_size,
				half_size
			), color)
			draw_rect(Rect2(
				pos.x - quarter_size,
				pos.y - quarter_size * 2,
				quarter_size,
				half_size + quarter_size
			), color)
			# Outline for third bar
			draw_rect(Rect2(
				pos.x,
				pos.y - half_size,
				quarter_size,
				icon_size
			), color, false)
		
		LagStatus.CRITICAL:
			# One bar
			draw_rect(Rect2(
				pos.x - half_size,
				pos.y - quarter_size,
				quarter_size,
				half_size
			), color)
			# Outlines for other bars
			draw_rect(Rect2(
				pos.x - quarter_size,
				pos.y - quarter_size * 2,
				quarter_size,
				half_size + quarter_size
			), color, false)
			draw_rect(Rect2(
				pos.x,
				pos.y - half_size,
				quarter_size,
				icon_size
			), color, false)
	
	# Draw X for packet loss
	if _packet_loss:
		var x_size = quarter_size
		var x_offset = Vector2(x_size, x_size)
		var x_pos = pos + Vector2(quarter_size * 2, -quarter_size)
		
		draw_line(x_pos - x_offset, x_pos + x_offset, color, 2.0)
		draw_line(x_pos + Vector2(-x_size, x_size), x_pos + Vector2(x_size, -x_size), color, 2.0)

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample lag for preview
		if !lag_active:
			show_lag(200, true)
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	if !lag_active:
		return
		
	var size = gauge_size
	if Engine.is_editor_hint():
		size = preview_size
	
	var color = _get_status_color()
	
	# Draw lag icon
	var icon_pos = Vector2(
		size.x * 0.5,
		size.y * 0.5
	)
	_draw_lag_icon(icon_pos, color)
	
	# Draw ping if enabled
	if show_ping:
		var font = ThemeDB.fallback_font
		var font_size = ThemeDB.fallback_font_size
		
		var ping_text = "%dms" % ping_ms
		var text_pos = Vector2(
			size.x * 0.5,
			size.y + font_size + 5
		)
		
		draw_string(font, text_pos, ping_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		if lag_active && (_current_status == LagStatus.CRITICAL || _packet_loss) && flash_critical:
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
