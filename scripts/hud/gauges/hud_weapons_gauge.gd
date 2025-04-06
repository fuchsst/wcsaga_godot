@tool
extends HUDGauge
class_name HUDWeaponsGauge

# Weapon types
enum WeaponType {
	PRIMARY,
	SECONDARY
}

# Weapon settings
@export_group("Weapon Settings")
@export var primary_weapons: Array[WeaponGroup]:
	set(value):
		primary_weapons = value
		queue_redraw()
@export var secondary_weapons: Array[WeaponGroup]:
	set(value):
		secondary_weapons = value
		queue_redraw()
@export var current_primary: int = 0:
	set(value):
		current_primary = value
		queue_redraw()
@export var current_secondary: int = 0:
	set(value):
		current_secondary = value
		queue_redraw()
@export var weapon_energy: float = 1.0:
	set(value):
		weapon_energy = clampf(value, 0.0, 1.0)
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(200, 150)
@export var weapon_spacing := 20
@export var energy_bar_width := 100
@export var energy_bar_height := 10
@export var ammo_bar_width := 50
@export var ammo_bar_height := 8

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(250, 200)

func _init() -> void:
	super._init()
	gauge_id = GaugeType.WEAPONS_GAUGE

func _ready() -> void:
	super._ready()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship and its weapon system exist
	if GameState.player_ship and is_instance_valid(GameState.player_ship) and GameState.player_ship.weapon_system:
		var weapon_sys: WeaponSystem = GameState.player_ship.weapon_system
		var ship = GameState.player_ship

		# Update Weapon Energy (setter handles redraw)
		weapon_energy = weapon_sys.get_weapon_energy_pct()

		# Update Selected Banks (setters handle redraw)
		current_primary = weapon_sys.current_primary_bank
		current_secondary = weapon_sys.current_secondary_bank

		# Update Weapon Groups (Primary)
		var new_primary_weapons = []
		for i in range(weapon_sys.num_primary_banks):
			var weapon_index = weapon_sys.primary_bank_weapons[i]
			if weapon_index >= 0:
				var weapon_data: WeaponData = GlobalConstants.get_weapon_data(weapon_index)
				if weapon_data:
					var ammo = weapon_sys.primary_bank_ammo[i]
					var max_ammo = weapon_sys.primary_bank_capacity[i]
					var is_energy = not (weapon_data.flags2 & GlobalConstants.WIF2_BALLISTIC)
					# Check linking status (assuming WeaponSystem tracks this or ShipBase flags)
					var is_linked = (ship.flags & GlobalConstants.SF_PRIMARY_LINKED) and (weapon_sys.num_primary_banks > 1)

					var group = WeaponGroup.new(
						weapon_data.weapon_name, # Or use alt_name?
						ammo,
						max_ammo,
						weapon_data.energy_consumed,
						is_energy,
						is_linked
					)
					new_primary_weapons.append(group)
				else:
					printerr("HUDWeaponsGauge: Could not get WeaponData for primary index %d" % weapon_index)
			# else: Handle empty bank if needed, maybe add a placeholder?

		# Update Secondary Weapons
		var new_secondary_weapons = []
		for i in range(weapon_sys.num_secondary_banks):
			var weapon_index = weapon_sys.secondary_bank_weapons[i]
			if weapon_index >= 0:
				var weapon_data: WeaponData = GlobalConstants.get_weapon_data(weapon_index)
				if weapon_data:
					var ammo = weapon_sys.secondary_bank_ammo[i]
					var max_ammo = weapon_sys.secondary_bank_capacity[i]
					# Check linking status (dual fire)
					var is_linked = (ship.flags & GlobalConstants.SF_SECONDARY_DUAL_FIRE) and (weapon_sys.num_secondary_banks > 1)

					var group = WeaponGroup.new(
						weapon_data.weapon_name, # Or use alt_name?
						ammo,
						max_ammo,
						0.0, # Secondaries don't use energy directly
						false, # Secondaries are ammo based
						is_linked
					)
					new_secondary_weapons.append(group)
				else:
					printerr("HUDWeaponsGauge: Could not get WeaponData for secondary index %d" % weapon_index)

		# Update the gauge's arrays (setters handle redraw)
		# TODO: More efficient update? Only update if lists actually changed?
		primary_weapons = new_primary_weapons
		secondary_weapons = new_secondary_weapons

	else:
		# Default state if no player ship or weapon system
		weapon_energy = 0.0
		current_primary = 0
		current_secondary = 0
		primary_weapons = []
		secondary_weapons = []


