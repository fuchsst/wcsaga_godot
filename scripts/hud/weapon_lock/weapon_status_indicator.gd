class_name WeaponStatusIndicator
extends Node2D

## Real-time weapon readiness display for HUD-007
## Shows weapon charge status, ammo counts, heat levels, and firing readiness
## Supports multiple weapon types with appropriate status indicators

# Weapon status data structure
class WeaponStatus:
	var weapon_name: String = ""
	var weapon_type: WeaponLockDisplay.WeaponType = WeaponLockDisplay.WeaponType.ENERGY
	var is_ready: bool = false
	var is_charging: bool = false
	var is_overheated: bool = false
	var is_jammed: bool = false
	var charge_level: float = 0.0      # 0.0 to 1.0
	var heat_level: float = 0.0        # 0.0 to 1.0
	var ammo_current: int = 0
	var ammo_maximum: int = 0
	var energy_drain_rate: float = 0.0 # Energy per shot
	var cooldown_time: float = 0.0     # Remaining cooldown time
	var firing_rate: float = 0.0       # Shots per second
	var last_fired_time: float = 0.0

# Display modes
enum DisplayMode {
	COMPACT,	# Minimal status indicators
	STANDARD,	# Standard weapon status display
	DETAILED	# Full weapon diagnostics
}

# Status indicator types
enum IndicatorType {
	CHARGE_BAR,		# Energy/charge level bar
	AMMO_COUNT,		# Ammunition counter
	HEAT_GAUGE,		# Heat level gauge
	READY_LIGHT,	# Ready/not ready indicator
	COOLDOWN_TIMER	# Cooldown time display
}

# Display configuration
@export_group("Display Configuration")
@export var display_mode: DisplayMode = DisplayMode.STANDARD
@export var max_weapons_shown: int = 4
@export var show_primary_weapons: bool = true
@export var show_secondary_weapons: bool = true
@export var show_tertiary_weapons: bool = false

# Visual settings
@export_group("Visual Settings")
@export var indicator_spacing: float = 30.0
@export var bar_width: float = 60.0
@export var bar_height: float = 8.0
@export var ready_light_size: float = 6.0
@export var text_size: int = 12
@export var background_alpha: float = 0.7

# Color settings
@export_group("Colors")
@export var color_ready: Color = Color.GREEN
@export var color_charging: Color = Color.YELLOW
@export var color_overheated: Color = Color.RED
@export var color_jammed: Color = Color.MAGENTA
@export var color_ammo_full: Color = Color.CYAN
@export var color_ammo_low: Color = Color.ORANGE
@export var color_ammo_empty: Color = Color.RED
@export var color_background: Color = Color(0.0, 0.0, 0.0, 0.7)
@export var color_border: Color = Color.WHITE

# Positioning
@export_group("Positioning")
@export var base_position: Vector2 = Vector2(10, 300)
@export var weapon_slot_height: float = 40.0
@export var horizontal_layout: bool = false

# Current weapon status data
var weapon_statuses: Array[WeaponStatus] = []
var selected_weapon_index: int = 0
var update_frequency: float = 20.0  # Hz
var last_update_time: float = 0.0

# Animation state
var _flash_time: float = 0.0
var _flash_state: bool = false

# References
var player_ship: Node3D = null
var weapon_manager: Node = null

func _ready() -> void:
	set_process(true)
	_initialize_weapon_status_indicator()

## Initialize weapon status indicator
func initialize_weapon_status_indicator() -> bool:
	"""Initialize weapon status indicator system."""
	# Get player ship reference
	if GameState.player_ship:
		player_ship = GameState.player_ship
		
		# Get weapon manager
		if player_ship.has_method("get_weapon_manager"):
			weapon_manager = player_ship.get_weapon_manager()
		
		# Initialize weapon status array
		_initialize_weapon_statuses()
		
		return true
	
	push_error("WeaponStatusIndicator: Cannot initialize without player ship")
	return false

## Initialize weapon status tracking
func _initialize_weapon_statuses() -> void:
	"""Initialize weapon status tracking array."""
	weapon_statuses.clear()
	
	# Create status objects for tracked weapons
	for i in range(max_weapons_shown):
		var status := WeaponStatus.new()
		status.weapon_name = "Weapon %d" % (i + 1)
		weapon_statuses.append(status)

