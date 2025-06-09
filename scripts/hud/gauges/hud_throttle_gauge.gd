@tool
extends HUDGauge
class_name HUDThrottleGauge

# Throttle settings
@export_group("Throttle Settings")
@export var current_speed: float = 0.0:
	set(value):
		current_speed = value
		queue_redraw()
@export var max_speed: float = 100.0:
	set(value):
		max_speed = value
		queue_redraw()
@export var current_throttle: float = 0.0:
	set(value):
		current_throttle = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var afterburner_active: bool = false:
	set(value):
		afterburner_active = value
		if value:
			start_flash()
		else:
			stop_flash()
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var bar_width: int = 15
@export var bar_height: int = 100
@export var tick_width: int = 5
@export var num_ticks: int = 10
@export var speed_text_offset := Vector2(20, 10)
@export var afterburner_indicator_size := Vector2(15, 10)

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(100, 150)

func _init() -> void:
	super._init()
	gauge_id = GaugeType.THROTTLE_GAUGE

func _ready() -> void:
	super._ready()
	# Don't reset here, let update_from_game_state set initial values
	# reset_to_defaults()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship exists
	if GameStateManager.player_ship and is_instance_valid(GameStateManager.player_ship):
		var ship = GameStateManager.player_ship

		# Read speed, throttle, and status flags from ShipBase
		# Assuming these properties/methods exist
		current_speed = ship.linear_velocity.length() # Get current speed magnitude
		max_speed = ship.current_max_speed # Get current max speed (might change with ETS)
		current_throttle = ship.get_throttle_input() # Placeholder: Need method/property for desired throttle (0-1)
		afterburner_active = (ship.physics_flags & WCSConstants.PF_AFTERBURNER_ON) != 0

		# Glide and Match Speed status are checked directly in _draw() using GameState.player_ship
		# No need to store them as separate gauge properties unless needed elsewhere.

	else:
		# Default state if no player ship
		reset_to_defaults() # Use reset function for default state

# Reset energy distribution to default values
func reset_to_defaults() -> void:
	current_throttle = 0.5 # 50% throttle
	current_speed = 0.0
	max_speed = 100.0
	afterburner_active = false

# Set the current throttle level (0.0 to 1.0)
func set_throttle(level: float) -> void:
	current_throttle = clampf(level, 0.0, 1.0)

# Set the current speed
func set_speed(speed: float, max_spd: float) -> void:
	current_speed = speed
	max_speed = max_spd

# Set afterburner state
func set_afterburner(active: bool) -> void:
	if active != afterburner_active:
		afterburner_active = active
		if active:
			start_flash()
		else:
			stop_flash()

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var color = get_current_color()
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	
	# Draw speed text
	var speed_text = "%d/%d" % [round(current_speed), round(max_speed)]
	draw_string(font, speed_text_offset, speed_text, 
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	
	# Draw throttle bar background
	var bar_rect = Rect2(0, font_size + 10, bar_width, bar_height)
	draw_rect(bar_rect, Color(color, 0.2))
	
	# Draw throttle level
	var level_height = bar_height * current_throttle
	var level_rect = Rect2(0, bar_rect.position.y + (bar_height - level_height),
		bar_width, level_height)
	draw_rect(level_rect, color)
	
	# Draw tick marks
	if num_ticks > 0:
		var tick_spacing = bar_height / (num_ticks - 1)
		for i in range(num_ticks):
			var y = bar_rect.position.y + (i * tick_spacing)
			draw_line(Vector2(bar_width, y), 
				Vector2(bar_width + tick_width, y), color)
	
	# Draw afterburner indicator
	if afterburner_active:
		var ab_width = afterburner_indicator_size.x
		var ab_height = afterburner_indicator_size.y
		var ab_y = bar_rect.position.y + (bar_height - level_height) - ab_height/2
		
		# Draw afterburner triangle
		var points = PackedVector2Array([
			Vector2(bar_width + tick_width + 2, ab_y),
			Vector2(bar_width + tick_width + 2 + ab_width, ab_y + ab_height/2),
			Vector2(bar_width + tick_width + 2, ab_y + ab_height)
		])
		
		# Flash the afterburner indicator
		var ab_color = color
		if is_flashing:
			ab_color = bright_color if is_bright else dim_color
		draw_colored_polygon(points, ab_color)
	
	# Draw glide/match speed indicators
	var player_ship = ObjectManager.get_player_ship() if ObjectManager else null
	if player_ship:
		var y_offset = font_size + 2
		var x_offset = -31 if current_speed <= 9.5 else (-22 if current_speed <= 99.5 else -13)
		
		# Check glide status
		var physics_flags = player_ship.get("physics_flags", 0) if player_ship.has_method("get") else 0
		var gliding_flag = WCSConstants.PF_GLIDING if WCSConstants and WCSConstants.has_property("PF_GLIDING") else 0
		if physics_flags & gliding_flag:
			draw_string(font, Vector2(x_offset, bar_rect.position.y + bar_height + y_offset),
				"GLIDE", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		# Check match speed status
		elif player_ship.get("match_target_speed", false) if player_ship.has_method("get") else false:
			draw_string(font, Vector2(x_offset, bar_rect.position.y + bar_height + y_offset),
				"MATCH", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

# Update the gauge with current ship state (Keep for potential direct calls?)
# func update_from_game_state() -> void: # This is now the main update function
#	 if !GameState.player_ship:
#		 return
#
#	 var ship = GameState.player_ship
#	 current_speed = ship.current_speed
#	 max_speed = ship.max_speed
#	 current_throttle = ship.throttle
#	 afterburner_active = ship.afterburner_active
