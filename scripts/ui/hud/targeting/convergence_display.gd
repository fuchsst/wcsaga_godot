class_name ConvergenceDisplay
extends Control

## HUD-006: Weapon Convergence Display Component
## Provides visual display of weapon convergence points, optimal firing zones,
## and multi-weapon convergence handling for effective combat engagement

signal convergence_point_updated(point: Vector2, effective_range: float)
signal optimal_range_changed(min_range: float, max_range: float, optimal: float)
signal multi_weapon_convergence_calculated(convergence_data: Dictionary)

# Visual components
var convergence_marker: Control
var range_indicators: Array[Control] = []
var optimal_zone_display: Control
var weapon_cone_displays: Array[Control] = []

# Convergence state
var current_convergence_point: Vector2 = Vector2.ZERO
var effective_range: float = 0.0
var optimal_firing_range: float = 0.0
var min_effective_range: float = 0.0
var max_effective_range: float = 0.0

# Weapon data
var active_weapons: Array[Node] = []
var weapon_convergence_data: Dictionary = {}
var convergence_calculation_method: String = "weighted_average"  # "average", "weighted_average", "closest_weapon"

# Visual configuration
var convergence_marker_size: float = 24.0
var convergence_color: Color = Color.MAGENTA
var optimal_zone_color: Color = Color.GREEN
var range_indicator_color: Color = Color.YELLOW
var weapon_cone_color: Color = Color.CYAN

# Range display settings
var max_range_indicators: int = 5
var range_ring_thickness: float = 2.0
var show_weapon_cones: bool = true
var show_optimal_zone: bool = true

# Animation settings
var convergence_pulse_enabled: bool = true
var pulse_frequency: float = 1.5
var fade_duration: float = 0.3

# Performance settings
var update_frequency: float = 30.0  # 30 Hz for convergence calculations
var lod_enabled: bool = true
var distance_based_lod: bool = true

func _ready() -> void:
	set_process(false)  # Only process when active
	_initialize_convergence_display()
	print("ConvergenceDisplay: Convergence display initialized")

func _initialize_convergence_display() -> void:
	# Set up full-screen canvas for convergence display
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create convergence marker
	convergence_marker = _create_convergence_marker()
	add_child(convergence_marker)
	
	# Create optimal zone display
	optimal_zone_display = _create_optimal_zone_display()
	add_child(optimal_zone_display)
	
	# Initially hidden
	visible = false

func _create_convergence_marker() -> Control:
	var marker = Control.new()
	marker.size = Vector2(convergence_marker_size, convergence_marker_size)
	
	# Create diamond-shaped convergence marker
	var diamond_points = PackedVector2Array()
	var half_size = convergence_marker_size / 2
	
	# Diamond points
	diamond_points.append(Vector2(0, -half_size))      # Top
	diamond_points.append(Vector2(half_size, 0))       # Right
	diamond_points.append(Vector2(0, half_size))       # Bottom
	diamond_points.append(Vector2(-half_size, 0))      # Left
	diamond_points.append(Vector2(0, -half_size))      # Close the shape
	
	# Create visual representation using ColorRect elements
	# (In a full implementation, would use a custom draw function)
	var center_dot = ColorRect.new()
	center_dot.color = convergence_color
	center_dot.size = Vector2(4, 4)
	center_dot.position = Vector2(-2, -2)
	marker.add_child(center_dot)
	
	# Create diamond outline with four lines
	var line_thickness = 2.0
	var diamond_size = convergence_marker_size * 0.8
	
	# Top-right line
	var tr_line = ColorRect.new()
	tr_line.color = convergence_color
	tr_line.size = Vector2(diamond_size * 0.7, line_thickness)
	tr_line.rotation = PI / 4
	tr_line.position = Vector2(-diamond_size * 0.35, -diamond_size * 0.25)
	marker.add_child(tr_line)
	
	# Bottom-right line
	var br_line = ColorRect.new()
	br_line.color = convergence_color
	br_line.size = Vector2(diamond_size * 0.7, line_thickness)
	br_line.rotation = -PI / 4
	br_line.position = Vector2(-diamond_size * 0.35, diamond_size * 0.25)
	marker.add_child(br_line)
	
	# Bottom-left line
	var bl_line = ColorRect.new()
	bl_line.color = convergence_color
	bl_line.size = Vector2(diamond_size * 0.7, line_thickness)
	bl_line.rotation = PI / 4
	bl_line.position = Vector2(diamond_size * 0.35, diamond_size * 0.25)
	marker.add_child(bl_line)
	
	# Top-left line
	var tl_line = ColorRect.new()
	tl_line.color = convergence_color
	tl_line.size = Vector2(diamond_size * 0.7, line_thickness)
	tl_line.rotation = -PI / 4
	tl_line.position = Vector2(diamond_size * 0.35, -diamond_size * 0.25)
	marker.add_child(tl_line)
	
	return marker