## Update weapon status with new data
func update_weapon_status(weapon_data: Dictionary) -> void:
	"""Update weapon status with weapon system data."""
	if not weapon_data:
		return
	
	var current_time: float = Time.get_time_from_start()
	
	# Limit update frequency for performance
	if current_time - last_update_time < (1.0 / update_frequency):
		return
	
	last_update_time = current_time
	
	# Get weapon list from data
	var weapons_list: Array = weapon_data.get("weapons", [])
	
	# Update each weapon status
	for i in range(min(weapons_list.size(), weapon_statuses.size())):
		var weapon_info: Dictionary = weapons_list[i]
		var status: WeaponStatus = weapon_statuses[i]
		
		_update_weapon_status_from_data(status, weapon_info)
	
	# Clear unused weapon slots
	for i in range(weapons_list.size(), weapon_statuses.size()):
		_clear_weapon_status(weapon_statuses[i])
	
	# Update selected weapon index
	if weapon_data.has("selected_weapon"):
		selected_weapon_index = weapon_data["selected_weapon"]
	
	queue_redraw()

## Update individual weapon status from data
func _update_weapon_status_from_data(status: WeaponStatus, weapon_info: Dictionary) -> void:
	"""Update individual weapon status from weapon data."""
	status.weapon_name = weapon_info.get("name", "Unknown")
	status.weapon_type = weapon_info.get("type", WeaponLockDisplay.WeaponType.ENERGY)
	status.is_ready = weapon_info.get("ready", false)
	status.is_charging = weapon_info.get("charging", false)
	status.is_overheated = weapon_info.get("overheated", false)
	status.is_jammed = weapon_info.get("jammed", false)
	status.charge_level = weapon_info.get("charge", 0.0)
	status.heat_level = weapon_info.get("heat", 0.0)
	status.ammo_current = weapon_info.get("ammo_current", 0)
	status.ammo_maximum = weapon_info.get("ammo_maximum", 0)
	status.energy_drain_rate = weapon_info.get("energy_drain", 0.0)
	status.cooldown_time = weapon_info.get("cooldown", 0.0)
	status.firing_rate = weapon_info.get("firing_rate", 0.0)
	status.last_fired_time = weapon_info.get("last_fired", 0.0)

## Clear weapon status
func _clear_weapon_status(status: WeaponStatus) -> void:
	"""Clear weapon status for unused slot."""
	status.weapon_name = ""
	status.is_ready = false
	status.is_charging = false
	status.is_overheated = false
	status.is_jammed = false
	status.charge_level = 0.0
	status.heat_level = 0.0
	status.ammo_current = 0
	status.ammo_maximum = 0

## Main drawing method
func _draw() -> void:
	"""Main drawing method for weapon status indicators."""
	if display_mode == DisplayMode.COMPACT:
		_draw_compact_display()
	elif display_mode == DisplayMode.STANDARD:
		_draw_standard_display()
	elif display_mode == DisplayMode.DETAILED:
		_draw_detailed_display()

## Draw compact display
func _draw_compact_display() -> void:
	"""Draw compact weapon status display."""
	var current_pos: Vector2 = base_position
	var active_weapons: int = 0
	
	for i in range(weapon_statuses.size()):
		var status: WeaponStatus = weapon_statuses[i]
		if status.weapon_name.is_empty():
			continue
		
		_draw_compact_weapon_indicator(current_pos, status, i == selected_weapon_index)
		
		if horizontal_layout:
			current_pos.x += indicator_spacing
		else:
			current_pos.y += indicator_spacing
		
		active_weapons += 1
		if active_weapons >= max_weapons_shown:
			break

## Draw standard display
func _draw_standard_display() -> void:
	"""Draw standard weapon status display."""
	var current_pos: Vector2 = base_position
	var active_weapons: int = 0
	
	for i in range(weapon_statuses.size()):
		var status: WeaponStatus = weapon_statuses[i]
		if status.weapon_name.is_empty():
			continue
		
		_draw_standard_weapon_panel(current_pos, status, i == selected_weapon_index)
		
		current_pos.y += weapon_slot_height
		
		active_weapons += 1
		if active_weapons >= max_weapons_shown:
			break

