@tool
extends HUDGauge
class_name HUDKillsGauge



# Kill settings
@export_group("Kill Settings")
@export var kill_info: KillInfo:
	set(value):
		kill_info = value
		queue_redraw()
@export var show_details: bool = false:
	set(value):
		show_details = value
		queue_redraw()
@export var show_score: bool = true:
	set(value):
		show_score = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(150, 100)
@export var flash_rate := 0.1

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(200, 150)

# Status tracking
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.KILLS_GAUGE
	if flash_duration == 0:
		flash_duration = 1.0
	kill_info = KillInfo.new()

func _ready() -> void:
	super._ready()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if PlayerData exists via GameState singleton
	if GameState.player_data and is_instance_valid(GameState.player_data):
		var player_stats = GameState.player_data.stats # Assuming stats are stored here

		# Update kill info directly (setters handle redraw)
		# Assuming PlayerData.stats has properties like:
		# - total_kills
		# - current_score
		# - mission_kills
		# - mission_score
		# - kill_types (Dictionary mapping KillInfo.Type to count)
		kill_info.total_kills = player_stats.get("total_kills", 0)
		kill_info.current_score = player_stats.get("current_score", 0)
		kill_info.mission_kills = player_stats.get("mission_kills", 0)
		kill_info.mission_score = player_stats.get("mission_score", 0)

		# Update kill types dictionary
		var stats_kill_types = player_stats.get("kill_types", {})
		for type_enum_value in KillInfo.Type.values():
			# Ensure the type exists in the stats dictionary before accessing
			kill_info.kill_types[type_enum_value] = stats_kill_types.get(type_enum_value, 0)

		# Trigger flash if a kill happened recently?
		# Need a way to detect a *new* kill since the last update.
		# Option 1: Compare current total_kills with a stored _last_total_kills
		# Option 2: ScoringManager emits a signal player_scored_kill
		# For now, let's assume the flash is triggered externally via start_flash() or add_kill()

	else:
		# Default state if no player data
		clear_stats() # Resets kill_info


# Add a kill
func add_kill(type: KillInfo.Type, score: int = 100) -> void:
	kill_info.total_kills += 1
	kill_info.kill_types[type] += 1
	kill_info.current_score += score
	kill_info.mission_kills += 1
	kill_info.mission_score += score
	kill_info.last_kill_time = Time.get_ticks_msec() / 1000.0
	kill_info.flash_time = flash_duration
	queue_redraw()

# Set total kills (for loading saved games)
func set_total_kills(kills: int, score: int = 0) -> void:
	kill_info.total_kills = kills
	kill_info.current_score = score
	queue_redraw()

# Set kill type count
func set_kill_type_count(type: KillInfo.Type, count: int) -> void:
	kill_info.kill_types[type] = count
	queue_redraw()

# Reset mission stats
func reset_mission_stats() -> void:
	kill_info.mission_kills = 0
	kill_info.mission_score = 0
	queue_redraw()

# Clear all stats
func clear_stats() -> void:
	kill_info = KillInfo.new()
	queue_redraw()

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample kills for preview
		if kill_info.total_kills == 0:
			kill_info.total_kills = 42
			kill_info.kill_types[KillInfo.Type.FIGHTER] = 25
			kill_info.kill_types[KillInfo.Type.BOMBER] = 10
			kill_info.kill_types[KillInfo.Type.CAPITAL] = 5
			kill_info.current_score = 8500
			kill_info.mission_kills = 3
			kill_info.mission_score = 500
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var x = 10
	var y = line_height
	
	# Get display color
	var color = get_current_color()
	if kill_info.flash_time > 0 && _flash_state:
		color = Color.GREEN
	
	# Draw total kills
	var kills_text = "Kills: %d" % kill_info.total_kills
	if kill_info.mission_kills > 0:
		kills_text += " (+%d)" % kill_info.mission_kills
	draw_string(font, Vector2(x, y), kills_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	y += line_height
	
	# Draw score if enabled
	if show_score:
		var score_text = "Score: %d" % kill_info.current_score
		if kill_info.mission_score > 0:
			score_text += " (+%d)" % kill_info.mission_score
		draw_string(font, Vector2(x, y), score_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_height
	
	# Draw kill type details if enabled
	if show_details:
		y += line_height/2
		
		for type in kill_info.kill_types:
			var count = kill_info.kill_types[type]
			if count > 0:
				var type_text = "%s: %d" % [_get_kill_type_text(type), count]
				draw_string(font, Vector2(x + 10, y), type_text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
				y += line_height

# Get text for kill type
func _get_kill_type_text(type: KillInfo.Type) -> String:
	match type:
		KillInfo.Type.FIGHTER:
			return "Fighters"
		KillInfo.Type.BOMBER:
			return "Bombers"
		KillInfo.Type.CAPITAL:
			return "Capital Ships"
		KillInfo.Type.TRANSPORT:
			return "Transports"
		KillInfo.Type.ASTEROID:
			return "Asteroids"
		KillInfo.Type.OTHER:
			return "Other"
		_:
			return "Unknown"

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update kill flash
	if kill_info.flash_time > 0:
		kill_info.flash_time -= delta
		needs_redraw = true
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