func _create_optimal_zone_display() -> Control:
	var zone_display = Control.new()
	zone_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return zone_display

## Set active weapons for convergence calculation
func set_weapons(weapons: Array[Node]) -> void:
	active_weapons = weapons.duplicate()
	weapon_convergence_data.clear()
	
	# Calculate convergence data for each weapon
	for weapon in weapons:
		var weapon_data = _calculate_weapon_convergence_data(weapon)
		weapon_convergence_data[weapon.get_instance_id()] = weapon_data
	
	# Update convergence display
	_calculate_multi_weapon_convergence()
	_update_visual_display()
	
	set_process(weapons.size() > 0)  # Only process when weapons are active

func _calculate_weapon_convergence_data(weapon: Node) -> Dictionary:
	var data = {}
	
	# Get weapon properties
	data["effective_range"] = _get_weapon_effective_range(weapon)
	data["optimal_range"] = _get_weapon_optimal_range(weapon)
	data["min_range"] = _get_weapon_min_range(weapon)
	data["weapon_type"] = _get_weapon_type(weapon)
	data["accuracy"] = _get_weapon_accuracy(weapon)
	data["spread"] = _get_weapon_spread(weapon)
	data["mount_position"] = _get_weapon_mount_position(weapon)
	
	return data

func _get_weapon_effective_range(weapon: Node) -> float:
	if weapon.has_method("get_effective_range"):
		return weapon.get_effective_range()
	elif weapon.has_property("effective_range"):
		return weapon.effective_range
	else:
		return 2000.0  # Default range

func _get_weapon_optimal_range(weapon: Node) -> float:
	if weapon.has_method("get_optimal_range"):
		return weapon.get_optimal_range()
	elif weapon.has_property("optimal_range"):
		return weapon.optimal_range
	else:
		return _get_weapon_effective_range(weapon) * 0.7  # 70% of effective range

func _get_weapon_min_range(weapon: Node) -> float:
	if weapon.has_method("get_min_range"):
		return weapon.get_min_range()
	elif weapon.has_property("min_range"):
		return weapon.min_range
	else:
		return 50.0  # Default minimum range

func _get_weapon_type(weapon: Node) -> String:
	if weapon.has_method("get_weapon_type"):
		return weapon.get_weapon_type()
	elif weapon.has_property("weapon_type"):
		return weapon.weapon_type
	else:
		return "energy"

func _get_weapon_accuracy(weapon: Node) -> float:
	if weapon.has_method("get_accuracy"):
		return weapon.get_accuracy()
	elif weapon.has_property("accuracy"):
		return weapon.accuracy
	else:
		return 1.0

func _get_weapon_spread(weapon: Node) -> float:
	if weapon.has_method("get_spread"):
		return weapon.get_spread()
	elif weapon.has_property("spread"):
		return weapon.spread
	else:
		return 0.05  # 5 degree default spread

func _get_weapon_mount_position(weapon: Node) -> Vector3:
	if weapon.has_method("get_mount_position"):
		return weapon.get_mount_position()
	elif weapon.has_property("mount_position"):
		return weapon.mount_position
	else:
		return Vector3.ZERO

