@tool
extends HUDGauge
class_name HUDRadarGauge

# Radar range settings
enum RadarRange {
	SHORT = 0,    # 2000m
	LONG = 1,     # 10000m
	INFINITE = 2  # No limit
}

# Radar ranges in meters
const RADAR_RANGES = [
	2000.0,    # SHORT
	10000.0,   # LONG
	1.0e10     # INFINITE
]

# Blip types matching original
enum BlipType {
	JUMP_NODE,
	NAVBUOY_CARGO,
	BOMB,
	WARPING_SHIP,
	TAGGED_SHIP,
	NORMAL_SHIP
}

# Radar settings
@export_group("Radar Settings")
@export var current_range: RadarRange = RadarRange.SHORT:
	set(value):
		current_range = value
		queue_redraw()
@export var show_debris: bool = true:
	set(value):
		show_debris = value
		queue_redraw()
@export var show_friendly_missiles: bool = true:
	set(value):
		show_friendly_missiles = value
		queue_redraw()
@export var show_hostile_missiles: bool = true:
	set(value):
		show_hostile_missiles = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var radius: float = 60.0
@export var blip_size: float = 2.0
@export var ring_spacing: float = 20.0
@export var num_rings: int = 3
@export var flash_rate := 0.2
@export var warning_flash_rate := 0.1
@export var sensor_distortion_angle := 20.0
@export var static_effect_intensity := 0.5
@export var range_indicator_size := Vector2(40, 15)

# Sensor settings
@export_group("Sensor Settings")
@export var min_sensor_strength := 0.25 # Minimum sensor strength for radar to work
@export var sensor_noise_threshold := 0.75 # Sensor strength below which noise appears

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(150, 150)

# Radar object class
class RadarBlip:
	var position: Vector3
	var type: BlipType
	var team: int
	var is_targeted: bool
	var is_distorted: bool
	var flash_time: float
	var color: Color
	
	func _init(pos: Vector3, blip_type: BlipType, blip_team: int, targeted: bool = false) -> void:
		position = pos
		type = blip_type
		team = blip_team
		is_targeted = targeted
		is_distorted = false
		flash_time = 0.0

# Radar state
var _radar_objects: Array[RadarBlip] = []
var _flash_time := 0.0
var _flash_state := false
var _warning_flash_time := 0.0
var _warning_flash_state := false
var _bright_range := 1500.0 # Default bright range
var _calc_bright_range_timer := 0.0
var _static_sound_id := -1 # ID of currently playing static sound
var _prev_sensor_state := true # Previous sensor functional state

func _init() -> void:
	super._init()
	gauge_id = GaugeType.RADAR
	draw_centered = true # Radar is drawn centered

func _ready() -> void:
	super._ready()
	_calc_bright_range_timer = Time.get_ticks_msec()

# Convert world position to radar position
func world_to_radar(world_pos: Vector3, player_pos: Vector3, player_forward: Vector3, player_up: Vector3) -> Vector2:
	# Get relative position
	var rel_pos = world_pos - player_pos
	
	# Get right vector
	var right = player_forward.cross(player_up)
	
	# Project onto player's horizontal plane
	var x = rel_pos.dot(right)
	var y = rel_pos.dot(player_forward)
	
	# Scale by current range
	var radar_range = RADAR_RANGES[current_range]
	x = (x / radar_range) * radius
	y = (y / radar_range) * radius
	
	return Vector2(x, y)

# Add object to radar
func add_radar_object(pos: Vector3, type: BlipType, team: int, targeted: bool = false) -> RadarBlip:
	var blip = RadarBlip.new(pos, type, team, targeted)
	
	# Set color based on type and team
	if type == BlipType.WARPING_SHIP:
		blip.color = Color(0.5, 0.5, 0.5) # Gray for warping
	elif type == BlipType.TAGGED_SHIP:
		blip.color = Color(1.0, 0.75, 0.0) # Gold for tagged
	elif type == BlipType.NAVBUOY_CARGO:
		blip.color = Color(0.0, 0.75, 1.0) # Cyan for navbuoys/cargo
	elif type == BlipType.BOMB:
		blip.color = Color(1.0, 0.0, 0.0) # Red for bombs
	elif type == BlipType.JUMP_NODE:
		blip.color = Color(0.5, 0.5, 1.0) # Blue for jump nodes
	else:
		# Normal ships - color based on IFF
		if team == GameState.player_ship.team:
			blip.color = Color(0.0, 1.0, 0.0) # Green for friendly
		else:
			blip.color = Color(1.0, 0.0, 0.0) # Red for hostile
	
	_radar_objects.append(blip)
	queue_redraw()
	return blip

