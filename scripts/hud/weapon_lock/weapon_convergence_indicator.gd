class_name WeaponConvergenceIndicator
extends Node2D

## Visual weapon convergence display for HUD-007
## Shows weapon convergence points, firing patterns, and optimal engagement zones
## Helps players understand weapon grouping and effective firing distances

# Convergence display modes
enum ConvergenceMode {
	OFF,			# No convergence display
	BASIC,			# Basic convergence point
	DETAILED,		# Detailed convergence zones
	ADVANCED		# Advanced ballistics display
}

# Weapon group types
enum WeaponGroup {
	PRIMARY,		# Primary weapon group
	SECONDARY,		# Secondary weapon group
	TERTIARY,		# Tertiary weapon group
	ALL_WEAPONS		# All weapons combined
}

# Convergence quality levels
enum ConvergenceQuality {
	PERFECT,		# All weapons converge at same point
	EXCELLENT,		# Very tight convergence
	GOOD,			# Good convergence pattern
	FAIR,			# Acceptable convergence
	POOR,			# Poor convergence pattern
	UNUSABLE		# Weapons don't converge effectively
}

# Convergence data structure
class ConvergenceData:
	var convergence_distance: float = 1000.0
	var convergence_point: Vector3 = Vector3.ZERO
	var convergence_spread: float = 0.0
	var weapon_positions: Array[Vector3] = []
	var weapon_orientations: Array[Vector3] = []
	var weapon_ranges: Array[float] = []
	var optimal_range: float = 1000.0
	var quality: ConvergenceQuality = ConvergenceQuality.UNUSABLE

# Display configuration
@export_group("Display Configuration")
@export var convergence_mode: ConvergenceMode = ConvergenceMode.DETAILED
@export var show_weapon_groups: Array[WeaponGroup] = []
@export var show_convergence_point: bool = true
@export var show_convergence_zone: bool = true
@export var show_weapon_spread_pattern: bool = true
@export var show_optimal_range_indicator: bool = true

# Visual settings
@export_group("Visual Settings")
@export var convergence_point_size: float = 8.0
@export var convergence_zone_radius: float = 20.0
@export var weapon_line_width: float = 1.0
@export var spread_pattern_alpha: float = 0.5
@export var distance_text_size: int = 14

# Color settings
@export_group("Colors")
@export var color_perfect: Color = Color.GREEN
@export var color_excellent: Color = Color.LIME_GREEN
@export var color_good: Color = Color.YELLOW
@export var color_fair: Color = Color.ORANGE
@export var color_poor: Color = Color.RED
@export var color_unusable: Color = Color.DARK_RED
@export var color_weapon_lines: Color = Color.CYAN
@export var color_convergence_zone: Color = Color.WHITE
@export var color_optimal_range: Color = Color.LIME_GREEN

# Animation settings
@export_group("Animation")
@export var animate_convergence_point: bool = true
@export var animation_speed: float = 2.0
@export var pulse_amplitude: float = 0.3

# Current convergence data
var primary_convergence: ConvergenceData = ConvergenceData.new()
var secondary_convergence: ConvergenceData = ConvergenceData.new()
var tertiary_convergence: ConvergenceData = ConvergenceData.new()
var combined_convergence: ConvergenceData = ConvergenceData.new()

# Screen positions
var convergence_screen_positions: Dictionary = {}
var weapon_screen_positions: Array[Vector2] = []

# References
var player_ship: Node3D = null
var weapon_manager: Node = null
var camera: Camera3D = null

# Animation state
var _animation_time: float = 0.0
var _pulse_factor: float = 1.0

# Performance optimization
var update_frequency: float = 20.0  # Hz
var last_update_time: float = 0.0

func _ready() -> void:
	# Initialize default weapon groups
	show_weapon_groups = [WeaponGroup.PRIMARY, WeaponGroup.SECONDARY]
	
	set_process(true)
	_initialize_convergence_indicator()

## Initialize weapon convergence indicator
func _initialize_convergence_indicator() -> void:
	"""Initialize weapon convergence display system."""
	# Get player ship reference
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		player_ship = player_nodes[0]
		
		# Get weapon manager
		if player_ship.has_method("get_weapon_manager"):
			weapon_manager = player_ship.get_weapon_manager()
		
		# Get camera reference
		camera = get_viewport().get_camera_3d()