## Calculate convergence point for multiple weapons
func _calculate_multi_weapon_convergence() -> void:
	if active_weapons.is_empty():
		current_convergence_point = Vector2.ZERO
		effective_range = 0.0
		return
	
	# Calculate convergence based on method
	var convergence_3d = Vector3.ZERO
	var total_range = 0.0
	var min_range = INF
	var max_range = 0.0
	
	match convergence_calculation_method:
		"average":
			convergence_3d = _calculate_average_convergence()
		"weighted_average":
			convergence_3d = _calculate_weighted_convergence()
		"closest_weapon":
			convergence_3d = _calculate_closest_weapon_convergence()
		_:
			convergence_3d = _calculate_weighted_convergence()
	
	# Calculate effective range bounds
	for weapon in active_weapons:
		var weapon_id = weapon.get_instance_id()
		if weapon_convergence_data.has(weapon_id):
			var data = weapon_convergence_data[weapon_id]
			total_range += data["optimal_range"]
			min_range = min(min_range, data["min_range"])
			max_range = max(max_range, data["effective_range"])
	
	# Set convergence data
	optimal_firing_range = total_range / active_weapons.size()
	min_effective_range = min_range if min_range != INF else 0.0
	max_effective_range = max_range
	effective_range = optimal_firing_range
	
	# Project to screen coordinates
	current_convergence_point = _project_3d_to_screen(convergence_3d)
	
	# Emit signals
	convergence_point_updated.emit(current_convergence_point, effective_range)
	optimal_range_changed.emit(min_effective_range, max_effective_range, optimal_firing_range)
	
	var convergence_data = {
		"convergence_point": convergence_3d,
		"optimal_range": optimal_firing_range,
		"min_range": min_effective_range,
		"max_range": max_effective_range,
		"weapon_count": active_weapons.size()
	}
	multi_weapon_convergence_calculated.emit(convergence_data)

func _calculate_average_convergence() -> Vector3:
	var player_pos = _get_player_position()
	var forward_dir = _get_player_forward_direction()
	
	var total_range = 0.0
	for weapon in active_weapons:
		var weapon_id = weapon.get_instance_id()
		if weapon_convergence_data.has(weapon_id):
			total_range += weapon_convergence_data[weapon_id]["optimal_range"]
	
	var average_range = total_range / active_weapons.size()
	return player_pos + forward_dir * average_range

func _calculate_weighted_convergence() -> Vector3:
	var player_pos = _get_player_position()
	var forward_dir = _get_player_forward_direction()
	
	var weighted_range = 0.0
	var total_weight = 0.0
	
	for weapon in active_weapons:
		var weapon_id = weapon.get_instance_id()
		if weapon_convergence_data.has(weapon_id):
			var data = weapon_convergence_data[weapon_id]
			var weight = data["accuracy"]  # Use accuracy as weight
			weighted_range += data["optimal_range"] * weight
			total_weight += weight
	
	var final_range = weighted_range / max(total_weight, 1.0)
	return player_pos + forward_dir * final_range

func _calculate_closest_weapon_convergence() -> Vector3:
	var player_pos = _get_player_position()
	var forward_dir = _get_player_forward_direction()
	
	var closest_range = INF
	for weapon in active_weapons:
		var weapon_id = weapon.get_instance_id()
		if weapon_convergence_data.has(weapon_id):
			var data = weapon_convergence_data[weapon_id]
			closest_range = min(closest_range, data["optimal_range"])
	
	return player_pos + forward_dir * closest_range

func _get_player_position() -> Vector3:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_global_position"):
		return player.get_global_position()
	return Vector3.ZERO

func _get_player_forward_direction() -> Vector3:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_global_transform"):
		return -player.get_global_transform().basis.z
	return Vector3(0, 0, -1)

func _project_3d_to_screen(point_3d: Vector3) -> Vector2:
	var camera = get_viewport().get_camera_3d()
	if camera:
		return camera.unproject_position(point_3d)
	return Vector2.ZERO

## Update visual display elements
func _update_visual_display() -> void:
	if current_convergence_point == Vector2.ZERO:
		visible = false
		return
	
	visible = true
	
	# Update convergence marker position
	if convergence_marker:
		var marker_pos = current_convergence_point - Vector2(convergence_marker_size/2, convergence_marker_size/2)
		convergence_marker.position = marker_pos
		
		# Apply pulsing animation if enabled
		if convergence_pulse_enabled:
			_apply_convergence_pulse()
	
	# Update range indicators
	_update_range_indicators()
	
	# Update optimal zone display
	if show_optimal_zone:
		_update_optimal_zone()
	
	# Update weapon cone displays
	if show_weapon_cones:
		_update_weapon_cones()