# Clear all radar objects
func clear_radar_objects() -> void:
	_radar_objects.clear()
	queue_redraw()

# Update radar from current game state
func update_from_game_state() -> void:
	clear_radar_objects()
	
	if !GameState.player_ship:
		return
		
	# Update bright range periodically
	var current_time = Time.get_ticks_msec()
	if current_time - _calc_bright_range_timer > 1000:
		_calc_bright_range_timer = current_time
		# TODO: Calculate based on equipped weapons
		_bright_range = 1500.0
	
	# Add nearby ships
	for ship in get_tree().get_nodes_in_group("ships"):
		if ship == GameState.player_ship:
			continue
			
		var distance = ship.global_position.distance_to(GameState.player_ship.global_position)
		if distance <= RADAR_RANGES[current_range]:
			var blip_type = BlipType.NORMAL_SHIP
			
			# Determine blip type
			if ship.is_warping:
				blip_type = BlipType.WARPING_SHIP
			elif ship.is_tagged:
				blip_type = BlipType.TAGGED_SHIP
			elif ship.is_cargo or ship.is_navbuoy:
				blip_type = BlipType.NAVBUOY_CARGO
			elif ship.is_bomb:
				blip_type = BlipType.BOMB
				
			var blip = add_radar_object(
				ship.global_position,
				blip_type,
				ship.team,
				ship == GameState.player_ship.target
			)
			
			# Check for sensor distortion
			if ship.hidden_from_sensors or ship.awacs_level < 1.0:
				blip.is_distorted = true
	
	# Add missiles if enabled
	if show_friendly_missiles || show_hostile_missiles:
		for missile in get_tree().get_nodes_in_group("missiles"):
			var team_matches = (
				(show_friendly_missiles && missile.team == GameState.player_ship.team) ||
				(show_hostile_missiles && missile.team != GameState.player_ship.team)
			)
			if team_matches:
				var distance = missile.global_position.distance_to(GameState.player_ship.global_position)
				if distance <= RADAR_RANGES[current_range]:
					add_radar_object(
						missile.global_position,
						BlipType.BOMB,
						missile.team,
						false
					)

func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var color = get_current_color()
	var center = Vector2(radius + 10, radius + 10)
	
	# Get sensor strength
	var sensor_strength = 1.0
	if GameState.player_ship:
		sensor_strength = GameState.player_ship.get_sensor_strength()
	
	# Check if radar is functional
	if sensor_strength < min_sensor_strength && !Engine.is_editor_hint():
		# Draw static when radar is non-functional
		_draw_static_effect(center, color)
		return
		
	# Draw radar rings
	for i in range(num_rings):
		var ring_radius = (i + 1) * ring_spacing
		if ring_radius > radius:
			break
		draw_arc(center, ring_radius, 0, TAU, 32, Color(color, 0.2))
	
	# Draw radar boundary
	draw_arc(center, radius, 0, TAU, 32, color)
	
	# Draw crosshairs
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(color, 0.2))
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(color, 0.2))
	
	# Draw range indicator
	_draw_range_indicator(center, color)
	
	# Draw radar objects
	if Engine.is_editor_hint():
		# Draw some sample blips for preview
		_draw_sample_blips(center, color)
	else:
		_draw_radar_objects(center)
		
	# Draw noise effect if sensors are degraded
	if sensor_strength < sensor_noise_threshold:
		var noise_intensity = (sensor_noise_threshold - sensor_strength) / sensor_noise_threshold
		_draw_noise_effect(center, color, noise_intensity)

