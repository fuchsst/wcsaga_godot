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

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(150, 150)

# Radar objects
class RadarObject:
	var position: Vector3
	var type: int  # Ship, missile, etc
	var team: int
	var is_targeted: bool
	
	func _init(pos: Vector3, obj_type: int, obj_team: int, targeted: bool = false) -> void:
		position = pos
		type = obj_type
		team = team
		is_targeted = targeted

var radar_objects: Array[RadarObject] = []

func _init() -> void:
	super._init()
	gauge_id = HUDGauge.RADAR

func _ready() -> void:
	super._ready()

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
	var range = RADAR_RANGES[current_range]
	x = (x / range) * radius
	y = (y / range) * radius
	
	return Vector2(x, y)

# Add object to radar
func add_radar_object(pos: Vector3, type: int, team: int, targeted: bool = false) -> void:
	radar_objects.append(RadarObject.new(pos, type, team, targeted))
	queue_redraw()

# Clear all radar objects
func clear_radar_objects() -> void:
	radar_objects.clear()
	queue_redraw()

# Update radar from current game state
func update_from_game_state(player_ship: PlayerShip) -> void:
	# TODO: Get nearby objects from game state
	# This would:
	# 1. Clear current objects
	# 2. Get player position/orientation
	# 3. Find nearby ships/objects
	# 4. Add them to radar
	pass

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var color = get_current_color()
	var center = Vector2(radius + 10, radius + 10)
	
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
	
	# Draw range text
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var range_text = "%.1fk" % (RADAR_RANGES[current_range] / 1000.0)
	draw_string(font, center + Vector2(radius + 5, -radius), range_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	
	# Draw radar objects
	if Engine.is_editor_hint():
		# Draw some sample blips for preview
		_draw_sample_blips(center, color)
	else:
		_draw_radar_objects(center, color)

# Draw actual radar objects
func _draw_radar_objects(center: Vector2, color: Color) -> void:
	for obj in radar_objects:
		# TODO: Convert world position to radar position
		# var radar_pos = world_to_radar(obj.position, player_pos, player_forward, player_up)
		var radar_pos = Vector2.ZERO # Temporary
		
		# Get object color based on type/team
		var obj_color = color # TODO: Get proper color based on type/team
		
		# Draw blip
		if obj.is_targeted:
			# Draw targeting box
			var box_size = blip_size * 3
			draw_rect(Rect2(center + radar_pos - Vector2(box_size/2, box_size/2),
				Vector2(box_size, box_size)), obj_color, false)
		else:
			# Draw regular blip
			draw_circle(center + radar_pos, blip_size, obj_color)

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
