@tool
extends HUDGauge
class_name HUDETSGauge

# Energy level constants
const NUM_ENERGY_LEVELS = 13
const MAX_ENERGY_INDEX = NUM_ENERGY_LEVELS - 1

# Default indices
const ZERO_INDEX = 0
const ONE_THIRD_INDEX = 4  
const ONE_HALF_INDEX = 6
const ALL_INDEX = 12

# System flags
const HAS_ENGINES = 1 << 0
const HAS_SHIELDS = 1 << 1
const HAS_WEAPONS = 1 << 2

# Energy levels array matching original
var energy_levels = [
	0.0,      # 0
	0.0833,   # 1/12
	0.167,    # 2/12
	0.25,     # 3/12
	0.333,    # 4/12
	0.417,    # 5/12
	0.5,      # 6/12
	0.583,    # 7/12
	0.667,    # 8/12
	0.75,     # 9/12
	0.833,    # 10/12
	0.9167,   # 11/12
	1.0       # 12/12
]

# Current energy indices
@export var weapon_index: int = ONE_HALF_INDEX:
	set(value):
		weapon_index = value
		queue_redraw()
@export var shield_index: int = ONE_HALF_INDEX:
	set(value):
		shield_index = value
		queue_redraw()
@export var engine_index: int = ONE_HALF_INDEX:
	set(value):
		engine_index = value
		queue_redraw()

# Bar dimensions
@export var bar_height: int = 41  # Matches original HUD_bar_h
@export var bar_width: int = 15
@export var bar_spacing: int = 25

# System availability
@export var has_weapons: bool = true:
	set(value):
		has_weapons = value
		queue_redraw()
@export var has_shields: bool = true:
	set(value):
		has_shields = value
		queue_redraw()
@export var has_engines: bool = true:
	set(value):
		has_engines = value
		queue_redraw()

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(100, 150)

func _init() -> void:
	super._init()
	gauge_id = GaugeType.ETS_GAUGE

func _ready() -> void:
	super._ready()
	# Don't reset here, let update_from_game_state set initial values
	# reset_to_defaults()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship exists using GameStateManager singleton
	if GameStateManager.player_ship and is_instance_valid(GameStateManager.player_ship):
		var ship = GameStateManager.player_ship

		# Read ETS indices from BaseShip
		weapon_index = ship.weapon_recharge_index # Setter handles redraw
		shield_index = ship.shield_recharge_index # Setter handles redraw
		engine_index = ship.engine_recharge_index # Setter handles redraw

		# Read system availability
		# Check if there are primary banks AND if at least one uses energy
		var energy_weapon_exists = false
		if ship.weapon_system and ship.weapon_system.num_primary_banks > 0:
			for wpn_idx in ship.weapon_system.primary_bank_weapons:
				if wpn_idx >= 0:
					var wpn_data: WeaponData = WCSConstants.get_weapon_data(wpn_idx)
					if wpn_data and not (wpn_data.flags2 & WCSConstants.WIF2_BALLISTIC):
						energy_weapon_exists = true
						break
		has_weapons = energy_weapon_exists

		has_shields = not (ship.flags & WCSConstants.OF_NO_SHIELDS)

		# Check if engine system exists and ship has max speed > 0
		has_engines = is_instance_valid(ship.engine_system) and ship.ship_data and ship.ship_data.max_vel.z > 0.01

	else:
		# Default state if no player ship
		weapon_index = ONE_HALF_INDEX
		shield_index = ONE_HALF_INDEX
		engine_index = ONE_HALF_INDEX
		has_weapons = true
		has_shields = true
		has_engines = true

# Reset energy distribution to default values
func reset_to_defaults() -> void:
	weapon_index = ONE_HALF_INDEX
	shield_index = ONE_HALF_INDEX
	engine_index = ONE_HALF_INDEX

# Set which systems are available
func set_available_systems(weapons: bool, shields: bool, engines: bool) -> void:
	has_weapons = weapons
	has_shields = shields
	has_engines = engines
	
	# Redistribute energy based on available systems
	var total_systems = 0
	if has_weapons:
		total_systems += 1
	if has_shields:
		total_systems += 1
	if has_engines:
		total_systems += 1
		
	if total_systems == 0:
		return
		
	var energy_per_system = ALL_INDEX / total_systems
	
	if has_weapons:
		weapon_index = energy_per_system
	else:
		weapon_index = 0
		
	if has_shields:
		shield_index = energy_per_system
	else:
		shield_index = 0
		
	if has_engines:
		engine_index = energy_per_system
	else:
		engine_index = 0