## Update convergence data with weapon system information
func update_convergence_data(weapon_data: Dictionary) -> void:
	"""Update convergence data with weapon system information."""
	if not weapon_data:
		return
	
	var current_time: float = Time.get_ticks_msec() / 1000.0
	
	# Limit update frequency for performance
	if current_time - last_update_time < (1.0 / update_frequency):
		return
	
	last_update_time = current_time
	
	# Update convergence data for each weapon group
	if weapon_data.has("primary_weapons"):
		_update_weapon_group_convergence(primary_convergence, weapon_data["primary_weapons"])
	
	if weapon_data.has("secondary_weapons"):
		_update_weapon_group_convergence(secondary_convergence, weapon_data["secondary_weapons"])
	
	if weapon_data.has("tertiary_weapons"):
		_update_weapon_group_convergence(tertiary_convergence, weapon_data["tertiary_weapons"])
	
	# Calculate combined convergence
	_calculate_combined_convergence()
	
	# Update screen positions
	_update_screen_positions()
	
	queue_redraw()

## Update weapon group convergence data
func _update_weapon_group_convergence(convergence_data: ConvergenceData, weapons_info: Array) -> void:
	"""Update convergence data for a specific weapon group."""
	if weapons_info.is_empty():
		convergence_data.quality = ConvergenceQuality.UNUSABLE
		return
	
	# Clear previous data
	convergence_data.weapon_positions.clear()
	convergence_data.weapon_orientations.clear()
	convergence_data.weapon_ranges.clear()
	
	# Collect weapon data
	var total_range: float = 0.0
	var weapon_count: int = 0
	
	for weapon_info in weapons_info:
		if not weapon_info is Dictionary:
			continue
		
		var weapon_pos: Vector3 = weapon_info.get("position", Vector3.ZERO)
		var weapon_orient: Vector3 = weapon_info.get("orientation", Vector3.FORWARD)
		var weapon_range: float = weapon_info.get("range", 1000.0)
		
		convergence_data.weapon_positions.append(weapon_pos)
		convergence_data.weapon_orientations.append(weapon_orient)
		convergence_data.weapon_ranges.append(weapon_range)
		
		total_range += weapon_range
		weapon_count += 1
	
	if weapon_count == 0:
		convergence_data.quality = ConvergenceQuality.UNUSABLE
		return
	
	# Calculate average weapon range
	var average_range: float = total_range / weapon_count
	convergence_data.optimal_range = average_range
	
	# Calculate convergence point
	_calculate_convergence_point(convergence_data)
	
	# Calculate convergence quality
	_calculate_convergence_quality(convergence_data)

## Calculate convergence point for weapon group
func _calculate_convergence_point(convergence_data: ConvergenceData) -> void:
	"""Calculate the convergence point for a weapon group."""
	if convergence_data.weapon_positions.is_empty():
		return
	
	# Use optimal range as convergence distance
	convergence_data.convergence_distance = convergence_data.optimal_range
	
	# Calculate convergence point in front of ship
	if player_ship:
		var ship_forward: Vector3 = -player_ship.global_transform.basis.z
		convergence_data.convergence_point = player_ship.global_position + \
			ship_forward * convergence_data.convergence_distance
	
	# Calculate spread at convergence distance
	_calculate_weapon_spread(convergence_data)

## Calculate weapon spread pattern
func _calculate_weapon_spread(convergence_data: ConvergenceData) -> void:
	"""Calculate weapon spread pattern at convergence distance."""
	if convergence_data.weapon_positions.size() < 2:
		convergence_data.convergence_spread = 0.0
		return
	
	var spread_points: Array[Vector3] = []
	
	# Project each weapon's aim point at convergence distance
	for i in range(convergence_data.weapon_positions.size()):
		var weapon_pos: Vector3 = convergence_data.weapon_positions[i]
		var weapon_orient: Vector3 = convergence_data.weapon_orientations[i]
		
		# Calculate where this weapon aims at convergence distance
		var aim_point: Vector3 = weapon_pos + weapon_orient * convergence_data.convergence_distance
		spread_points.append(aim_point)
	
	# Calculate spread as maximum distance between aim points
	var max_spread: float = 0.0
	for i in range(spread_points.size()):
		for j in range(i + 1, spread_points.size()):
			var distance: float = spread_points[i].distance_to(spread_points[j])
			max_spread = maxf(max_spread, distance)
	
	convergence_data.convergence_spread = max_spread