## Draw detailed display
func _draw_detailed_display() -> void:
	"""Draw detailed weapon status display."""
	var current_pos: Vector2 = base_position
	var active_weapons: int = 0
	
	for i in range(weapon_statuses.size()):
		var status: WeaponStatus = weapon_statuses[i]
		if status.weapon_name.is_empty():
			continue
		
		_draw_detailed_weapon_panel(current_pos, status, i == selected_weapon_index)
		
		current_pos.y += weapon_slot_height + 10
		
		active_weapons += 1
		if active_weapons >= max_weapons_shown:
			break

## Draw compact weapon indicator
func _draw_compact_weapon_indicator(position: Vector2, status: WeaponStatus, is_selected: bool) -> void:
	"""Draw compact weapon status indicator."""
	var indicator_color: Color = _get_weapon_status_color(status)
	var size: float = ready_light_size
	
	# Larger size if selected
	if is_selected:
		size *= 1.5
	
	# Draw status light
	if status.is_ready:
		draw_circle(position, size, indicator_color)
	else:
		draw_arc(position, size, 0, TAU, 16, indicator_color, 2.0)
		
		# Show charge progress for charging weapons
		if status.is_charging and status.charge_level > 0.0:
			var progress_arc: float = TAU * status.charge_level
			draw_arc(position, size + 2, -PI/2, -PI/2 + progress_arc, 16, color_charging, 2.0)
	
	# Flash if selected
	if is_selected and _flash_state:
		draw_arc(position, size + 4, 0, TAU, 16, Color.WHITE, 1.0)

## Draw standard weapon panel
func _draw_standard_weapon_panel(position: Vector2, status: WeaponStatus, is_selected: bool) -> void:
	"""Draw standard weapon status panel."""
	var panel_width: float = 200.0
	var panel_height: float = weapon_slot_height - 5
	var panel_rect := Rect2(position, Vector2(panel_width, panel_height))
	
	# Panel background
	var bg_color: Color = color_background
	if is_selected:
		bg_color = Color(bg_color.r, bg_color.g, bg_color.b, bg_color.a + 0.2)
	
	draw_rect(panel_rect, bg_color)
	draw_rect(panel_rect, color_border, false, 1.0)
	
	# Weapon name
	var font := ThemeDB.fallback_font
	var font_size := text_size
	var text_pos: Vector2 = position + Vector2(5, font_size + 2)
	var name_color: Color = Color.WHITE if is_selected else Color.LIGHT_GRAY
	
	draw_string(font, text_pos, status.weapon_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, name_color)
	
	# Status indicators
	var indicator_start: Vector2 = position + Vector2(5, font_size + 8)
	_draw_weapon_status_indicators(indicator_start, status, false)

## Draw detailed weapon panel
func _draw_detailed_weapon_panel(position: Vector2, status: WeaponStatus, is_selected: bool) -> void:
	"""Draw detailed weapon status panel."""
	var panel_width: float = 250.0
	var panel_height: float = weapon_slot_height + 5
	var panel_rect := Rect2(position, Vector2(panel_width, panel_height))
	
	# Panel background
	var bg_color: Color = color_background
	if is_selected:
		bg_color = Color(bg_color.r, bg_color.g, bg_color.b, bg_color.a + 0.2)
	
	draw_rect(panel_rect, bg_color)
	draw_rect(panel_rect, color_border, false, 1.0)
	
	# Weapon name and type
	var font := ThemeDB.fallback_font
	var font_size := text_size
	var text_pos: Vector2 = position + Vector2(5, font_size + 2)
	var name_color: Color = Color.WHITE if is_selected else Color.LIGHT_GRAY
	
	var weapon_type_name: String = WeaponLockDisplay.WeaponType.keys()[status.weapon_type]
	var display_text: String = "%s (%s)" % [status.weapon_name, weapon_type_name]
	draw_string(font, text_pos, display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, name_color)
	
	# Detailed status indicators
	var indicator_start: Vector2 = position + Vector2(5, font_size + 8)
	_draw_weapon_status_indicators(indicator_start, status, true)

