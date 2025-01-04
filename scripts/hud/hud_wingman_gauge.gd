@tool
extends HUDGauge
class_name HUDWingmanGauge


# Wingman settings
@export_group("Wingman Settings")
@export var wingmen: Array[Wingman]:
	set(value):
		wingmen = value
		queue_redraw()
@export var show_orders: bool = true:
	set(value):
		show_orders = value
		queue_redraw()
@export var show_health: bool = true:
	set(value):
		show_health = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var gauge_size := Vector2(200, 300)
@export var wingman_spacing := 25
@export var health_bar_width := 60
@export var health_bar_height := 6
@export var flash_rate := 0.1

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(250, 350)

# Status tracking
var _flash_time := 0.0
var _flash_state := false

func _init() -> void:
	super._init()
	gauge_id = HUDGauge.WINGMEN_STATUS
	if flash_duration == 0:
		flash_duration = 0.5

func _ready() -> void:
	super._ready()

# Add a wingman
func add_wingman(name: String, callsign: String, health: float = 1.0,
	shield: float = 1.0) -> void:
	var wm = Wingman.new(name, callsign, health, shield)
	wingmen.append(wm)
	queue_redraw()

# Update wingman status
func update_wingman(index: int, status: Wingman.Status, health: float = -1,
	shield: float = -1) -> void:
	if index >= 0 && index < wingmen.size():
		var wm = wingmen[index]
		if status != wm.status:
			wm.status = status
			wm.flash_time = flash_duration
		if health >= 0:
			wm.health = clampf(health, 0.0, 1.0)
		if shield >= 0:
			wm.shield = clampf(shield, 0.0, 1.0)
		queue_redraw()

# Update wingman order
func update_wingman_order(index: int, order: Wingman.OrderType,
	target: String = "") -> void:
	if index >= 0 && index < wingmen.size():
		var wm = wingmen[index]
		wm.current_order = order
		wm.target_name = target
		queue_redraw()

# Set selected wingman
func set_selected_wingman(index: int) -> void:
	for i in range(wingmen.size()):
		wingmen[i].is_selected = (i == index)
	queue_redraw()

# Clear all wingmen
func clear_wingmen() -> void:
	wingmen.clear()
	queue_redraw()

# Draw the gauge using Node2D drawing
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		
		# Add sample wingmen for preview
		if wingmen.is_empty():
			wingmen = [
				Wingman.new("Alpha 1", "Maverick", 0.8, 0.6),
				Wingman.new("Alpha 2", "Goose", 1.0, 1.0),
				Wingman.new("Alpha 3", "Iceman", 0.4, 0.2),
				Wingman.new("Alpha 4", "Viper", 0.0, 0.0)
			]
			wingmen[0].current_order = Wingman.OrderType.ATTACK
			wingmen[0].target_name = "Kilrathi Ace"
			wingmen[1].current_order = Wingman.OrderType.FORM_UP
			wingmen[2].status = Wingman.Status.CRITICAL
			wingmen[3].status = Wingman.Status.DESTROYED
	
	if !can_draw() && !Engine.is_editor_hint():
		return
		
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var line_height = font_size + 4
	var x = 10
	var y = line_height
	
	# Draw wingmen
	for wm in wingmen:
		var color = _get_status_color(wm)
		
		# Handle status flash
		if wm.flash_time > 0 && _flash_state:
			color = Color.RED
		
		# Draw selection indicator
		if wm.is_selected:
			draw_string(font, Vector2(x, y + line_height/2), ">",
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += font_size
		
		# Draw callsign/name
		var name_text = wm.callsign if wm.callsign else wm.name
		draw_string(font, Vector2(x, y + line_height/2), name_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		
		# Draw status indicator
		var status_text = _get_status_text(wm.status)
		if status_text:
			x += 80
			draw_string(font, Vector2(x, y + line_height/2), status_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		
		# Draw health bars if enabled
		if show_health && wm.status != Wingman.Status.DESTROYED:
			x += 40
			
			# Draw shield bar
			var shield_color = _get_health_color(wm.shield)
			var shield_bg_rect = Rect2(x, y + 2, health_bar_width, health_bar_height)
			draw_rect(shield_bg_rect, Color(shield_color, 0.2))
			
			var shield_fill_rect = Rect2(x, y + 2,
				health_bar_width * wm.shield, health_bar_height)
			draw_rect(shield_fill_rect, shield_color)
			
			# Draw hull bar
			var hull_color = _get_health_color(wm.health)
			var hull_bg_rect = Rect2(x, y + health_bar_height + 4,
				health_bar_width, health_bar_height)
			draw_rect(hull_bg_rect, Color(hull_color, 0.2))
			
			var hull_fill_rect = Rect2(x, y + health_bar_height + 4,
				health_bar_width * wm.health, health_bar_height)
			draw_rect(hull_fill_rect, hull_color)
		
		# Draw current order if enabled
		if show_orders && wm.current_order != Wingman.OrderType.NONE:
			x = 20
			y += line_height
			var order_text = _get_order_text(wm.current_order)
			if wm.target_name:
				order_text += " " + wm.target_name
			draw_string(font, Vector2(x, y + line_height/2), order_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, 0.8))
		
		# Reset x and move to next wingman
		x = 10
		y += wingman_spacing

# Get color based on wingman status
func _get_status_color(wm: Wingman) -> Color:
	match wm.status:
		Wingman.Status.ALIVE:
			return get_current_color()
		Wingman.Status.DAMAGED:
			return Color.YELLOW
		Wingman.Status.CRITICAL:
			return Color.RED
		Wingman.Status.DEPARTED:
			return Color(get_current_color(), 0.5)
		Wingman.Status.DESTROYED:
			return Color.RED
		_:
			return get_current_color()

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

# Get text for wingman status
func _get_status_text(status: Wingman.Status) -> String:
	match status:
		Wingman.Status.DAMAGED:
			return "DMG"
		Wingman.Status.CRITICAL:
			return "CRIT"
		Wingman.Status.DEPARTED:
			return "GONE"
		Wingman.Status.DESTROYED:
			return "LOST"
		_:
			return ""

# Get text for order type
func _get_order_text(order: Wingman.OrderType) -> String:
	match order:
		Wingman.OrderType.ATTACK:
			return "ATTACKING"
		Wingman.OrderType.DEFEND:
			return "DEFENDING"
		Wingman.OrderType.FORM_UP:
			return "FORMING UP"
		Wingman.OrderType.COVER:
			return "COVERING"
		Wingman.OrderType.REARM:
			return "REARMING"
		Wingman.OrderType.DISABLE:
			return "DISABLING"
		_:
			return ""

func _process(delta: float) -> void:
	super._process(delta)
	
	var needs_redraw = false
	
	# Update wingman status flash
	for wm in wingmen:
		if wm.flash_time > 0:
			wm.flash_time -= delta
			needs_redraw = true
	
	# Update flash state
	_flash_time += delta
	if _flash_time >= flash_rate:
		_flash_time = 0.0
		_flash_state = !_flash_state
		needs_redraw = true
	
	if needs_redraw:
		queue_redraw()