## Calculate convergence quality
func _calculate_convergence_quality(convergence_data: ConvergenceData) -> void:
	"""Calculate convergence quality rating."""
	if convergence_data.weapon_positions.size() < 2:
		convergence_data.quality = ConvergenceQuality.PERFECT
		return
	
	# Quality based on spread relative to convergence distance
	var spread_ratio: float = convergence_data.convergence_spread / convergence_data.convergence_distance
	
	if spread_ratio <= 0.01:  # 1% spread
		convergence_data.quality = ConvergenceQuality.PERFECT
	elif spread_ratio <= 0.02:  # 2% spread
		convergence_data.quality = ConvergenceQuality.EXCELLENT
	elif spread_ratio <= 0.05:  # 5% spread
		convergence_data.quality = ConvergenceQuality.GOOD
	elif spread_ratio <= 0.1:   # 10% spread
		convergence_data.quality = ConvergenceQuality.FAIR
	elif spread_ratio <= 0.2:   # 20% spread
		convergence_data.quality = ConvergenceQuality.POOR
	else:
		convergence_data.quality = ConvergenceQuality.UNUSABLE

## Calculate combined convergence for all weapons
func _calculate_combined_convergence() -> void:
	"""Calculate combined convergence for all weapon groups."""
	# Combine all weapon data
	combined_convergence.weapon_positions.clear()
	combined_convergence.weapon_orientations.clear()
	combined_convergence.weapon_ranges.clear()
	
	# Add primary weapons
	combined_convergence.weapon_positions.append_array(primary_convergence.weapon_positions)
	combined_convergence.weapon_orientations.append_array(primary_convergence.weapon_orientations)
	combined_convergence.weapon_ranges.append_array(primary_convergence.weapon_ranges)
	
	# Add secondary weapons
	combined_convergence.weapon_positions.append_array(secondary_convergence.weapon_positions)
	combined_convergence.weapon_orientations.append_array(secondary_convergence.weapon_orientations)
	combined_convergence.weapon_ranges.append_array(secondary_convergence.weapon_ranges)
	
	# Add tertiary weapons
	combined_convergence.weapon_positions.append_array(tertiary_convergence.weapon_positions)
	combined_convergence.weapon_orientations.append_array(tertiary_convergence.weapon_orientations)
	combined_convergence.weapon_ranges.append_array(tertiary_convergence.weapon_ranges)
	
	# Calculate combined convergence
	if not combined_convergence.weapon_positions.is_empty():
		var total_range: float = 0.0
		for range_val in combined_convergence.weapon_ranges:
			total_range += range_val
		combined_convergence.optimal_range = total_range / combined_convergence.weapon_ranges.size()
		
		_calculate_convergence_point(combined_convergence)
		_calculate_convergence_quality(combined_convergence)

## Update screen positions
func _update_screen_positions() -> void:
	"""Update 2D screen positions from 3D world coordinates."""
	if not camera:
		return
	
	convergence_screen_positions.clear()
	weapon_screen_positions.clear()
	
	# Convert convergence points to screen coordinates
	for group in WeaponGroup.values():
		var convergence_data: ConvergenceData = _get_convergence_data(group)
		if convergence_data.convergence_point != Vector3.ZERO:
			var screen_pos: Vector2 = camera.unproject_position(convergence_data.convergence_point)
			convergence_screen_positions[group] = screen_pos
	
	# Convert weapon positions to screen coordinates
	for weapon_pos in combined_convergence.weapon_positions:
		var screen_pos: Vector2 = camera.unproject_position(weapon_pos)
		weapon_screen_positions.append(screen_pos)

