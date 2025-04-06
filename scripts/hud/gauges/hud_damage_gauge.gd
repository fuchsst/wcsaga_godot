@tool
extends HUDGauge
class_name HUDDamageGauge


# Damage settings
@export_group("Damage Settings")
@export var hull_integrity: float = 1.0:
	set(value):
		var old_value = hull_integrity
		hull_integrity = clampf(value, 0.0, 1.0)
		if hull_integrity < old_value:
			_hull_damage_flash_time = flash_duration
		queue_redraw()
@export var subsystems: Array[Subsystem]:
	set(value):
		subsystems = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(300, 200)
@export var subsystem_spacing := 20
@export var health_bar_width := 100
@export var health_bar_height := 8
@export var flash_rate := 0.1
@export var warning_flash_rate := 0.5

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(350, 250)

# Damage tracking
var _hull_damage_flash_time := 0.0
var _flash_time := 0.0
var _flash_state := false
var _warning_flash_time := 0.0
var _warning_flash_state := false

func _init() -> void:
	super._init()
	if flash_duration == 0:
		flash_duration = 0.5
	gauge_id = GaugeType.DAMAGE_GAUGE

func _ready() -> void:
	super._ready()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship and its damage system exist
	if GameState.player_ship and is_instance_valid(GameState.player_ship) and GameState.player_ship.damage_system:
		var damage_sys: DamageSystem = GameState.player_ship.damage_system

		# Update hull integrity
		# Assuming hull_strength is directly on ShipBase for easier access
		hull_integrity = GameState.player_ship.hull_strength / GameState.player_ship.ship_max_hull_strength

		# Update subsystems
		# This requires DamageSystem to provide a way to get current subsystem states
		# Option 1: DamageSystem provides a list of subsystem status dictionaries/objects
		# Option 2: Iterate through ShipBase's subsystem nodes and get their status

		# Using Option 2 for now (assuming subsystems are children with ShipSubsystem script)
		var current_subsystems_data = []
		var ship_subsystems = GameState.player_ship.get_subsystems() # Assuming ShipBase has this helper

		for subsys_node in ship_subsystems:
			if subsys_node is ShipSubsystem and is_instance_valid(subsys_node.subsystem_definition):
				var subsys: ShipSubsystem = subsys_node
				var subsys_def = subsys.subsystem_definition
				# Create a new Subsystem data object for the gauge
				var gauge_subsys = Subsystem.new(
					subsys_def.type,
					subsys_def.subobj_name, # Or use ship_subsys_get_name(subsys)?
					subsys.current_hits, # Use current hits
					subsys_def.max_hits, # Pass max hits
					subsys_def.is_critical # Pass critical flag
				)
				# Copy flash state if needed (or handle flash purely in gauge)
				# gauge_subsys.damage_flash_time = subsys.get_damage_flash_time_remaining() # Needs method on ShipSubsystem
				current_subsystems_data.append(gauge_subsys)

		# Update the gauge's subsystems array (setter handles redraw)
		subsystems = current_subsystems_data

	else:
		# Default state if no player ship or damage system
		hull_integrity = 1.0
		subsystems = []


# --- Subsystem Inner Class ---
# Represents subsystem data specifically for this gauge's display needs
class Subsystem:
	enum Type { # Mirror GlobalConstants.SubsystemType if possible
		ENGINES, WEAPONS, SHIELDS, SENSORS, NAVIGATION, COMMUNICATION, WARPDRIVE, TURRET, OTHER
	}
	var type: Type
	var name: String
	var health: float # Current health points
	var max_health: float # Maximum health points
	var is_critical: bool
	var damage_flash_time: float = 0.0 # For tracking flash state within the gauge

	func _init(p_type: Type, p_name: String, p_health: float = 100.0, p_max_health: float = 100.0, p_critical: bool = false):
		type = p_type
		name = p_name
		health = p_health
		max_health = max(1.0, p_max_health) # Ensure max_health is at least 1
		is_critical = p_critical
# --- End Subsystem Inner Class ---


# Add a subsystem
func add_subsystem(type: Subsystem.Type, name: String, health: float = 100.0, max_health: float = 100.0,
	critical: bool = false) -> void:
	# This method might become obsolete if update_from_game_state replaces it,
	# but keep it for potential manual testing or specific scenarios.
	var sys = Subsystem.new(type, name, health, max_health, critical)
	subsystems.append(sys)
	queue_redraw()

