@tool
extends HUDGauge
class_name HUDTargetMonitor

# Target info
@export_group("Target Info")
@export var target_name: String = "":
	set(value):
		target_name = value
		queue_redraw()
@export var target_class: String = "":
	set(value):
		target_class = value
		queue_redraw()
@export var target_team: int = 0:
	set(value):
		target_team = value
		queue_redraw()
@export var target_distance: float = 0.0:
	set(value):
		target_distance = value
		queue_redraw()

# Target status
@export_group("Target Status")
@export var hull_strength: float = 1.0:
	set(value):
		hull_strength = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var shield_strength: Array[float] = [1.0, 1.0, 1.0, 1.0]:
	set(value):
		shield_strength = value
		queue_redraw()
@export var is_disabled: bool = false:
	set(value):
		is_disabled = value
		queue_redraw()

# Subsystem targeting
@export_group("Subsystems")
@export var current_subsystem: String = "":
	set(value):
		current_subsystem = value
		queue_redraw()
@export var subsystem_strength: float = 1.0:
	set(value):
		subsystem_strength = clampf(value, 0.0, 1.0)
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var monitor_size := Vector2(200, 150)
@export var shield_display_size := Vector2(60, 60)
@export var hull_bar_width := 100
@export var hull_bar_height := 10

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(250, 200)

func _init() -> void:
	super._init()
	gauge_id = GaugeType.TARGET_MONITOR

	# References to child nodes (assuming names in target_monitor.tscn)
	@onready var sub_viewport: SubViewport = $TargetModelViewportContainer/SubViewport # Example path
	@onready var target_model_node: Node3D = $TargetModelViewportContainer/SubViewport/TargetModelRoot # Example path for the node holding the target model instance
	@onready var viewport_camera: Camera3D = $TargetModelViewportContainer/SubViewport/ViewportCamera # Example path

	# Runtime state for 3D view
	var _target_model_instance: Node3D = null
	var _target_radius: float = 1.0
	var _target_rotation_speed: float = 0.5 # Radians per second

	# Flashing/Static effect state
	# TODO: Implement flashing/static logic based on C++ TBOX_FLASH_* and hud_targetbox_static_maybe_blit

func _ready() -> void:
	super._ready()
	# Ensure viewport is set up correctly
	if sub_viewport:
		sub_viewport.transparent_bg = true
		# Set viewport size based on gauge configuration?
		# sub_viewport.size = ...
	else:
		printerr("HUDTargetMonitor: SubViewport node not found!")

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship and target exist
	if not GameState.player_ship or not is_instance_valid(GameState.player_ship) or GameState.player_ship.target_object_id == -1:
		_clear_target_display()
		return

	var target_node = ObjectManager.get_object_by_id(GameState.player_ship.target_object_id)
	if not is_instance_valid(target_node):
		_clear_target_display()
		return

	# Update display based on target type
	if target_node is ShipBase:
		update_from_target(target_node)
	# TODO: Add cases for other target types if needed (Asteroid, Debris, Weapon, JumpNode)
	# elif target_node is AsteroidObject: update_from_asteroid(target_node)
	else:
		# Target type not handled by this monitor? Clear display.
		_clear_target_display()


# Clear all target display elements
func _clear_target_display():
	target_name = ""
	target_class = ""
	target_team = 0
	target_distance = 0.0
	hull_strength = 0.0
	shield_strength = [0.0, 0.0, 0.0, 0.0] # Assuming 4 quadrants
	is_disabled = false
	current_subsystem = ""
	subsystem_strength = 0.0
	# Clear 3D model view
	if is_instance_valid(_target_model_instance):
		_target_model_instance.queue_free()
		_target_model_instance = null
	queue_redraw()


# Update monitor from target ship
func update_from_target(target_ship: ShipBase) -> void:
	if not is_instance_valid(target_ship) or not is_instance_valid(target_ship.ship_data):
		_clear_target_display()
		return

	var ship_data = target_ship.ship_data
	var shield_sys = target_ship.shield_system

	# Update Text Info (setters handle redraw)
	target_name = target_ship.ship_name # Or get formatted name
	target_class = ship_data.ship_class_name # Or get formatted class
	target_team = target_ship.team
	target_distance = GameState.player_ship.global_position.distance_to(target_ship.global_position) # Recalculate distance

	# Update Status
	hull_strength = target_ship.hull_strength / target_ship.ship_max_hull_strength if target_ship.ship_max_hull_strength > 0 else 0.0
	if shield_sys and is_instance_valid(shield_sys):
		shield_strength = target_shield_system.shield_quadrants.duplicate() # Get current quadrant strengths
	else:
		shield_strength = [0.0, 0.0, 0.0, 0.0] # Default if no shield system
	is_disabled = (target_ship.flags & GlobalConstants.SF_DISABLED) or \
				  (target_ship.flags2 & GlobalConstants.SF2_DISABLED) # Check relevant flags

	# Update Subsystem Info
	if is_instance_valid(target_ship.target_subsystem_node) and target_ship.target_subsystem_node is ShipSubsystem:
		var subsys: ShipSubsystem = target_ship.target_subsystem_node
		if is_instance_valid(subsys.subsystem_definition):
			current_subsystem = subsys.subsystem_definition.subobj_name # Or formatted name
			subsystem_strength = subsys.current_hits / subsys.subsystem_definition.max_hits if subsys.subsystem_definition.max_hits > 0 else 0.0
		else:
			current_subsystem = ""
			subsystem_strength = 0.0
	else:
		current_subsystem = ""
		subsystem_strength = 0.0

	# Update 3D Model View
	_update_target_model(target_ship)

	# TODO: Update flashing/static effects based on target status, damage, EMP etc.