## Get convergence data for weapon group
func _get_convergence_data(group: WeaponGroup) -> ConvergenceData:
	"""Get convergence data for specific weapon group."""
	match group:
		WeaponGroup.PRIMARY:
			return primary_convergence
		WeaponGroup.SECONDARY:
			return secondary_convergence
		WeaponGroup.TERTIARY:
			return tertiary_convergence
		WeaponGroup.ALL_WEAPONS:
			return combined_convergence
		_:
			return ConvergenceData.new()

## Get quality color
func _get_quality_color(quality: ConvergenceQuality) -> Color:
	"""Get color based on convergence quality."""
	match quality:
		ConvergenceQuality.PERFECT:
			return color_perfect
		ConvergenceQuality.EXCELLENT:
			return color_excellent
		ConvergenceQuality.GOOD:
			return color_good
		ConvergenceQuality.FAIR:
			return color_fair
		ConvergenceQuality.POOR:
			return color_poor
		ConvergenceQuality.UNUSABLE:
			return color_unusable
		_:
			return Color.WHITE

## Main drawing method
func _draw() -> void:
	"""Main drawing method for convergence display."""
	if convergence_mode == ConvergenceMode.OFF:
		return
	
	# Draw based on display mode
	match convergence_mode:
		ConvergenceMode.BASIC:
			_draw_basic_convergence()
		ConvergenceMode.DETAILED:
			_draw_detailed_convergence()
		ConvergenceMode.ADVANCED:
			_draw_advanced_convergence()

## Draw basic convergence display
func _draw_basic_convergence() -> void:
	"""Draw basic convergence point display."""
	# Draw primary weapon convergence only
	if WeaponGroup.PRIMARY in show_weapon_groups:
		var screen_pos: Vector2 = convergence_screen_positions.get(WeaponGroup.PRIMARY, Vector2.ZERO)
		if screen_pos != Vector2.ZERO:
			var quality_color: Color = _get_quality_color(primary_convergence.quality)
			_draw_convergence_point(screen_pos, quality_color, primary_convergence.quality)

## Draw detailed convergence display
func _draw_detailed_convergence() -> void:
	"""Draw detailed convergence display with multiple weapon groups."""
	# Draw convergence for each enabled weapon group
	for group in show_weapon_groups:
		var screen_pos: Vector2 = convergence_screen_positions.get(group, Vector2.ZERO)
		if screen_pos == Vector2.ZERO:
			continue
		
		var convergence_data: ConvergenceData = _get_convergence_data(group)
		var quality_color: Color = _get_quality_color(convergence_data.quality)
		
		# Draw convergence point
		if show_convergence_point:
			_draw_convergence_point(screen_pos, quality_color, convergence_data.quality)
		
		# Draw convergence zone
		if show_convergence_zone:
			_draw_convergence_zone(screen_pos, quality_color, convergence_data)
		
		# Draw range indicator
		if show_optimal_range_indicator:
			_draw_range_indicator(screen_pos, convergence_data)

## Draw advanced convergence display
func _draw_advanced_convergence() -> void:
	"""Draw advanced convergence display with ballistics."""
	# Draw all detailed elements
	_draw_detailed_convergence()
	
	# Draw weapon spread pattern
	if show_weapon_spread_pattern:
		_draw_weapon_spread_pattern()
	
	# Draw weapon fire lines
	_draw_weapon_fire_lines()

## Draw convergence point
func _draw_convergence_point(position: Vector2, color: Color, quality: ConvergenceQuality) -> void:
	"""Draw convergence point marker."""
	var size: float = convergence_point_size
	
	# Animate point if enabled
	if animate_convergence_point:
		size *= _pulse_factor
	
	# Draw different shapes based on quality
	match quality:
		ConvergenceQuality.PERFECT, ConvergenceQuality.EXCELLENT:
			# Filled circle for excellent convergence
			draw_circle(position, size, color)
			draw_circle(position, size + 2, color, false, 2.0)
		
		ConvergenceQuality.GOOD, ConvergenceQuality.FAIR:
			# Circle with cross for good convergence
			draw_circle(position, size, Color.TRANSPARENT, false, 2.0)
			draw_circle(position, size, color, false, 2.0)
			draw_line(position - Vector2(size, 0), position + Vector2(size, 0), color, 2.0)
			draw_line(position - Vector2(0, size), position + Vector2(0, size), color, 2.0)
		
		ConvergenceQuality.POOR, ConvergenceQuality.UNUSABLE:
			# X mark for poor convergence
			var half_size: float = size * 0.7
			draw_line(position - Vector2(half_size, half_size), position + Vector2(half_size, half_size), color, 2.0)
			draw_line(position - Vector2(half_size, -half_size), position + Vector2(half_size, -half_size), color, 2.0)