# Draw range indicator with current range setting
func _draw_range_indicator(center: Vector2, color: Color) -> void:
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	
	# Draw range text
	var range_text = "%.1fk" % (RADAR_RANGES[current_range] / 1000.0)
	
	# Draw background box
	var text_size = font.get_string_size(range_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var box_rect = Rect2(
		center + Vector2(radius + 5, -radius - range_indicator_size.y/2),
		Vector2(range_indicator_size.x, range_indicator_size.y)
	)
	draw_rect(box_rect, Color(0, 0, 0, 0.5))
	draw_rect(box_rect, color, false)
	
	# Draw text centered in box
	var text_pos = box_rect.position + Vector2(box_rect.size.x/2, box_rect.size.y/2 + font_size/3)
	draw_string(font, text_pos, range_text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

# Draw static effect when radar is non-functional
func _draw_static_effect(center: Vector2, color: Color) -> void:
	var static_color = Color(color)
	static_color.a *= static_effect_intensity
	
	for i in range(20):
		var angle = randf() * TAU
		var length = randf_range(radius * 0.2, radius)
		var start_pos = center + Vector2.from_angle(angle) * (radius - length)
		var end_pos = start_pos + Vector2.from_angle(angle) * length
		draw_line(start_pos, end_pos, static_color)

# Draw noise effect for degraded sensors
func _draw_noise_effect(center: Vector2, color: Color, intensity: float) -> void:
	var noise_color = Color(color)
	noise_color.a *= intensity * 0.5
	
	for i in range(10):
		var angle = randf() * TAU
		var dist = randf_range(0, radius)
		var pos = center + Vector2.from_angle(angle) * dist
		draw_circle(pos, randf_range(1, 3), noise_color)

# Draw actual radar objects
func _draw_radar_objects(center: Vector2) -> void:
	if !GameState.player_ship:
		return
		
	var player_pos = GameState.player_ship.global_position
	var player_forward = GameState.player_ship.global_transform.basis.z
	var player_up = GameState.player_ship.global_transform.basis.y
	
	# Sort blips by distance
	var sorted_blips = _radar_objects.duplicate()
	sorted_blips.sort_custom(func(a, b): 
		return a.position.distance_to(player_pos) < b.position.distance_to(player_pos)
	)
	
	for blip in sorted_blips:
		var radar_pos = world_to_radar(blip.position, player_pos, player_forward, player_up)
		var distance = blip.position.distance_to(player_pos)
		var is_bright = distance <= _bright_range
		
		# Get blip color and handle flashing
		var blip_color = blip.color
		if blip.is_targeted:
			blip_color = Color.GREEN
			is_bright = true
		
		if is_bright:
			blip_color.a = 1.0
		else:
			blip_color.a = 0.5
			
		if blip.is_distorted:
			if _flash_state:
				# Apply distortion
				var distort_angle = sensor_distortion_angle
				if GameState.player_ship.emp_active:
					distort_angle *= randf_range(1.0, 3.0)
				var distorted_pos = radar_pos.rotated(randf_range(-distort_angle, distort_angle))
				radar_pos = distorted_pos
		
		# Draw blip
		if blip.is_targeted:
			# Draw targeting box
			var box_size = blip_size * 3
			draw_rect(Rect2(center + radar_pos - Vector2(box_size/2, box_size/2),
				Vector2(box_size, box_size)), blip_color, false)
		else:
			# Draw regular blip
			draw_circle(center + radar_pos, blip_size, blip_color)

# Draw sample blips for editor preview
func _draw_sample_blips(center: Vector2, color: Color) -> void:
	# Draw some sample blips at different positions
	var positions = [
		Vector2(20, 0),   # Right
		Vector2(-15, 25), # Back left
		Vector2(0, -30),  # Front
	]
	
	for pos in positions:
		draw_circle(center + pos, blip_size, color)
	
	# Draw one targeted blip
	var box_size = blip_size * 3
	draw_rect(Rect2(center + Vector2(25, 25) - Vector2(box_size/2, box_size/2),
		Vector2(box_size, box_size)), color, false)

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
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
