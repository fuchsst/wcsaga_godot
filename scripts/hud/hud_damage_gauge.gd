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

# Add a subsystem
func add_subsystem(type: Subsystem.Type, name: String, health: float = 100.0,
	critical: bool = false) -> void:
	var sys = Subsystem.new(type, name, health, critical)
	subsystems.append(sys)
	queue_redraw()

# Update subsystem health
func update_subsystem_health(index: int, health: float) -> void:
	if index >= 0 && index < subsystems.size():
		var sys = subsystems[index]
		if health < sys.health:
			sys.damage_flash_time = flash_duration
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