## Draw weapon status indicators
func _draw_weapon_status_indicators(position: Vector2, status: WeaponStatus, detailed: bool) -> void:
	"""Draw weapon status indicators (bars, counters, etc.)."""
	var current_pos: Vector2 = position
	var line_height: float = bar_height + 4
	
	# Ready status light
	_draw_ready_status_light(current_pos, status)
	current_pos.x += ready_light_size * 2 + 5
	
	# Charge/Energy bar (for energy weapons)
	if status.weapon_type in [WeaponLockDisplay.WeaponType.ENERGY, WeaponLockDisplay.WeaponType.BEAM]:
		_draw_charge_bar(current_pos, status)
		current_pos.x += bar_width + 10
	
	# Ammo counter (for ballistic/missile weapons)
	elif status.weapon_type in [WeaponLockDisplay.WeaponType.BALLISTIC, WeaponLockDisplay.WeaponType.MISSILE]:
		_draw_ammo_counter(current_pos, status)
		current_pos.x += 50
	
	# Heat gauge (if weapon generates heat)
	if status.heat_level > 0.1 or detailed:
		current_pos.y += line_height
		current_pos.x = position.x + ready_light_size * 2 + 5
		_draw_heat_gauge(current_pos, status)
		current_pos.x += bar_width + 10
	
	# Cooldown timer (if cooling down)
	if status.cooldown_time > 0.0:
		current_pos.y += line_height
		current_pos.x = position.x + ready_light_size * 2 + 5
		_draw_cooldown_timer(current_pos, status)

## Draw ready status light
func _draw_ready_status_light(position: Vector2, status: WeaponStatus) -> void:
	"""Draw weapon ready status light."""
	var light_color: Color = _get_weapon_status_color(status)
	var size: float = ready_light_size
	
	if status.is_ready:
		draw_circle(position, size, light_color)
	elif status.is_charging:
		# Pulsing circle while charging
		var pulse_size: float = size * (1.0 + 0.3 * sin(_flash_time * 4.0))
		draw_circle(position, pulse_size, Color(light_color.r, light_color.g, light_color.b, 0.6))
		draw_arc(position, size, 0, TAU, 16, light_color, 2.0)
	else:
		draw_arc(position, size, 0, TAU, 16, light_color, 2.0)

