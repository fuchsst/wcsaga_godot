@tool
extends HUDGauge
class_name HUDThreatGauge

# Threat settings
@export_group("Threat Settings")
@export var threats: Array[Threat]:
	set(value):
		threats = value
		queue_redraw()
@export var max_threats := 8:
	set(value):
		max_threats = value
		_adjust_threat_list()
		queue_redraw()
@export var warning_duration := 3.0
@export var max_warning_distance := 5000.0

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(200, 200)
@export var indicator_size := 20.0
@export var arrow_size := 15.0
@export var flash_rate := 0.2
@export var warning_flash_rate := 0.1

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(250, 250)

# Warning tracking
var _flash_time := 0.0
var _flash_state := false
var _warning_flash_time := 0.0
var _warning_flash_state := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.THREAT_GAUGE

func _ready() -> void:
	super._ready()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship exists
	if GameState.player_ship and is_instance_valid(GameState.player_ship):
		# Get threat list from the player ship
		# Assuming PlayerShip has a method get_current_threats() that returns an array of Dictionaries
		# matching the Threat class structure or adaptable to it.
		var current_threats_data = GameState.player_ship.get_current_threats() # Placeholder method

		var new_threats_list = []
		var updated = false

		for threat_data in current_threats_data:
			# Assuming threat_data is a Dictionary like:
			# { type: Threat.Type.MISSILE, direction: Vector3, distance: float, source_name: "", is_locked: false }
			var new_threat = Threat.new(
				threat_data.get("type", Threat.Type.FIGHTER),
				threat_data.get("direction", Vector3.FORWARD),
				threat_data.get("distance", 0.0),
				threat_data.get("source_name", ""),
				threat_data.get("is_locked", false)
			)
			# TODO: Add logic to update existing threats instead of replacing the whole list?
			# This would require matching threats based on source object ID or similar.
			# For now, just replace the list.
			new_threats_list.append(new_threat)

		# Simple check if the number of threats changed
		if threats.size() != new_threats_list.size():
			updated = true
		# TODO: Add more robust check if threat details changed

		# Update the gauge's threats array if changed (setter handles redraw)
		if updated:
			threats = new_threats_list
		elif not threats.is_empty() and not new_threats_list.is_empty() and threats[0].source_name != new_threats_list[0].source_name:
			# Fallback redraw if first threat changed but size didn't
			threats = new_threats_list

	else:
		# No player ship, clear threats
		if not threats.is_empty():
			clear_threats()


# Add a new threat
func add_threat(type: Threat.Type, direction: Vector3, distance: float,
	source_name: String = "", is_locked: bool = false) -> void:
	var threat = Threat.new(type, direction, distance, source_name, is_locked)
	threats.append(threat)
	_adjust_threat_list()
	queue_redraw()

# Update threat status
func update_threat(index: int, direction: Vector3, distance: float,
	is_locked: bool = false) -> void:
	if index >= 0 && index < threats.size():
		var threat = threats[index]
		threat.direction = direction
		threat.distance = distance
		if !threat.is_locked && is_locked:
			threat.warning_time = warning_duration
		threat.is_locked = is_locked
		queue_redraw()

# Remove a threat
func remove_threat(index: int) -> void:
	if index >= 0 && index < threats.size():
		threats.remove_at(index)
		queue_redraw()