# Update subsystem health
func update_subsystem_health(index: int, health: float) -> void:
	# This method might become obsolete if update_from_game_state replaces it.
	if index >= 0 && index < subsystems.size():
		var sys = subsystems[index]
		if health < sys.health: # Trigger flash only if health decreased
			sys.damage_flash_time = flash_duration
		# Clamp health between 0 and the subsystem's max_health
		sys.health = clampf(health, 0.0, sys.max_health)
		queue_redraw()

# Clear all subsystems
func clear_subsystems() -> void:
	subsystems.clear()
	queue_redraw()

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample subsystems for preview
		if subsystems.is_empty():
			subsystems = [
				Subsystem.new(Subsystem.Type.ENGINES, "Engines", 75.0, true),
				Subsystem.new(Subsystem.Type.WEAPONS, "Weapons", 100.0),
				Subsystem.new(Subsystem.Type.SHIELDS, "Shields", 50.0),
				Subsystem.new(Subsystem.Type.SENSORS, "Sensors", 25.0, true)
			]
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var x = 10
	var y = line_height
	
	# Draw hull integrity
	draw_string(font, Vector2(x, y), "HULL INTEGRITY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_current_color())
	y += line_height
	
	# Draw hull integrity bar
	var hull_color = _get_health_color(hull_integrity)
	if _hull_damage_flash_time > 0 && _flash_state:
		hull_color = Color.RED
	
	var hull_bg_rect = Rect2(x, y, health_bar_width, health_bar_height)
	draw_rect(hull_bg_rect, Color(hull_color, 0.2))
	
	var hull_fill_rect = Rect2(x, y, health_bar_width * hull_integrity, health_bar_height)
	draw_rect(hull_fill_rect, hull_color)
	
	# Draw hull percentage
	var hull_text = "%d%%" % (hull_integrity * 100)
	draw_string(font, Vector2(x + health_bar_width + 10, y + health_bar_height/2),
		hull_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, hull_color)
	
	y += health_bar_height + line_height * 2
	
	# Draw subsystems
	draw_string(font, Vector2(x, y), "SUBSYSTEMS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_current_color())
	y += line_height
	
	for sys in subsystems:
		var sys_color = _get_health_color(sys.health / sys.max_health)
		
		# Handle damage flash
		if sys.damage_flash_time > 0 && _flash_state:
			sys_color = Color.RED
		
		# Handle critical warning flash
		if sys.is_critical && sys.health / sys.max_health < 0.25:
			if _warning_flash_state:
				sys_color = Color.RED
		
		# Draw system name
		draw_string(font, Vector2(x, y + health_bar_height/2),
			sys.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, sys_color)
		
		# Draw health bar
		var bar_x = x + 100
		var sys_bg_rect = Rect2(bar_x, y, health_bar_width, health_bar_height)
		draw_rect(sys_bg_rect, Color(sys_color, 0.2))
		
		var health_ratio = sys.health / sys.max_health
		var sys_fill_rect = Rect2(bar_x, y, health_bar_width * health_ratio, health_bar_height)
		draw_rect(sys_fill_rect, sys_color)
		
		# Draw health percentage
		var sys_text = "%d%%" % (health_ratio * 100)
		draw_string(font, Vector2(bar_x + health_bar_width + 10, y + health_bar_height/2),
			sys_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, sys_color)
		
		y += subsystem_spacing

# Get color based on health percentage
func _get_health_color(health_ratio: float) -> Color:
	if health_ratio <= 0.25:
		return Color.RED
	elif health_ratio <= 0.5:
		return Color.ORANGE
	elif health_ratio <= 0.75:
		return Color.YELLOW
	else:
		return Color.GREEN

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update hull damage flash
	if _hull_damage_flash_time > 0:
		_hull_damage_flash_time -= delta
		needs_redraw = true
	
	# Update subsystem damage flash
	for sys in subsystems:
		if sys.damage_flash_time > 0:
			sys.damage_flash_time -= delta
			needs_redraw = true
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		needs_redraw = true
	
	# Update warning flash state
	_warning_flash_time += delta
	if _warning_flash_time >= warning_flash_rate:
		_warning_flash_time = 0.0
		_warning_flash_state = !_warning_flash_state
		needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
