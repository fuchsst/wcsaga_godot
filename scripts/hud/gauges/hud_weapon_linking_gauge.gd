@tool
extends HUDGauge
class_name HUDWeaponLinkingGauge

# Link status settings
@export_group("Link Settings")
@export var linking_active := false:
	set(value):
		linking_active = value
		queue_redraw()
@export var num_primary_banks := 2:
	set(value):
		num_primary_banks = clampi(value, 0, MAX_WEAPON_BANKS)
		_update_link_status()
		queue_redraw()
@export var num_secondary_banks := 2:
	set(value):
		num_secondary_banks = clampi(value, 0, MAX_WEAPON_BANKS)
		_update_link_status()
		queue_redraw()

# Link configuration
@export_group("Link Configuration")
@export var primary_link_mask := 0:
	set(value):
		primary_link_mask = value
		_update_link_status()
		queue_redraw()
@export var secondary_link_mask := 0:
	set(value):
		secondary_link_mask = value
		_update_link_status()
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(120, 160)
@export var bank_size := Vector2(30, 20)
@export var bank_spacing := 10.0
@export var group_spacing := 40.0
@export var show_labels := true:
	set(value):
		show_labels = value
		queue_redraw()
@export var flash_rate := 0.2
@export var flash_changes := true

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(150, 200)

# Constants
const MAX_WEAPON_BANKS := 4

# Status tracking
var _flash_time := 0.0
var _flash_state := false
var _primary_groups := []
var _secondary_groups := []

func _init() -> void:
	super._init()
	gauge_id = GaugeType.WEAPON_LINKING_GAUGE

func _ready() -> void:
	super._ready()
	_update_link_status()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship and its weapon system exist
	if GameState.player_ship and is_instance_valid(GameState.player_ship) and GameState.player_ship.weapon_system:
		var weapon_sys: WeaponSystem = GameState.player_ship.weapon_system
		var ship = GameState.player_ship

		var new_num_primary = weapon_sys.num_primary_banks
		var new_num_secondary = weapon_sys.num_secondary_banks
		var new_primary_mask = 0
		var new_secondary_mask = 0

		# Determine link masks based on ship flags
		if ship.flags & GlobalConstants.SF_PRIMARY_LINKED:
			# Set all bits up to num_primary_banks if linked
			new_primary_mask = (1 << new_num_primary) - 1
		else:
			# Only set the bit for the current primary bank if not linked
			if weapon_sys.current_primary_bank >= 0:
				new_primary_mask = 1 << weapon_sys.current_primary_bank

		if ship.flags & GlobalConstants.SF_SECONDARY_DUAL_FIRE:
			# Set all bits up to num_secondary_banks if dual fire
			# Note: FS2 dual fire might have different logic than simple linking all.
			# Assuming for now it means all secondaries fire together.
			new_secondary_mask = (1 << new_num_secondary) - 1
		else:
			# Only set the bit for the current secondary bank if not dual fire
			if weapon_sys.current_secondary_bank >= 0:
				new_secondary_mask = 1 << weapon_sys.current_secondary_bank

		# Update gauge properties if they changed (setters handle redraw and _update_link_status)
		var changed = false
		if num_primary_banks != new_num_primary:
			num_primary_banks = new_num_primary
			changed = true
		if num_secondary_banks != new_num_secondary:
			num_secondary_banks = new_num_secondary
			changed = true
		if primary_link_mask != new_primary_mask:
			primary_link_mask = new_primary_mask
			changed = true
		if secondary_link_mask != new_secondary_mask:
			secondary_link_mask = new_secondary_mask
			changed = true

		# Activate the gauge if there are weapons
		linking_active = (new_num_primary > 0 or new_num_secondary > 0)

	else:
		# Default state if no player ship or weapon system
		linking_active = false
		num_primary_banks = 0
		num_secondary_banks = 0
		primary_link_mask = 0
		secondary_link_mask = 0