func _apply_convergence_pulse() -> void:
	if not convergence_marker:
		return
	
	var tween = create_tween()
	tween.set_loops()
	var pulse_scale = 1.2
	tween.tween_property(convergence_marker, "scale", Vector2(pulse_scale, pulse_scale), 1.0 / pulse_frequency)
	tween.tween_property(convergence_marker, "scale", Vector2(1.0, 1.0), 1.0 / pulse_frequency)

func _update_range_indicators() -> void:
	# Clear existing range indicators
	for indicator in range_indicators:
		indicator.queue_free()
	range_indicators.clear()
	
	# Create range rings for min, optimal, and max ranges
	var ranges_to_show = []
	
	if min_effective_range > 0:
		ranges_to_show.append({"range": min_effective_range, "color": Color.RED, "label": "MIN"})
	
	ranges_to_show.append({"range": optimal_firing_range, "color": optimal_zone_color, "label": "OPT"})
	
	if max_effective_range > optimal_firing_range:
		ranges_to_show.append({"range": max_effective_range, "color": range_indicator_color, "label": "MAX"})
	
	# Create visual range indicators
	for range_data in ranges_to_show:
		var indicator = _create_range_indicator(range_data["range"], range_data["color"], range_data["label"])
		if indicator:
			range_indicators.append(indicator)
			add_child(indicator)

func _create_range_indicator(range_value: float, color: Color, label: String) -> Control:
	# Calculate screen radius for range
	var screen_radius = _calculate_screen_radius_for_range(range_value)
	if screen_radius < 10.0 or screen_radius > get_viewport().get_visible_rect().size.x:
		return null  # Range too small or too large to display
	
	var indicator = Control.new()
	indicator.position = current_convergence_point - Vector2(screen_radius, screen_radius)
	indicator.size = Vector2(screen_radius * 2, screen_radius * 2)
	
	# Create range ring (simplified as circle outline)
	var ring_segments = 32
	var ring_line = Line2D.new()
	ring_line.width = range_ring_thickness
	ring_line.default_color = color
	
	for i in range(ring_segments + 1):
		var angle = (i * 2.0 * PI) / ring_segments
		var point = Vector2(cos(angle), sin(angle)) * screen_radius + Vector2(screen_radius, screen_radius)
		ring_line.add_point(point)
	
	indicator.add_child(ring_line)
	
	# Add range label
	var range_label = Label.new()
	range_label.text = label
	range_label.add_theme_color_override("font_color", color)
	range_label.position = Vector2(screen_radius + 10, screen_radius - 10)
	indicator.add_child(range_label)
	
	return indicator

func _calculate_screen_radius_for_range(range_3d: float) -> float:
	# Calculate approximate screen radius for a 3D range
	# This is a simplified calculation - in a full implementation would use proper projection
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return 50.0
	
	var player_pos = _get_player_position()
	var range_point_3d = player_pos + Vector3(range_3d, 0, 0)
	var range_point_screen = camera.unproject_position(range_point_3d)
	var player_screen = camera.unproject_position(player_pos)
	
	return player_screen.distance_to(range_point_screen)

func _update_optimal_zone() -> void:
	# Clear existing optimal zone display
	for child in optimal_zone_display.get_children():
		child.queue_free()
	
	# Create optimal firing zone visualization
	var zone_inner_radius = _calculate_screen_radius_for_range(optimal_firing_range * 0.8)
	var zone_outer_radius = _calculate_screen_radius_for_range(optimal_firing_range * 1.2)
	
	if zone_inner_radius > 0 and zone_outer_radius > zone_inner_radius:
		var zone_visual = _create_optimal_zone_visual(zone_inner_radius, zone_outer_radius)
		optimal_zone_display.add_child(zone_visual)