# Update the 3D model displayed in the SubViewport
func _update_target_model(target_ship: ShipBase):
	if not sub_viewport or not target_model_node or not is_instance_valid(target_ship.ship_data):
		return

	var model_path = target_ship.ship_data.pof_file # Assuming this holds the scene path
	var current_model_path = _target_model_instance.scene_file_path if is_instance_valid(_target_model_instance) else ""

	# Load/replace model only if necessary
	if not is_instance_valid(_target_model_instance) or current_model_path != model_path:
		if is_instance_valid(_target_model_instance):
			_target_model_instance.queue_free()

		var scene: PackedScene = load(model_path)
		if scene:
			_target_model_instance = scene.instantiate()
			target_model_node.add_child(_target_model_instance)
			# Calculate radius for camera positioning
			var aabb = _target_model_instance.get_aabb()
			_target_radius = aabb.get_longest_axis_size() / 2.0
		else:
			printerr("HUDTargetMonitor: Failed to load target model scene: ", model_path)
			_target_model_instance = null
			_target_radius = 1.0

	# Update model rotation and camera position
	if is_instance_valid(_target_model_instance):
		# Rotate the model slowly
		_target_model_instance.rotate_y(_target_rotation_speed * get_process_delta_time())
		# Position camera based on model radius (simple approach)
		if viewport_camera:
			var cam_dist = _target_radius * 3.0 # Adjust multiplier for desired view
			viewport_camera.position = Vector3(0, _target_radius * 0.5, cam_dist) # Slightly above center
			viewport_camera.look_at(Vector3.ZERO, Vector3.UP)

		# TODO: Apply wireframe shader if Targetbox_wire is set
		# This requires accessing HUDUserSettings and applying a shader material override.
		# var user_settings = _hud_manager.get_user_settings() if _hud_manager else null
		# if user_settings and user_settings.Targetbox_wire > 0:
		#     apply_wireframe_material(_target_model_instance, user_settings.Targetbox_wire == 1)


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
	var line_height = font_size + 4
	var x = 10
	var y = line_height
	
	# Draw target name and class
	if target_name != "":
		draw_string(font, Vector2(x, y), target_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_height
		
	if target_class != "":
		draw_string(font, Vector2(x, y), target_class,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_height
	
	# Draw distance
	if target_distance > 0:
		var dist_text = "%.1fm" % target_distance
		draw_string(font, Vector2(x, y), dist_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_height
	
	# Draw hull strength bar
	y += 5
	var hull_bg_rect = Rect2(x, y, hull_bar_width, hull_bar_height)
	draw_rect(hull_bg_rect, Color(color, 0.2))
	
	var hull_fill_rect = Rect2(x, y, hull_bar_width * hull_strength, hull_bar_height)
	var hull_color = _get_hull_color(hull_strength)
	draw_rect(hull_fill_rect, hull_color)
	
	draw_string(font, Vector2(x + hull_bar_width + 5, y + hull_bar_height), "HULL",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	y += hull_bar_height + line_height
	
	# Draw shield display
	y += 5
	var shield_center = Vector2(x + shield_display_size.x/2, 
		y + shield_display_size.y/2)
	_draw_shield_display(shield_center, color)
	y += shield_display_size.y + 5
	
	# Draw subsystem info
	if current_subsystem != "":
		draw_string(font, Vector2(x, y), current_subsystem,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_height
		
		# Draw subsystem strength bar
		var sys_bg_rect = Rect2(x, y, hull_bar_width, hull_bar_height)
		draw_rect(sys_bg_rect, Color(color, 0.2))
		
		var sys_fill_rect = Rect2(x, y, hull_bar_width * subsystem_strength, hull_bar_height)
		draw_rect(sys_fill_rect, color)
		y += hull_bar_height + 5
	
	# Draw disabled status if applicable
	if is_disabled:
		draw_string(font, Vector2(x, y), "DISABLED",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.RED)

# Draw shield strength display
func _draw_shield_display(center: Vector2, color: Color) -> void:
	var radius = shield_display_size.x / 2
	
	# Draw shield quadrants
	for i in range(shield_strength.size()):
		var start_angle = i * PI/2 - PI/4
		var end_angle = start_angle + PI/2 - 0.1
		
		# Draw quadrant background
		_draw_shield_arc(center, radius - 5, radius, 
			start_angle, end_angle, Color(color, 0.2))
		
		# Draw shield strength
		if shield_strength[i] > 0:
			var strength_radius = radius - 5 + (5 * shield_strength[i])
			_draw_shield_arc(center, radius - 5, strength_radius,
				start_angle, end_angle, color)

# Helper to draw shield arc (similar to radar gauge)
func _draw_shield_arc(center: Vector2, inner_radius: float, outer_radius: float, 
	start_angle: float, end_angle: float, color: Color, num_points: int = 16) -> void:
	
	var points = PackedVector2Array()
	var angle_step = (end_angle - start_angle) / (num_points - 1)
	
	# Generate outer arc points
	for i in range(num_points):
		var angle = start_angle + i * angle_step
		points.push_back(center + Vector2(
			cos(angle) * outer_radius,
			sin(angle) * outer_radius
		))
	
	# Generate inner arc points (in reverse)
	for i in range(num_points - 1, -1, -1):
		var angle = start_angle + i * angle_step
		points.push_back(center + Vector2(
			cos(angle) * inner_radius,
			sin(angle) * inner_radius
		))
	
	# Draw filled polygon
	draw_colored_polygon(points, color)

# Get hull strength indicator color
func _get_hull_color(strength: float) -> Color:
	if strength <= 0.2:
		return Color.RED
	elif strength <= 0.5:
		return Color.YELLOW
	else:
		return get_current_color()