# Set weapon bank counts
func set_weapon_banks(primary: int, secondary: int) -> void:
	num_primary_banks = primary
	num_secondary_banks = secondary

# Set link configuration
func set_link_masks(primary: int, secondary: int) -> void:
	primary_link_mask = primary
	secondary_link_mask = secondary

# Update weapon link groups
func _update_link_status() -> void:
	_primary_groups.clear()
	_secondary_groups.clear()
	
	# Group primary weapons
	var current_group := []
	for i in range(num_primary_banks):
		var mask = 1 << i
		if primary_link_mask & mask:
			current_group.append(i)
		else:
			if current_group.size() > 0:
				_primary_groups.append(current_group.duplicate())
				current_group.clear()
			current_group = [i]
	if current_group.size() > 0:
		_primary_groups.append(current_group)
	
	# Group secondary weapons
	current_group.clear()
	for i in range(num_secondary_banks):
		var mask = 1 << i
		if secondary_link_mask & mask:
			current_group.append(i)
		else:
			if current_group.size() > 0:
				_secondary_groups.append(current_group.duplicate())
				current_group.clear()
			current_group = [i]
	if current_group.size() > 0:
		_secondary_groups.append(current_group)

# Draw weapon bank
func _draw_weapon_bank(pos: Vector2, color: Color, active: bool = true) -> void:
	var rect = Rect2(pos, bank_size)
	
	# Draw bank outline
	draw_rect(rect, color, false)
	
	# Draw bank fill if active
	if active:
		draw_rect(rect, Color(color, 0.3))
	
	# Draw link indicators
	var link_size = Vector2(bank_size.x * 0.2, 2.0)
	var link_pos = Vector2(
		pos.x + (bank_size.x - link_size.x) * 0.5,
		pos.y + bank_size.y
	)
	draw_rect(Rect2(link_pos, link_size), color)

# Draw weapon group
func _draw_weapon_group(pos: Vector2, banks: Array, color: Color) -> void:
	var total_width = bank_size.x * banks.size() + bank_spacing * (banks.size() - 1)
	var start_x = pos.x - total_width * 0.5
	
	for i in range(banks.size()):
		var bank_pos = Vector2(
			start_x + (bank_size.x + bank_spacing) * i,
			pos.y
		)
		_draw_weapon_bank(bank_pos, color, true)
		
		# Draw link lines between banks
		if i > 0:
			var link_start = bank_pos + Vector2(-bank_spacing, bank_size.y * 0.5)
			var link_end = link_start + Vector2(bank_spacing, 0)
			draw_line(link_start, link_end, color, 2.0)

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample configuration for preview
		if !linking_active:
			linking_active = true
			set_weapon_banks(3, 2)
			set_link_masks(0b011, 0b11)
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	if !linking_active:
		return
		
	var size = gauge_size
	if Engine.is_editor_hint():
		size = preview_size
	
	var color = get_current_color()
	if _flash_state && flash_changes:
		color = Color.WHITE
	
	var center_x = size.x * 0.5
	var y = size.y * 0.2
	
	# Draw primary groups
	if show_labels:
		var font = ThemeDB.fallback_font
		var font_size = ThemeDB.fallback_font_size
		
		draw_string(font, Vector2(center_x, y - font_size - 5),
			"PRIMARY",
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
	
	for group in _primary_groups:
		_draw_weapon_group(Vector2(center_x, y), group, color)
		y += bank_size.y + group_spacing
	
	y += group_spacing
	
	# Draw secondary groups
	if show_labels:
		var font = ThemeDB.fallback_font
		var font_size = ThemeDB.fallback_font_size
		
		draw_string(font, Vector2(center_x, y - font_size - 5),
			"SECONDARY",
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
	
	for group in _secondary_groups:
		_draw_weapon_group(Vector2(center_x, y), group, color)
		y += bank_size.y + group_spacing

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		if linking_active && flash_changes:
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