# Increase energy to a system
# NOTE: This function currently modifies the gauge's state directly.
# Ideally, it should send a request to the BaseShip/EnergyTransferSystem
# to change the energy distribution, and the gauge would update via
# update_from_game_state().
func increase_system(system: String) -> void:
	# TODO: Refactor - Send signal/call to BaseShip instead of direct modification.
	# Example: ship_base.request_increase_ets(system)

	var index_ref = _get_system_index_ref(system)
	if index_ref == null:
		return
		
	# Check if already at max
	if index_ref.value >= MAX_ENERGY_INDEX:
		return
		
	# Calculate how much we can increase
	var increase = min(2, MAX_ENERGY_INDEX - index_ref.value)
	if increase <= 0:
		return
		
	# Take energy from other systems
	var other_systems = _get_other_systems(system)
	var energy_per_system = increase / other_systems.size()
	
	for other in other_systems:
		var other_ref = _get_system_index_ref(other)
		if other_ref == null:
			continue
		if other_ref.value <= 0:
			continue
			
		var decrease = min(energy_per_system, other_ref.value)
		other_ref.value -= decrease
		index_ref.value += decrease
		
	start_flash()

# Decrease energy from a system
# NOTE: This function currently modifies the gauge's state directly.
# Ideally, it should send a request to the BaseShip/EnergyTransferSystem
# to change the energy distribution, and the gauge would update via
# update_from_game_state().
func decrease_system(system: String) -> void:
	# TODO: Refactor - Send signal/call to BaseShip instead of direct modification.
	# Example: ship_base.request_decrease_ets(system)

	var index_ref = _get_system_index_ref(system)
	if index_ref == null:
		return
		
	# Check if already at min
	if index_ref.value <= 0:
		return
		
	# Calculate how much we can decrease
	var decrease = min(2, index_ref.value)
	if decrease <= 0:
		return
		
	# Give energy to other systems
	var other_systems = _get_other_systems(system)
	var energy_per_system = decrease / other_systems.size()
	
	for other in other_systems:
		var other_ref = _get_system_index_ref(other)
		if other_ref == null:
			continue
		if other_ref.value >= MAX_ENERGY_INDEX:
			continue
			
		var increase = min(energy_per_system, MAX_ENERGY_INDEX - other_ref.value)
		other_ref.value += increase
		index_ref.value -= increase
		
	start_flash()

# Get current energy level for a system
func get_energy_level(system: String) -> float:
	var index_ref = _get_system_index_ref(system)
	if index_ref == null:
		return 0.0
	return energy_levels[index_ref.value]

# Helper to get reference to system index
func _get_system_index_ref(system: String) -> Dictionary:
	match system:
		"weapons":
			if !has_weapons:
				return {}
			return {"value": weapon_index}
		"shields":
			if !has_shields:
				return {}
			return {"value": shield_index}
		"engines":
			if !has_engines:
				return {}
			return {"value": engine_index}
	return {}

# Helper to get other available systems
func _get_other_systems(system: String) -> Array:
	var others = []
	match system:
		"weapons":
			if has_shields:
				others.append("shields")
			if has_engines:
				others.append("engines")
		"shields":
			if has_weapons:
				others.append("weapons")
			if has_engines:
				others.append("engines")
		"engines":
			if has_weapons:
				others.append("weapons")
			if has_shields:
				others.append("shields")
	return others

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
	
	var x = 0
	var y_offset = font_size + 5
	
	# Draw weapons system
	if has_weapons:
		# Draw letter
		draw_string(font, Vector2(x + bar_width/2 - font_size/4, font_size), "G", 
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		# Draw bar background
		draw_rect(Rect2(x, y_offset, bar_width, bar_height), Color(color, 0.2))
		# Draw energy bar
		var bar_height_px = bar_height * energy_levels[weapon_index]
		draw_rect(Rect2(x, y_offset + (bar_height - bar_height_px), 
			bar_width, bar_height_px), color)
		x += bar_spacing
		
	# Draw shields system
	if has_shields:
		# Draw letter
		draw_string(font, Vector2(x + bar_width/2 - font_size/4, font_size), "S",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		# Draw bar background
		draw_rect(Rect2(x, y_offset, bar_width, bar_height), Color(color, 0.2))
		# Draw energy bar
		var bar_height_px = bar_height * energy_levels[shield_index]
		draw_rect(Rect2(x, y_offset + (bar_height - bar_height_px),
			bar_width, bar_height_px), color)
		x += bar_spacing
		
	# Draw engines system
	if has_engines:
		# Draw letter
		draw_string(font, Vector2(x + bar_width/2 - font_size/4, font_size), "E",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		# Draw bar background
		draw_rect(Rect2(x, y_offset, bar_width, bar_height), Color(color, 0.2))
		# Draw energy bar
		var bar_height_px = bar_height * energy_levels[engine_index]
		draw_rect(Rect2(x, y_offset + (bar_height - bar_height_px),
			bar_width, bar_height_px), color)