# Clear all threats
func clear_threats() -> void:
	threats.clear()
	queue_redraw()

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample threats for preview
		if threats.is_empty():
			threats = [
				Threat.new(Threat.Type.MISSILE, Vector3(1, 0, 0), 1000, "Missile", true),
				Threat.new(Threat.Type.FIGHTER, Vector3(0, 1, 0), 2000, "Fighter"),
				Threat.new(Threat.Type.CAPITAL, Vector3(-1, -1, 0), 3000, "Cruiser")
			]
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var center = gauge_size / 2
	if Engine.is_editor_hint():
		center = preview_size / 2
	
	# Draw radar circle
	var color = get_current_color()
	draw_arc(center, indicator_size, 0, TAU, 32, color)
	
	# Draw cardinal directions
	var dir_size = indicator_size + 10
	var dir_text = ["N", "E", "S", "W"]
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	
	for i in range(4):
		var angle = i * PI/2
		var dir_pos = center + Vector2(cos(angle), sin(angle)) * dir_size
		draw_string(font, dir_pos, dir_text[i],
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
	
	# Sort threats by distance
	var sorted_threats = threats.duplicate()
	sorted_threats.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Draw threats
	for threat in sorted_threats:
		if !threat.is_active:
			continue
		
		# Calculate threat position
		var threat_dir = Vector2(threat.direction.x, threat.direction.z).normalized()
		var distance_ratio = clampf(threat.distance / max_warning_distance, 0.0, 1.0)
		var threat_pos = center + threat_dir * indicator_size * distance_ratio
		
		# Get threat color
		var threat_color = _get_threat_color(threat)
		
		# Handle warning flash for locked threats
		if threat.is_locked && threat.warning_time > 0:
			if _warning_flash_state:
				threat_color = Color.RED
		
		# Draw threat indicator based on type
		match threat.type:
			Threat.Type.MISSILE, Threat.Type.TORPEDO:
				_draw_missile_indicator(threat_pos, threat_dir, threat_color)
			Threat.Type.BEAM:
				_draw_beam_indicator(threat_pos, threat_dir, threat_color)
			Threat.Type.FIGHTER:
				_draw_fighter_indicator(threat_pos, threat_color)
			Threat.Type.CAPITAL:
				_draw_capital_indicator(threat_pos, threat_color)
		
		# Draw distance if close
		if distance_ratio <= 0.5:
			var dist_text = "%.0fm" % threat.distance
			draw_string(font, threat_pos + Vector2(10, 10), dist_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, threat_color)

# Draw missile threat indicator
func _draw_missile_indicator(pos: Vector2, dir: Vector2, color: Color) -> void:
	# Draw arrow pointing in direction of travel
	var perp = Vector2(-dir.y, dir.x)
	var points = PackedVector2Array([
		pos + dir * arrow_size,
		pos - dir * arrow_size/2 + perp * arrow_size/2,
		pos - dir * arrow_size/2 - perp * arrow_size/2
	])
	draw_colored_polygon(points, color)

# Draw beam weapon indicator
func _draw_beam_indicator(pos: Vector2, dir: Vector2, color: Color) -> void:
	# Draw lightning bolt symbol
	var perp = Vector2(-dir.y, dir.x) * arrow_size/4
	var points = [
		pos + dir * arrow_size,
		pos,
		pos - dir * arrow_size/2 + perp,
		pos - perp,
		pos - dir * arrow_size
	]
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color)

# Draw fighter threat indicator
func _draw_fighter_indicator(pos: Vector2, color: Color) -> void:
	# Draw diamond shape
	var size = arrow_size/2
	var points = PackedVector2Array([
		pos + Vector2(0, -size),
		pos + Vector2(size, 0),
		pos + Vector2(0, size),
		pos + Vector2(-size, 0)
	])
	draw_colored_polygon(points, color)

# Draw capital ship indicator
func _draw_capital_indicator(pos: Vector2, color: Color) -> void:
	# Draw square shape
	var size = arrow_size/2
	draw_rect(Rect2(pos - Vector2(size, size), Vector2(size * 2, size * 2)), color)

# Get color for threat based on type and status
func _get_threat_color(threat: Threat) -> Color:
	if threat.is_locked:
		return Color.RED
	
	match threat.type:
		Threat.Type.MISSILE, Threat.Type.TORPEDO:
			return Color.RED
		Threat.Type.BEAM:
			return Color.YELLOW
		Threat.Type.FIGHTER:
			return Color.ORANGE
		Threat.Type.CAPITAL:
			return Color.RED
		_:
			return get_current_color()

# Adjust threat list size
func _adjust_threat_list() -> void:
	while threats.size() > max_threats:
		threats.pop_front()

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update threat warning times
	for threat in threats:
		if threat.warning_time > 0:
			threat.warning_time -= delta
			needs_redraw = true
	
	# Update flash states
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		needs_redraw = true
	
	_warning_flash_time += delta
	if _warning_flash_time >= warning_flash_rate:
		_warning_flash_time = 0.0
		_warning_flash_state = !_warning_flash_state
		needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