## Draw charge bar
func _draw_charge_bar(position: Vector2, status: WeaponStatus) -> void:
	"""Draw weapon charge level bar."""
	var bar_rect := Rect2(position, Vector2(bar_width, bar_height))
	
	# Background
	draw_rect(bar_rect, Color.BLACK)
	
	# Charge fill
	var charge_width: float = bar_width * status.charge_level
	var charge_rect := Rect2(position, Vector2(charge_width, bar_height))
	var charge_color: Color = color_ready if status.charge_level >= 1.0 else color_charging
	draw_rect(charge_rect, charge_color)
	
	# Border
	draw_rect(bar_rect, Color.WHITE, false, 1.0)
	
	# Percentage text
	var font := ThemeDB.fallback_font
	var font_size := text_size - 2
	var percent_text: String = "%d%%" % int(status.charge_level * 100)
	var text_pos: Vector2 = position + Vector2(bar_width + 5, bar_height - 1)
	draw_string(font, text_pos, percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

## Draw ammo counter
func _draw_ammo_counter(position: Vector2, status: WeaponStatus) -> void:
	"""Draw ammunition counter."""
	var font := ThemeDB.fallback_font
	var font_size := text_size
	
	# Determine ammo color
	var ammo_color: Color = color_ammo_full
	if status.ammo_maximum > 0:
		var ammo_ratio: float = float(status.ammo_current) / float(status.ammo_maximum)
		if ammo_ratio == 0.0:
			ammo_color = color_ammo_empty
		elif ammo_ratio < 0.3:
			ammo_color = color_ammo_low
	
	# Draw ammo count
	var ammo_text: String = "%d" % status.ammo_current
	if status.ammo_maximum > 0:
		ammo_text += "/%d" % status.ammo_maximum
	
	draw_string(font, position, ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ammo_color)

## Draw heat gauge
func _draw_heat_gauge(position: Vector2, status: WeaponStatus) -> void:
	"""Draw weapon heat level gauge."""
	var bar_rect := Rect2(position, Vector2(bar_width, bar_height))
	
	# Background
	draw_rect(bar_rect, Color.BLACK)
	
	# Heat fill
	var heat_width: float = bar_width * status.heat_level
	var heat_rect := Rect2(position, Vector2(heat_width, bar_height))
	var heat_color: Color = Color.YELLOW
	if status.heat_level > 0.8:
		heat_color = color_overheated
	elif status.heat_level > 0.6:
		heat_color = Color.ORANGE
	
	draw_rect(heat_rect, heat_color)
	
	# Border
	draw_rect(bar_rect, Color.WHITE, false, 1.0)
	
	# Temperature warning
	if status.is_overheated:
		var font := ThemeDB.fallback_font
		var font_size := text_size - 2
		var warning_pos: Vector2 = position + Vector2(bar_width + 5, bar_height - 1)
		draw_string(font, warning_pos, "OVERHEAT", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color_overheated)

## Draw cooldown timer
func _draw_cooldown_timer(position: Vector2, status: WeaponStatus) -> void:
	"""Draw weapon cooldown timer."""
	var font := ThemeDB.fallback_font
	var font_size := text_size - 2
	
	var cooldown_text: String = "COOL: %.1fs" % status.cooldown_time
	draw_string(font, position, cooldown_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color_charging)

## Get weapon status color
func _get_weapon_status_color(status: WeaponStatus) -> Color:
	"""Get color based on weapon status."""
	if status.is_jammed:
		return color_jammed
	elif status.is_overheated:
		return color_overheated
	elif status.is_ready:
		return color_ready
	elif status.is_charging:
		return color_charging
	else:
		return Color.GRAY

## Process updates
func _process(delta: float) -> void:
	"""Process weapon status indicator updates."""
	# Update flash animation
	_flash_time += delta
	_flash_state = fmod(_flash_time, 1.0) < 0.5
	
	# Update cooldown timers
	for status in weapon_statuses:
		if status.cooldown_time > 0.0:
			status.cooldown_time = maxf(0.0, status.cooldown_time - delta)
	
	# Redraw if we have active animations
	var should_redraw: bool = false
	for status in weapon_statuses:
		if status.is_charging or status.cooldown_time > 0.0 or status.is_overheated:
			should_redraw = true
			break
	
	if should_redraw:
		queue_redraw()

## Public interface

## Set display mode
func set_display_mode(mode: DisplayMode) -> void:
	"""Set weapon status display mode."""
	display_mode = mode
	queue_redraw()

## Set maximum weapons shown
func set_max_weapons_shown(count: int) -> void:
	"""Set maximum number of weapons to display."""
	max_weapons_shown = count
	_initialize_weapon_statuses()
	queue_redraw()

## Set selected weapon
func set_selected_weapon(index: int) -> void:
	"""Set selected weapon index."""
	selected_weapon_index = clamp(index, 0, weapon_statuses.size() - 1)
	queue_redraw()

## Set base position
func set_base_position(position: Vector2) -> void:
	"""Set base position for weapon status display."""
	base_position = position
	queue_redraw()

## Set layout orientation
func set_horizontal_layout(horizontal: bool) -> void:
	"""Set whether to use horizontal layout."""
	horizontal_layout = horizontal
	queue_redraw()

## Get weapon status for specific weapon
func get_weapon_status(weapon_index: int) -> Dictionary:
	"""Get weapon status data for specific weapon."""
	if weapon_index < 0 or weapon_index >= weapon_statuses.size():
		return {}
	
	var status: WeaponStatus = weapon_statuses[weapon_index]
	return {
		"weapon_name": status.weapon_name,
		"weapon_type": status.weapon_type,
		"is_ready": status.is_ready,
		"is_charging": status.is_charging,
		"is_overheated": status.is_overheated,
		"charge_level": status.charge_level,
		"heat_level": status.heat_level,
		"ammo_current": status.ammo_current,
		"ammo_maximum": status.ammo_maximum,
		"cooldown_time": status.cooldown_time
	}

## Get all weapon statuses
func get_all_weapon_statuses() -> Array[Dictionary]:
	"""Get status data for all weapons."""
	var statuses: Array[Dictionary] = []
	
	for i in range(weapon_statuses.size()):
		var status_data: Dictionary = get_weapon_status(i)
		if not status_data.is_empty():
			statuses.append(status_data)
	
	return statuses

## Check if any weapons are ready
func has_ready_weapons() -> bool:
	"""Check if any weapons are ready to fire."""
	for status in weapon_statuses:
		if status.is_ready and not status.weapon_name.is_empty():
			return true
	return false

## Get ready weapon count
func get_ready_weapon_count() -> int:
	"""Get count of ready weapons."""
	var count: int = 0
	for status in weapon_statuses:
		if status.is_ready and not status.weapon_name.is_empty():
			count += 1
	return count