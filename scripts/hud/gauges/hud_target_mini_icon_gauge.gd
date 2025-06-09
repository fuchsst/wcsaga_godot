@tool
extends HUDGauge
class_name HUDTargetMiniIconGauge

# Status settings
@export_group("Status Settings")
@export var icon_active := false:
	set(value):
		icon_active = value
		queue_redraw()
@export_range(0.0, 1.0) var hull_integrity := 1.0:
	set(value):
		hull_integrity = clampf(value, 0.0, 1.0)
		_update_status()
		queue_redraw()
@export_range(0.0, 1.0) var shield_integrity := 1.0:
	set(value):
		shield_integrity = clampf(value, 0.0, 1.0)
		_update_status()
		queue_redraw()

# Target settings
@export_group("Target Settings")
@export var is_friendly := false:
	set(value):
		is_friendly = value
		queue_redraw()
@export var has_shields := true:
	set(value):
		has_shields = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(60, 60)
@export var icon_size := 40.0
@export var shield_thickness := 3.0
@export var flash_rate := 0.2
@export var flash_critical := true
@export var critical_threshold := 0.25

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(80, 80)

# Status tracking
enum DamageStatus {
	GOOD,      # High integrity
	DAMAGED,   # Medium integrity
	CRITICAL   # Low integrity
}

var _hull_status: DamageStatus
var _shield_status: DamageStatus
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.TARGET_MINI_ICON

func _ready() -> void:
	super._ready()
	_update_status()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship and target exist
	if not GameStateManager.player_ship or not is_instance_valid(GameStateManager.player_ship) or GameStateManager.player_ship.target_object_id == -1:
		clear_target()
		return

	var target_node = ObjectManager.get_object_by_id(GameStateManager.player_ship.target_object_id)
	if not is_instance_valid(target_node) or not target_node is BaseShip:
		# Only show icon for ships
		clear_target()
		return

	var target_ship: BaseShip = target_node
	var target_shield_system: ShieldQuadrantManager = target_ship.shield_system

	# Get hull percentage
	var hull_pct = 0.0
	if target_ship.ship_max_hull_strength > 0:
		hull_pct = target_ship.hull_strength / target_ship.ship_max_hull_strength

	# Get shield percentage (average or overall?)
	# FS2 likely uses overall shield strength for the mini icon
	var shield_pct = 0.0
	var has_shield_system = is_instance_valid(target_shield_system) and not (target_ship.flags & WCSConstants.OF_NO_SHIELDS)
	if has_shield_system and target_shield_system.max_shield_strength > 0:
		shield_pct = target_shield_system.get_total_strength() / target_shield_system.max_shield_strength

	# Get friendliness
	var friendly = ObjectManager.is_friendly(GameStateManager.player_ship.team, target_ship.team) # Assuming IFFManager

	# Update the gauge
	show_target(hull_pct, shield_pct, friendly, has_shield_system)


# Show target status
func show_target(hull: float, shield: float, friendly: bool = false, has_shield: bool = true) -> void:
	icon_active = true
	hull_integrity = hull
	shield_integrity = shield
	is_friendly = friendly
	has_shields = has_shield
	queue_redraw()

# Clear target status
func clear_target() -> void:
	icon_active = false
	queue_redraw()

# Update damage status
func _update_status() -> void:
	# Update hull status
	if hull_integrity <= critical_threshold:
		_hull_status = DamageStatus.CRITICAL
	elif hull_integrity <= 0.5:
		_hull_status = DamageStatus.DAMAGED
	else:
		_hull_status = DamageStatus.GOOD
	
	# Update shield status
	if shield_integrity <= critical_threshold:
		_shield_status = DamageStatus.CRITICAL
	elif shield_integrity <= 0.5:
		_shield_status = DamageStatus.DAMAGED
	else:
		_shield_status = DamageStatus.GOOD

# Get color based on damage status
func _get_status_color(status: DamageStatus, base_color: Color) -> Color:
	var color = base_color
	
	match status:
		DamageStatus.GOOD:
			color = Color.GREEN if is_friendly else Color.RED
		DamageStatus.DAMAGED:
			color = Color.YELLOW
		DamageStatus.CRITICAL:
			color = Color.RED
			if flash_critical && _flash_state:
				color = Color.WHITE
	
	return color

# Draw hull icon
func _draw_hull_icon(pos: Vector2, size: float, color: Color) -> void:
	var half_size = size * 0.5
	var points = PackedVector2Array([
		pos + Vector2(0, -half_size),           # Top
		pos + Vector2(half_size, half_size),    # Bottom right
		pos + Vector2(-half_size, half_size)    # Bottom left
	])
	
	# Draw hull fill based on integrity
	var fill_points = points.duplicate()
	var fill_height = size * hull_integrity
	var base_y = pos.y + half_size - fill_height
	fill_points[0].y = base_y
	fill_points[1].y = pos.y + half_size
	fill_points[2].y = pos.y + half_size
	
	draw_colored_polygon(fill_points, Color(color, 0.3))
	draw_polyline(points, color, 2.0)

# Draw shield arc
func _draw_shield_arc(center: Vector2, radius: float, color: Color) -> void:
	var start_angle = -PI * 0.8
	var end_angle = PI * 0.8
	var total_angle = end_angle - start_angle
	var shield_angle = total_angle * shield_integrity
	
	if shield_integrity > 0:
		draw_arc(center, radius, start_angle, start_angle + shield_angle, 32,
			color, shield_thickness)
	
	# Draw remaining arc outline
	if shield_integrity < 1.0:
		draw_arc(center, radius, start_angle + shield_angle, end_angle, 32,
			color, shield_thickness, true)

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample status for preview
		if !icon_active:
			show_target(0.7, 0.3)
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	if !icon_active:
		return
		
	var size = gauge_size
	if Engine.is_editor_hint():
		size = preview_size
	
	var center = size * 0.5
	var base_color = get_current_color()
	
	# Draw hull icon
	var hull_color = _get_status_color(_hull_status, base_color)
	_draw_hull_icon(center, icon_size, hull_color)
	
	# Draw shield arc if available
	if has_shields:
		var shield_color = _get_status_color(_shield_status, base_color)
		_draw_shield_arc(center, icon_size * 0.7, shield_color)

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		if icon_active && flash_critical && (_hull_status == DamageStatus.CRITICAL || _shield_status == DamageStatus.CRITICAL):
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
