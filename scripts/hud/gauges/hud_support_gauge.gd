@tool
extends HUDGauge
class_name HUDSupportGauge


# Support settings
@export_group("Support Settings")
@export var support_info: SupportInfo:
	set(value):
		support_info = value
		queue_redraw()
@export var show_progress: bool = true:
	set(value):
		show_progress = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(200, 100)
@export var progress_bar_width := 100
@export var progress_bar_height := 8
@export var flash_rate := 0.5

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(250, 150)

# Status tracking
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = GaugeType.SUPPORT_GAUGE
	support_info = SupportInfo.new()

func _ready() -> void:
	super._ready()

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship exists
	if GameState.player_ship and is_instance_valid(GameState.player_ship):
		# Get support status from the player ship or a dedicated SupportManager
		# Assuming PlayerShip has methods or properties to get this info
		var current_support_data = GameState.player_ship.get_support_status_data() # Placeholder method

		if current_support_data and current_support_data.get("is_active", false):
			# Assuming current_support_data is a Dictionary like:
			# { is_active: true, ship_name: "TCS Hermes", status: SupportInfo.Status.APPROACHING,
			#   distance: 1500.0, eta: 45.0, repair_progress: 0.3, rearm_progress: 0.7 }

			# Check if the support ship name has changed
			if support_info.ship_name != current_support_data.get("ship_name", ""):
				set_support_ship(current_support_data.get("ship_name", "")) # Resets other info

			# Update status, distance, eta
			update_support_status(
				current_support_data.get("status", SupportInfo.Status.NONE),
				current_support_data.get("distance", -1.0),
				current_support_data.get("eta", -1.0)
			)

			# Update progress
			update_progress(
				current_support_data.get("repair_progress", -1.0),
				current_support_data.get("rearm_progress", -1.0)
			)

			# Ensure gauge is active
			if not support_info.is_active:
				support_info.is_active = true
				queue_redraw()

		else:
			# No active support, clear the gauge
			if support_info.is_active:
				clear_support()
	else:
		# No player ship, clear the gauge
		if support_info.is_active:
			clear_support()


# Set support ship
func set_support_ship(name: String) -> void:
	if support_info.ship_name != name:
		support_info.ship_name = name
		support_info.status = SupportInfo.Status.NONE
		support_info.distance = 0.0
		support_info.eta = 0.0
		support_info.repair_progress = 0.0
		support_info.rearm_progress = 0.0
		support_info.is_active = true
		queue_redraw()

# Update support status
func update_support_status(status: SupportInfo.Status, distance: float = -1,
	eta: float = -1) -> void:
	if !support_info.is_active:
		return
		
	support_info.status = status
	if distance >= 0:
		support_info.distance = distance
	if eta >= 0:
		support_info.eta = eta
	queue_redraw()

# Update repair/rearm progress
func update_progress(repair: float = -1, rearm: float = -1) -> void:
	if !support_info.is_active:
		return
		
	if repair >= 0:
		support_info.repair_progress = clampf(repair, 0.0, 1.0)
	if rearm >= 0:
		support_info.rearm_progress = clampf(rearm, 0.0, 1.0)
	queue_redraw()

# Clear support info
func clear_support() -> void:
	support_info.is_active = false
	queue_redraw()

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample support info for preview
		if !support_info.is_active:
			support_info.ship_name = "TCS Hermes"
			support_info.status = SupportInfo.Status.APPROACHING
			support_info.distance = 1500.0
			support_info.eta = 45.0
			support_info.repair_progress = 0.3
			support_info.rearm_progress = 0.7
			support_info.is_active = true
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	if !support_info.is_active:
		return
		
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var x = 10
	var y = line_height
	
	# Get status color
	var color = _get_status_color()
	
	# Draw support ship name
	draw_string(font, Vector2(x, y), support_info.ship_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	y += line_height
	
	# Draw status
	var status_text = _get_status_text()
	if status_text:
		draw_string(font, Vector2(x, y), status_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_height
	
	# Draw distance/ETA if applicable
	match support_info.status:
		SupportInfo.Status.APPROACHING:
			var dist_text = "Distance: %.0fm" % support_info.distance
			draw_string(font, Vector2(x, y), dist_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			y += line_height
			
			var eta_text = "ETA: %.0fs" % support_info.eta
			draw_string(font, Vector2(x, y), eta_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			y += line_height
		
		SupportInfo.Status.REPAIRING, SupportInfo.Status.REARMING:
			if show_progress:
				y += line_height/2
				
				# Draw repair progress if needed
				if support_info.repair_progress > 0:
					draw_string(font, Vector2(x, y), "Repairs:",
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
					
					var repair_bg_rect = Rect2(x + 80, y + 2,
						progress_bar_width, progress_bar_height)
					draw_rect(repair_bg_rect, Color(color, 0.2))
					
					var repair_fill_rect = Rect2(x + 80, y + 2,
						progress_bar_width * support_info.repair_progress,
						progress_bar_height)
					draw_rect(repair_fill_rect, color)
					
					y += line_height
				
				# Draw rearm progress if needed
				if support_info.rearm_progress > 0:
					draw_string(font, Vector2(x, y), "Rearming:",
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
					
					var rearm_bg_rect = Rect2(x + 80, y + 2,
						progress_bar_width, progress_bar_height)
					draw_rect(rearm_bg_rect, Color(color, 0.2))
					
					var rearm_fill_rect = Rect2(x + 80, y + 2,
						progress_bar_width * support_info.rearm_progress,
						progress_bar_height)
					draw_rect(rearm_fill_rect, color)
					
					y += line_height

# Get color based on support status
func _get_status_color() -> Color:
	match support_info.status:
		SupportInfo.Status.NONE:
			return get_current_color()
		SupportInfo.Status.APPROACHING:
			return Color.YELLOW
		SupportInfo.Status.DOCKING:
			return Color.GREEN
		SupportInfo.Status.REPAIRING, SupportInfo.Status.REARMING:
			return Color.GREEN
		SupportInfo.Status.DEPARTING:
			return Color.YELLOW
		SupportInfo.Status.ABORTED:
			return Color.RED
		_:
			return get_current_color()

# Get text for support status
func _get_status_text() -> String:
	match support_info.status:
		SupportInfo.Status.NONE:
			return ""
		SupportInfo.Status.APPROACHING:
			return "En Route"
		SupportInfo.Status.DOCKING:
			return "Docking"
		SupportInfo.Status.REPAIRING:
			return "Repairing"
		SupportInfo.Status.REARMING:
			return "Rearming"
		SupportInfo.Status.DEPARTING:
			return "Departing"
		SupportInfo.Status.ABORTED:
			return "Aborted"
		_:
			return ""

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
