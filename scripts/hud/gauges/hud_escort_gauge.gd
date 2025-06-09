@tool
extends HUDGauge
class_name HUDEscortGauge

# Escort ship info (simplified for display)
class EscortTarget:
	var name: String = ""
	var hull_percent: float = 1.0
	var shield_percent: float = 1.0 # Overall shield strength
	var status: String = "" # e.g., "OK", "DMG", "CRIT", "DISABLED"
	var is_player_target: bool = false
	var flash_time: float = 0.0 # For hit flashing

# Gauge settings
@export_group("Escort Settings")
@export var escort_list: Array:
	set(value):
		escort_list = value
		queue_redraw()
@export var max_display_ships: int = 3 # Corresponds roughly to Max_escort_ships

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(150, 100) # Adjust as needed
@export var entry_spacing := 20
@export var health_bar_width := 50
@export var health_bar_height := 4
@export var flash_rate := 0.1

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(200, 150)

# Status tracking
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.ESCORT_VIEW
	if flash_duration == 0:
		flash_duration = 0.5 # Default flash duration for hits
	escort_list = []

func _ready() -> void:
	super._ready()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship exists
	var player_ship = ObjectManager.get_player_ship() if ObjectManager else null
	if not player_ship or not is_instance_valid(player_ship):
		if not escort_list.is_empty(): escort_list.clear(); queue_redraw()
		return

	# Get the list of escort targets from object manager
	# Assuming a function returns an array of ShipBase nodes marked for escort
	var escort_targets_nodes = ObjectManager.get_escort_list() if ObjectManager and ObjectManager.has_method("get_escort_list") else []

	var new_escort_data = []
	var player_target_id = player_ship.get("target_object_id", 0) if player_ship.has_method("get") else 0

	for ship_node in escort_targets_nodes:
		if not is_instance_valid(ship_node): continue
		var ship = ship_node  # Use generic node reference

		# Limit display count
		if new_escort_data.size() >= max_display_ships: break

		var target_info = EscortTarget.new()
		target_info.name = ship.get("ship_name", "Unknown") if ship.has_method("get") else ship.name if ship.has_property("name") else "Unknown"
		
		# Get hull percentage using safe access
		var hull_strength = ship.get("hull_strength", 0.0) if ship.has_method("get") else 0.0
		var max_hull = ship.get("ship_max_hull_strength", 1.0) if ship.has_method("get") else 1.0
		target_info.hull_percent = hull_strength / max_hull if max_hull > 0 else 0.0

		# Get overall shield percentage using safe access
		var shield_system = ship.get("shield_system", null) if ship.has_method("get") else null
		if shield_system and is_instance_valid(shield_system):
			var shield_strength = shield_system.get("shield_strength", 0.0) if shield_system.has_method("get") else 0.0
			var max_shield = shield_system.get("max_shield_strength", 1.0) if shield_system.has_method("get") else 1.0
			target_info.shield_percent = shield_strength / max_shield if max_shield > 0 else 0.0
		else:
			target_info.shield_percent = 0.0 # Assume no shields if system missing

		# Determine status text
		var flags = ship.get("flags", 0) if ship.has_method("get") else 0
		var flags2 = ship.get("flags2", 0) if ship.has_method("get") else 0
		var disabled_flag = WCSConstants.SF_DISABLED if WCSConstants and WCSConstants.has_property("SF_DISABLED") else 0
		var disabled_flag2 = WCSConstants.SF2_DISABLED if WCSConstants and WCSConstants.has_property("SF2_DISABLED") else 0
		
		if (flags & disabled_flag) or (flags2 & disabled_flag2):
			target_info.status = "DIS"
		elif target_info.hull_percent <= 0.25:
			target_info.status = "CRIT"
		elif target_info.hull_percent <= 0.75:
			target_info.status = "DMG"
		else:
			target_info.status = "OK"

		target_info.is_player_target = (ship.get_instance_id() == player_target_id)

		# TODO: Handle hit flashing - needs signal connection from DamageSystem/ShieldSystem
		# For now, flash is not implemented here, relies on external trigger via register_hit()

		new_escort_data.append(target_info)

	# Update the list if it has changed
	# TODO: More efficient update? Compare individual entries?
	if _lists_differ(escort_list, new_escort_data):
		escort_list = new_escort_data # Setter handles redraw


# Helper to compare lists (basic check)
func _lists_differ(list_a: Array, list_b: Array) -> bool:
	if list_a.size() != list_b.size(): return true
	for i in range(list_a.size()):
		# Compare key fields
		if list_a[i].name != list_b[i].name or \
		   abs(list_a[i].hull_percent - list_b[i].hull_percent) > 0.01 or \
		   abs(list_a[i].shield_percent - list_b[i].shield_percent) > 0.01 or \
		   list_a[i].status != list_b[i].status or \
		   list_a[i].is_player_target != list_b[i].is_player_target:
			return true
	return false


# Call this when an escort ship is hit (needs signal connection)
func register_hit(ship_instance_id: int):
	for target_info in escort_list:
		# Need a way to link target_info back to ship_instance_id (e.g., store ID in EscortTarget)
		# if target_info.instance_id == ship_instance_id: # Assuming instance_id exists
		#	 target_info.flash_time = flash_duration
		#	 queue_redraw()
		#	 break
		pass # Placeholder


# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()

		# Add sample escort data for preview
		if escort_list.is_empty():
			var t1 = EscortTarget.new()
			t1.name = "Convoy Alpha"
			t1.hull_percent = 0.8
			t1.shield_percent = 0.6
			t1.status = "DMG"
			t1.is_player_target = true
			var t2 = EscortTarget.new()
			t2.name = "Freighter Beta"
			t2.hull_percent = 0.3
			t2.shield_percent = 0.1
			t2.status = "CRIT"
			escort_list = [t1, t2]

	if !can_draw() && !Engine.is_editor_hint():
		return

	if escort_list.is_empty():
		return

	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var x = 10
	var y = line_height

	# Draw header (Optional, based on original gauge frames)
	draw_string(font, Vector2(x, y), "ESCORT", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_current_color())
	y += line_height + 5

	# Draw escort entries
	for target_info in escort_list:
		var color = get_current_color()
		# Handle flashing if implemented
		# if target_info.flash_time > 0 and _flash_state:
		#	 color = Color.RED

		# Draw selection indicator if this is the player's target
		if target_info.is_player_target:
			draw_string(font, Vector2(x, y + line_height / 2), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

		# Draw name
		var name_x = x + (font_size if target_info.is_player_target else 0)
		draw_string(font, Vector2(name_x, y + line_height / 2), target_info.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

		# Draw status text
		var status_x = gauge_size.x - 30 # Adjust position
		draw_string(font, Vector2(status_x, y + line_height / 2), target_info.status, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size, color)

		# Draw health bars (optional)
		# TODO: Implement health bar drawing similar to hud_wingman_gauge.gd if needed

		y += entry_spacing


func _process(delta: float) -> void:
	super._process(delta)

	var needs_redraw = false

	# Update flash state for hits (if implemented)
	# _flash_time += delta
	# if _flash_time >= flash_rate:
	#	 _flash_time = 0.0
	#	 _flash_state = !_flash_state
	#	 # Check if any escort target is flashing
	#	 for target_info in escort_list:
	#		 if target_info.flash_time > 0:
	#			 target_info.flash_time -= flash_rate # Decrement flash timer
	#			 needs_redraw = true
	#			 break # Only need one flashing item to trigger redraw

	if needs_redraw:
		queue_redraw()