func _create_optimal_zone_visual(inner_radius: float, outer_radius: float) -> Control:
	var zone = Control.new()
	zone.position = current_convergence_point - Vector2(outer_radius, outer_radius)
	zone.size = Vector2(outer_radius * 2, outer_radius * 2)
	
	# Create zone ring
	var zone_ring = Line2D.new()
	zone_ring.width = outer_radius - inner_radius
	zone_ring.default_color = Color(optimal_zone_color.r, optimal_zone_color.g, optimal_zone_color.b, 0.3)
	
	var segments = 24
	for i in range(segments + 1):
		var angle = (i * 2.0 * PI) / segments
		var radius = (inner_radius + outer_radius) / 2
		var point = Vector2(cos(angle), sin(angle)) * radius + Vector2(outer_radius, outer_radius)
		zone_ring.add_point(point)
	
	zone.add_child(zone_ring)
	return zone

func _update_weapon_cones() -> void:
	# Clear existing weapon cone displays
	for cone in weapon_cone_displays:
		cone.queue_free()
	weapon_cone_displays.clear()
	
	# Create weapon cone displays for each weapon
	for weapon in active_weapons:
		var weapon_id = weapon.get_instance_id()
		if weapon_convergence_data.has(weapon_id):
			var cone = _create_weapon_cone_display(weapon_convergence_data[weapon_id])
			if cone:
				weapon_cone_displays.append(cone)
				add_child(cone)

func _create_weapon_cone_display(weapon_data: Dictionary) -> Control:
	# Create weapon firing cone visualization
	var cone = Control.new()
	cone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var spread_angle = weapon_data.get("spread", 0.05)
	var weapon_range = weapon_data.get("optimal_range", 1000.0)
	
	# Create cone lines
	var cone_line = Line2D.new()
	cone_line.width = 1.0
	cone_line.default_color = Color(weapon_cone_color.r, weapon_cone_color.g, weapon_cone_color.b, 0.4)
	
	# Calculate cone points
	var player_screen = _project_3d_to_screen(_get_player_position())
	var cone_end_left = _project_3d_to_screen(_get_player_position() + _get_player_forward_direction() * weapon_range + Vector3(sin(spread_angle), 0, 0) * weapon_range)
	var cone_end_right = _project_3d_to_screen(_get_player_position() + _get_player_forward_direction() * weapon_range + Vector3(-sin(spread_angle), 0, 0) * weapon_range)
	
	cone_line.add_point(player_screen)
	cone_line.add_point(cone_end_left)
	cone_line.add_point(cone_end_right)
	cone_line.add_point(player_screen)
	
	cone.add_child(cone_line)
	return cone

## Configure convergence display settings
func configure_convergence_display(config: Dictionary) -> void:
	if config.has("convergence_marker_size"):
		convergence_marker_size = config["convergence_marker_size"]
	
	if config.has("convergence_color"):
		convergence_color = config["convergence_color"]
		_update_marker_colors()
	
	if config.has("optimal_zone_color"):
		optimal_zone_color = config["optimal_zone_color"]
	
	if config.has("range_indicator_color"):
		range_indicator_color = config["range_indicator_color"]
	
	if config.has("show_weapon_cones"):
		show_weapon_cones = config["show_weapon_cones"]
	
	if config.has("show_optimal_zone"):
		show_optimal_zone = config["show_optimal_zone"]
	
	if config.has("convergence_calculation_method"):
		convergence_calculation_method = config["convergence_calculation_method"]
		_calculate_multi_weapon_convergence()
	
	if config.has("convergence_pulse_enabled"):
		convergence_pulse_enabled = config["convergence_pulse_enabled"]
	
	_update_visual_display()
	print("ConvergenceDisplay: Configuration updated")

func _update_marker_colors() -> void:
	if convergence_marker:
		for child in convergence_marker.get_children():
			if child is ColorRect:
				child.color = convergence_color

## Get convergence display status
func get_convergence_status() -> Dictionary:
	return {
		"visible": visible,
		"convergence_point": current_convergence_point,
		"effective_range": effective_range,
		"optimal_range": optimal_firing_range,
		"min_range": min_effective_range,
		"max_range": max_effective_range,
		"active_weapons": active_weapons.size(),
		"calculation_method": convergence_calculation_method,
		"range_indicators": range_indicators.size(),
		"weapon_cones": weapon_cone_displays.size()
	}

func _process(delta: float) -> void:
	# Update convergence calculations and display
	if active_weapons.size() > 0:
		_calculate_multi_weapon_convergence()
		_update_visual_display()