## Draw convergence zone
func _draw_convergence_zone(position: Vector2, color: Color, convergence_data: ConvergenceData) -> void:
	"""Draw convergence zone indicator."""
	if convergence_data.convergence_spread <= 0.0:
		return
	
	# Calculate zone radius based on spread
	var base_radius: float = convergence_zone_radius
	var spread_factor: float = clampf(convergence_data.convergence_spread / 100.0, 0.5, 3.0)
	var zone_radius: float = base_radius * spread_factor
	
	# Draw zone circle
	var zone_color: Color = Color(color.r, color.g, color.b, 0.3)
	draw_arc(position, zone_radius, 0, TAU, 32, color, 2.0)
	
	# Draw zone fill
	var circle_points: PackedVector2Array = PackedVector2Array()
	for i in range(33):  # 32 segments + close
		var angle: float = i * TAU / 32.0
		circle_points.append(position + Vector2(cos(angle), sin(angle)) * zone_radius)
	
	if circle_points.size() > 2:
		draw_colored_polygon(circle_points, zone_color)

## Draw range indicator
func _draw_range_indicator(position: Vector2, convergence_data: ConvergenceData) -> void:
	"""Draw optimal range indicator."""
	var font := ThemeDB.fallback_font
	var font_size := distance_text_size
	
	var range_text: String = "%.0fm" % convergence_data.optimal_range
	var text_size: Vector2 = font.get_string_size(range_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = position + Vector2(-text_size.x / 2, convergence_point_size + text_size.y + 5)
	
	# Background for text
	var bg_rect: Rect2 = Rect2(text_pos - Vector2(2, text_size.y), text_size + Vector2(4, 2))
	draw_rect(bg_rect, Color(0, 0, 0, 0.7))
	
	# Range text
	draw_string(font, text_pos, range_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color_optimal_range)

## Draw weapon spread pattern
func _draw_weapon_spread_pattern() -> void:
	"""Draw weapon spread pattern visualization."""
	if weapon_screen_positions.size() < 2:
		return
	
	var spread_color: Color = Color(color_weapon_lines.r, color_weapon_lines.g, color_weapon_lines.b, spread_pattern_alpha)
	
	# Draw lines between weapon positions to show spread
	for i in range(weapon_screen_positions.size()):
		for j in range(i + 1, weapon_screen_positions.size()):
			draw_line(weapon_screen_positions[i], weapon_screen_positions[j], spread_color, 1.0)

## Draw weapon fire lines
func _draw_weapon_fire_lines() -> void:
	"""Draw weapon fire lines to convergence points."""
	if not player_ship or not camera:
		return
	
	var ship_screen_pos: Vector2 = camera.unproject_position(player_ship.global_position)
	
	# Draw lines from weapons to convergence points
	for group in show_weapon_groups:
		var convergence_pos: Vector2 = convergence_screen_positions.get(group, Vector2.ZERO)
		if convergence_pos == Vector2.ZERO:
			continue
		
		var convergence_data: ConvergenceData = _get_convergence_data(group)
		var quality_color: Color = _get_quality_color(convergence_data.quality)
		var line_color: Color = Color(quality_color.r, quality_color.g, quality_color.b, 0.4)
		
		# Draw dashed line from ship to convergence point
		_draw_dashed_line(ship_screen_pos, convergence_pos, line_color, 8.0, 4.0)

## Draw dashed line
func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, dash_length: float, gap_length: float) -> void:
	"""Draw a dashed line between two points."""
	var direction: Vector2 = (to - from).normalized()
	var total_distance: float = from.distance_to(to)
	var segment_length: float = dash_length + gap_length
	
	var current_distance: float = 0.0
	while current_distance < total_distance:
		var start_pos: Vector2 = from + direction * current_distance
		var end_distance: float = minf(current_distance + dash_length, total_distance)
		var end_pos: Vector2 = from + direction * end_distance
		
		draw_line(start_pos, end_pos, color, weapon_line_width)
		current_distance += segment_length

