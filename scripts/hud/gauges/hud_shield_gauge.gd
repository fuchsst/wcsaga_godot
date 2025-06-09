@tool
extends HUDGauge
class_name HUDShieldGauge

# Shield quadrant indices
enum ShieldQuadrant {
	FRONT = 0,
	RIGHT = 1,
	BACK = 2,
	LEFT = 3,
	TOP = 4,
	BOTTOM = 5
}

# Shield settings
@export_group("Shield Settings")
@export var is_player_gauge: bool = true:
	set(value):
		is_player_gauge = value
		queue_redraw()
@export var shield_strength: Array[float] = [1.0, 1.0, 1.0, 1.0]:
	set(value):
		shield_strength = value
		queue_redraw()
@export var max_shield_strength: float = 100.0:
	set(value):
		max_shield_strength = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var radius: float = 40.0
@export var quadrant_gap: float = 2.0
@export var hit_flash_duration: float = 0.5
@export var hit_flash_interval: float = 0.1

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(100, 100)

# Hit flash tracking
var quadrant_hit_times: Array[float] = [0.0, 0.0, 0.0, 0.0]
var quadrant_flash_states: Array[bool] = [false, false, false, false]

func _init() -> void:
	super._init()
	gauge_id = GaugeType.PLAYER_SHIELD_ICON if is_player_gauge else GaugeType.TARGET_SHIELD_ICON

func _ready() -> void:
	super._ready()

# Update gauge based on current game state
func update_from_game_state() -> void:
	var target_ship: BaseShip = null
	var target_shield_system: ShieldQuadrantManager = null

	if is_player_gauge:
		# Get player ship data
		if GameStateManager.player_ship and is_instance_valid(GameStateManager.player_ship):
			target_ship = GameStateManager.player_ship
			target_shield_system = target_ship.shield_system
	else:
		# Get target ship data
		if GameStateManager.player_ship and is_instance_valid(GameStateManager.player_ship) and GameStateManager.player_ship.target_object_id != -1:
			var target_node = ObjectManager.get_object_by_id(GameStateManager.player_ship.target_object_id)
			if target_node is BaseShip and is_instance_valid(target_node):
				target_ship = target_node
				target_shield_system = target_ship.shield_system

	# Update the gauge if we found a valid shield system
	if target_shield_system and is_instance_valid(target_shield_system):
		# Ensure the shield_strength array has the correct size
		if shield_strength.size() != target_shield_system.shield_quadrants.size():
			shield_strength.resize(target_shield_system.shield_quadrants.size())

		# Check if update is needed to avoid unnecessary redraws
		var needs_update = false
		if abs(max_shield_strength - target_shield_system.max_shield_strength) > 0.01:
			needs_update = true
		else:
			for i in range(shield_strength.size()):
				if abs(shield_strength[i] - target_shield_system.shield_quadrants[i]) > 0.01:
					needs_update = true
					break

		if needs_update:
			update_shields(target_shield_system.shield_quadrants, target_shield_system.max_shield_strength)
	else:
		# No valid target or shield system, clear the gauge? Or show empty state?
		# For now, let's just ensure it doesn't crash and shows default (likely full or empty based on init)
		# If the gauge should be hidden when no target, that logic belongs in HUD.gd
		# We can ensure the gauge shows 0 strength if no valid target.
		if not shield_strength.is_empty() and shield_strength[0] != 0.0: # Check if already zero
			var zero_shields = []
			zero_shields.resize(shield_strength.size())
			zero_shields.fill(0.0)
			update_shields(zero_shields, 100.0) # Use default max strength

# Register a hit on a shield quadrant
func register_hit(quadrant: ShieldQuadrant, damage: float = 0.0) -> void:
	if quadrant < 0 || quadrant >= shield_strength.size():
		return
		
	# Update shield strength
	if damage > 0:
		shield_strength[quadrant] = maxf(0.0, shield_strength[quadrant] - damage/max_shield_strength)
	
	# Start flash effect
	quadrant_hit_times[quadrant] = Time.get_ticks_msec() / 1000.0
	quadrant_flash_states[quadrant] = true
	queue_redraw()

# Update shield strengths
func update_shields(strengths: Array[float], max_strength: float) -> void:
	max_shield_strength = max_strength
	shield_strength = strengths.duplicate()
	queue_redraw()

# Draw shield arc
func draw_shield_arc(center: Vector2, inner_radius: float, outer_radius: float, 
	start_angle: float, end_angle: float, color: Color, num_points: int = 16) -> void:
	
	var points = PackedVector2Array()
	var angle_step = (end_angle - start_angle) / (num_points - 1)
	
	# Generate outer arc points
	for i in range(num_points):
		var angle = start_angle + i * angle_step
		points.push_back(center + Vector2(
			cos(angle) * outer_radius,
			sin(angle) * outer_radius
		))
	
	# Generate inner arc points (in reverse)
	for i in range(num_points - 1, -1, -1):
		var angle = start_angle + i * angle_step
		points.push_back(center + Vector2(
			cos(angle) * inner_radius,
			sin(angle) * inner_radius
		))
	
	# Draw filled polygon
	draw_colored_polygon(points, color)

func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var color = get_current_color()
	var center = Vector2(radius + 10, radius + 10)
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Draw shield quadrants
	for i in range(shield_strength.size()):
		var start_angle = i * PI/2 - PI/4
		var end_angle = start_angle + PI/2 - quadrant_gap
		
		# Check if quadrant is flashing
		var quadrant_color = color
		if quadrant_hit_times[i] > 0:
			var elapsed = current_time - quadrant_hit_times[i]
			if elapsed < hit_flash_duration:
				# Update flash state
				if elapsed > int(quadrant_flash_states[i]) * hit_flash_interval:
					quadrant_flash_states[i] = !quadrant_flash_states[i]
				# Set flash color
				quadrant_color = bright_color if quadrant_flash_states[i] else dim_color
			else:
				quadrant_hit_times[i] = 0.0
		
		# Draw shield quadrant background
		draw_shield_arc(center, radius - 5, radius, start_angle, end_angle, 
			Color(quadrant_color, 0.2))
		
		# Draw shield strength
		var strength_radius = radius - 5 + (5 * shield_strength[i])
		if shield_strength[i] > 0:
			draw_shield_arc(center, radius - 5, strength_radius,
				start_angle, end_angle, quadrant_color)

func _process(delta: float) -> void:
	super._process(delta)
	
	# Check for hit flash updates
	var needs_redraw = false
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for i in range(quadrant_hit_times.size()):
		if quadrant_hit_times[i] > 0:
			var elapsed = current_time - quadrant_hit_times[i]
			if elapsed < hit_flash_duration:
				if elapsed > int(quadrant_flash_states[i]) * hit_flash_interval:
					quadrant_flash_states[i] = !quadrant_flash_states[i]
					needs_redraw = true
			else:
				quadrant_hit_times[i] = 0.0
				needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
