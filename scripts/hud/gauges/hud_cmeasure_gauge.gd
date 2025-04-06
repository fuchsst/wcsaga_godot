@tool
extends HUDGauge
class_name HUDCMeasureGauge

# CMeasure settings
@export_group("CMeasure Settings")
@export var cmeasure_count := 0:
	set(value):
		cmeasure_count = maxi(0, value)
		queue_redraw()
@export var max_cmeasures := 20:
	set(value):
		max_cmeasures = maxi(1, value)
		queue_redraw()
@export var recharge_time := 5.0
@export var deploy_time := 0.5

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(150, 50)
@export var flash_rate := 0.2
@export var warning_threshold := 3
@export var critical_threshold := 1
@export var show_recharge := true:
	set(value):
		show_recharge = value
		queue_redraw()

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(200, 80)

# Status tracking
var _recharge_time_left := 0.0
var _deploy_time_left := 0.0
var _flash_time := 0.0
var _flash_state := false
var _is_deploying := false
var _is_recharging := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.CMEASURE_GAUGE

func _ready() -> void:
	super._ready()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship exists using GameState singleton
	if GameState.player_ship and is_instance_valid(GameState.player_ship):
		# Read countermeasure count and max from player ship
		# Assuming these methods/properties exist on ShipBase or WeaponSystem
		var current_count = 0
		var max_count = 1 # Default to avoid division by zero

		# Try getting from WeaponSystem first, then fallback to ShipBase
		if GameState.player_ship.weapon_system and GameState.player_ship.weapon_system.has_method("get_cmeasure_count"):
			current_count = GameState.player_ship.weapon_system.get_cmeasure_count()
		elif GameState.player_ship.has_method("get_cmeasure_count"):
			current_count = GameState.player_ship.get_cmeasure_count() # Placeholder method name

		if GameState.player_ship.weapon_system and GameState.player_ship.weapon_system.has_method("get_max_cmeasures"):
			max_count = GameState.player_ship.weapon_system.get_max_cmeasures()
		elif GameState.player_ship.has_method("get_max_cmeasures"):
			max_count = GameState.player_ship.get_max_cmeasures() # Placeholder method name

		# Update gauge properties (setters handle queue_redraw)
		cmeasure_count = current_count
		max_cmeasures = max(1, max_count) # Ensure max is at least 1

		# Optional: Sync recharge state if managed externally
		# _is_recharging = GameState.player_ship.is_cmeasure_recharging() # Placeholder
		# _recharge_time_left = GameState.player_ship.get_cmeasure_recharge_time_left() # Placeholder
	else:
		# Default state if no player ship
		cmeasure_count = 0
		max_cmeasures = 1 # Avoid division by zero if used

# Deploy countermeasure
func deploy_cmeasure() -> bool:
	if cmeasure_count > 0 && !_is_deploying:
		cmeasure_count -= 1
		_is_deploying = true
		_deploy_time_left = deploy_time
		queue_redraw()
		return true
	return false

# Add countermeasures
func add_cmeasures(amount: int) -> void:
	cmeasure_count = mini(cmeasure_count + amount, max_cmeasures)
	queue_redraw()

# Start recharge cycle
func start_recharge() -> void:
	if !_is_recharging && cmeasure_count < max_cmeasures:
		_is_recharging = true
		_recharge_time_left = recharge_time
		queue_redraw()

# Stop recharge cycle
func stop_recharge() -> void:
	_is_recharging = false
	_recharge_time_left = 0.0
	queue_redraw()

# Get status color based on count
func _get_status_color() -> Color:
	var color = get_current_color()
	
	if cmeasure_count <= critical_threshold:
		color = Color.RED
	elif cmeasure_count <= warning_threshold:
		color = Color.YELLOW
	
	if _is_deploying && _flash_state:
		color = Color.WHITE
	
	return color

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample values for preview
		if cmeasure_count == 0:
			cmeasure_count = 15
			_is_recharging = true
			_recharge_time_left = recharge_time * 0.7
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var x = 10
	var y = line_height
	
	# Get display color
	var color = _get_status_color()
	
	# Draw countermeasure count
	var count_text = "CM: %d" % cmeasure_count
	draw_string(font, Vector2(x, y), count_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	
	# Draw recharge progress if active
	if show_recharge && _is_recharging:
		y += line_height
		var progress = 1.0 - (_recharge_time_left / recharge_time)
		var bar_width = 50.0
		var bar_height = 4.0
		
		# Draw background bar
		draw_rect(Rect2(x, y, bar_width, bar_height),
			Color(color, 0.3))
		
		# Draw progress bar
		draw_rect(Rect2(x, y, bar_width * progress, bar_height),
			Color(color, 0.8))

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update deployment
	if _is_deploying:
		_deploy_time_left -= delta
		if _deploy_time_left <= 0:
			_is_deploying = false
		needs_redraw = true
	
	# Update recharge
	if _is_recharging:
		_recharge_time_left -= delta
		if _recharge_time_left <= 0:
			_is_recharging = false
			add_cmeasures(1)
			if cmeasure_count < max_cmeasures:
				start_recharge()
		needs_redraw = true
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		if _is_deploying || cmeasure_count <= warning_threshold:
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