# Update weapons from ship state (Keep for potential direct calls?)
func update_from_ship(ship: ShipBase) -> void:
	# TODO: Update weapon info from ship
	# This would update:
	# - Weapon groups
	# - Ammo counts
	# - Energy levels
	# - Active weapons
	pass

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample weapons for preview
		if primary_weapons.is_empty():
			primary_weapons = [
				WeaponGroup.new("Laser", -1, -1, 0.2, true, true),
				WeaponGroup.new("Mass Driver", 100, 100, 0.0, false, false)
			]
		if secondary_weapons.is_empty():
			secondary_weapons = [
				WeaponGroup.new("Missile", 20, 20, 0.0, false, true),
				WeaponGroup.new("Torpedo", 5, 5, 0.0, false, false)
			]
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var color = get_current_color()
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var x = 10
	var y = line_height
	
	# Draw weapon energy bar
	draw_string(font, Vector2(x, y), "ENERGY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	y += line_height
	
	var energy_bg_rect = Rect2(x, y, energy_bar_width, energy_bar_height)
	draw_rect(energy_bg_rect, Color(color, 0.2))
	
	var energy_fill_rect = Rect2(x, y, energy_bar_width * weapon_energy, energy_bar_height)
	draw_rect(energy_fill_rect, color)
	y += energy_bar_height + line_height
	
	# Draw primary weapons
	y += 5
	draw_string(font, Vector2(x, y), "PRIMARY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	y += line_height
	
	for i in range(primary_weapons.size()):
		var weapon = primary_weapons[i]
		_draw_weapon_group(Vector2(x, y), weapon, i == current_primary, color)
		y += weapon_spacing
	
	# Draw secondary weapons
	y += 10
	draw_string(font, Vector2(x, y), "SECONDARY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	y += line_height
	
	for i in range(secondary_weapons.size()):
		var weapon = secondary_weapons[i]
		_draw_weapon_group(Vector2(x, y), weapon, i == current_secondary, color)
		y += weapon_spacing

# Draw a weapon group entry
func _draw_weapon_group(pos: Vector2, weapon: WeaponGroup, is_current: bool, color: Color) -> void:
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var x = pos.x
	var y = pos.y
	
	# Draw selection indicator
	if is_current:
		draw_string(font, Vector2(x, y), ">",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	x += font_size
	
	# Draw weapon name
	draw_string(font, Vector2(x, y), weapon.name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	x += 100
	
	# Draw linking indicator
	if weapon.is_linked:
		draw_string(font, Vector2(x, y), "L",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	x += font_size + 5
	
	# Draw ammo/energy bar
	if weapon.is_energy:
		# Draw energy cost indicator
		var energy_width = ammo_bar_width * weapon.energy_cost
		var energy_rect = Rect2(x, y + 2, energy_width, ammo_bar_height - 4)
		draw_rect(energy_rect, Color(color, 0.5))
	else:
		# Draw ammo count
		if weapon.max_ammo > 0:
			# Draw background
			var ammo_bg_rect = Rect2(x, y + 2, ammo_bar_width, ammo_bar_height - 4)
			draw_rect(ammo_bg_rect, Color(color, 0.2))
			
			# Draw ammo level
			var ammo_ratio = float(weapon.ammo) / weapon.max_ammo
			var ammo_width = ammo_bar_width * ammo_ratio
			var ammo_rect = Rect2(x, y + 2, ammo_width, ammo_bar_height - 4)
			draw_rect(ammo_rect, color)
			
			# Draw ammo count
			var ammo_text = str(weapon.ammo)
			draw_string(font, Vector2(x + ammo_bar_width + 5, y), ammo_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

# Add a weapon group
func add_weapon_group(type: WeaponType, name: String, ammo: int = -1, 
	energy_cost: float = 0.0, is_energy: bool = false) -> void:
	var group = WeaponGroup.new(name, ammo, ammo, energy_cost, is_energy)
	
	match type:
		WeaponType.PRIMARY:
			primary_weapons.append(group)
		WeaponType.SECONDARY:
			secondary_weapons.append(group)
	
	queue_redraw()

# Clear all weapon groups
func clear_weapons() -> void:
	primary_weapons.clear()
	secondary_weapons.clear()
	current_primary = 0
	current_secondary = 0
	queue_redraw()

# Set weapon linking for a group
func set_weapon_linked(type: WeaponType, index: int, linked: bool) -> void:
	var weapons = primary_weapons if type == WeaponType.PRIMARY else secondary_weapons
	if index >= 0 && index < weapons.size():
		weapons[index].is_linked = linked
		queue_redraw()

# Set active weapon
func set_active_weapon(type: WeaponType, index: int) -> void:
	match type:
		WeaponType.PRIMARY:
			current_primary = index
		WeaponType.SECONDARY:
			current_secondary = index
	queue_redraw()

# Update ammo count for a weapon
func update_ammo(type: WeaponType, index: int, ammo: int) -> void:
	var weapons = primary_weapons if type == WeaponType.PRIMARY else secondary_weapons
	if index >= 0 && index < weapons.size():
		weapons[index].ammo = ammo
		queue_redraw()