## Process animation updates
func _process(delta: float) -> void:
	"""Process convergence indicator animation updates."""
	# Update animation time
	_animation_time += delta * animation_speed
	
	# Calculate pulse factor for animated convergence points
	if animate_convergence_point:
		_pulse_factor = 1.0 + pulse_amplitude * sin(_animation_time)
	else:
		_pulse_factor = 1.0
	
	# Redraw if animating
	if animate_convergence_point:
		queue_redraw()

## Public interface

## Set convergence display mode
func set_convergence_mode(mode: ConvergenceMode) -> void:
	"""Set convergence display mode."""
	convergence_mode = mode
	queue_redraw()

## Set weapon groups to display
func set_weapon_groups_display(groups: Array[WeaponGroup]) -> void:
	"""Set which weapon groups to display."""
	show_weapon_groups = groups
	queue_redraw()

## Enable/disable display elements
func set_display_elements(
	point: bool = true,
	zone: bool = true,
	spread: bool = true,
	range: bool = true
) -> void:
	"""Configure which convergence elements are displayed."""
	show_convergence_point = point
	show_convergence_zone = zone
	show_weapon_spread_pattern = spread
	show_optimal_range_indicator = range
	queue_redraw()

## Get convergence information for weapon group
func get_convergence_info(group: WeaponGroup) -> Dictionary:
	"""Get convergence information for specific weapon group."""
	var convergence_data: ConvergenceData = _get_convergence_data(group)
	
	return {
		"convergence_distance": convergence_data.convergence_distance,
		"convergence_spread": convergence_data.convergence_spread,
		"optimal_range": convergence_data.optimal_range,
		"quality": convergence_data.quality,
		"weapon_count": convergence_data.weapon_positions.size(),
		"screen_position": convergence_screen_positions.get(group, Vector2.ZERO)
	}

## Get optimal firing range for weapon group
func get_optimal_firing_range(group: WeaponGroup) -> float:
	"""Get optimal firing range for weapon group."""
	var convergence_data: ConvergenceData = _get_convergence_data(group)
	return convergence_data.optimal_range

## Check if convergence is good for weapon group
func is_convergence_good(group: WeaponGroup) -> bool:
	"""Check if convergence is good enough for effective firing."""
	var convergence_data: ConvergenceData = _get_convergence_data(group)
	return convergence_data.quality in [ConvergenceQuality.PERFECT, ConvergenceQuality.EXCELLENT, ConvergenceQuality.GOOD]

## Get best weapon group for current target distance
func get_best_weapon_group_for_distance(target_distance: float) -> WeaponGroup:
	"""Get the best weapon group for a given target distance."""
	var best_group: WeaponGroup = WeaponGroup.PRIMARY
	var best_score: float = 0.0
	
	for group_enum in WeaponGroup.values():
		if group_enum == WeaponGroup.ALL_WEAPONS:
			continue
		var group: WeaponGroup = group_enum
		
		var convergence_data: ConvergenceData = _get_convergence_data(group)
		if convergence_data.quality == ConvergenceQuality.UNUSABLE:
			continue
		
		# Score based on how close target distance is to optimal range
		var range_diff: float = abs(target_distance - convergence_data.optimal_range)
		var range_score: float = 1.0 - (range_diff / convergence_data.optimal_range)
		
		# Factor in convergence quality
		var quality_score: float = float(ConvergenceQuality.values().size() - convergence_data.quality) / float(ConvergenceQuality.values().size())
		
		var total_score: float = (range_score + quality_score) / 2.0
		
		if total_score > best_score:
			best_score = total_score
			best_group = group
	
	return best_group
