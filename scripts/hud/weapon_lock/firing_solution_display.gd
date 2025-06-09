class_name FiringSolutionDisplay
extends Node2D

## Visual firing solution information display for HUD-007
## Shows detailed firing solution data including lead calculations,
## hit probability, time to impact, and optimal firing windows

# Firing solution data structure
class FiringSolution:
	var is_valid: bool = false
	var target_position: Vector3 = Vector3.ZERO
	var target_velocity: Vector3 = Vector3.ZERO
	var intercept_position: Vector3 = Vector3.ZERO
	var time_to_impact: float = 0.0
	var hit_probability: float = 0.0
	var weapon_range: float = 0.0
	var target_distance: float = 0.0
	var convergence_distance: float = 0.0
	var optimal_firing_window: bool = false
	var leading_required: bool = false

# Display modes
enum DisplayMode {
	OFF,			# No display
	BASIC,			# Basic firing data
	ADVANCED,		# Advanced ballistics
	TACTICAL		# Full tactical display
}

# Color coding for solution quality
enum SolutionQuality {
	EXCELLENT,		# >90% hit probability
	GOOD,			# 70-90% hit probability
	FAIR,			# 40-70% hit probability
	POOR,			# 10-40% hit probability
	IMPOSSIBLE		# <10% hit probability
}

# Display configuration
@export_group("Display Configuration")
@export var display_mode: DisplayMode = DisplayMode.ADVANCED
@export var show_intercept_point: bool = true
@export var show_weapon_convergence: bool = true
@export var show_hit_probability: bool = true
@export var show_time_to_impact: bool = true
@export var show_optimal_firing_window: bool = true

# Visual settings
@export_group("Visual Settings")
@export var solution_line_width: float = 2.0
@export var intercept_marker_size: float = 8.0
@export var convergence_marker_size: float = 6.0
@export var text_background_alpha: float = 0.7
@export var info_panel_width: float = 200.0
@export var info_panel_height: float = 120.0

# Color settings
@export_group("Colors")
@export var color_excellent: Color = Color.GREEN
@export var color_good: Color = Color.LIME_GREEN
@export var color_fair: Color = Color.YELLOW
@export var color_poor: Color = Color.ORANGE
@export var color_impossible: Color = Color.RED
@export var color_convergence: Color = Color.CYAN
@export var color_background: Color = Color(0.0, 0.0, 0.0, 0.7)

# Screen positioning
@export_group("Positioning")
@export var info_panel_position: Vector2 = Vector2(50, 50)
@export var intercept_screen_position: Vector2 = Vector2.ZERO
@export var convergence_screen_position: Vector2 = Vector2.ZERO

# Current firing solution
var current_solution: FiringSolution = FiringSolution.new()
var solution_quality: SolutionQuality = SolutionQuality.IMPOSSIBLE
var solution_update_time: float = 0.0

# References
var player_ship: Node3D = null
var current_target: Node3D = null
var weapon_manager: Node = null
var camera: Camera3D = null

# Animation
var _flash_time: float = 0.0
var _flash_state: bool = false

func _ready() -> void:
	set_process(true)
	_initialize_firing_solution_display()

## Initialize firing solution display
func _initialize_firing_solution_display() -> bool:
	"""Initialize firing solution display system."""
	# Get player ship reference
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		player_ship = player_nodes[0]
		
		# Get weapon manager
		if player_ship.has_method("get_weapon_manager"):
			weapon_manager = player_ship.get_weapon_manager()
		
		# Get camera reference
		camera = get_viewport().get_camera_3d()
		
		return true
	
	push_error("FiringSolutionDisplay: Cannot initialize without player ship")
	return false

## Update firing solution with new data
func update_firing_solution(firing_data: Dictionary) -> void:
	"""Update firing solution with weapon system data."""
	if not firing_data:
		current_solution.is_valid = false
		queue_redraw()
		return
	
	# Update solution data
	current_solution.is_valid = firing_data.get("is_valid", false)
	current_solution.target_position = firing_data.get("target_position", Vector3.ZERO)
	current_solution.target_velocity = firing_data.get("target_velocity", Vector3.ZERO)
	current_solution.intercept_position = firing_data.get("intercept_position", Vector3.ZERO)
	current_solution.time_to_impact = firing_data.get("time_to_impact", 0.0)
	current_solution.hit_probability = firing_data.get("hit_probability", 0.0)
	current_solution.weapon_range = firing_data.get("weapon_range", 0.0)
	current_solution.target_distance = firing_data.get("target_distance", 0.0)
	current_solution.convergence_distance = firing_data.get("convergence_distance", 0.0)
	current_solution.optimal_firing_window = firing_data.get("optimal_firing_window", false)
	current_solution.leading_required = firing_data.get("leading_required", false)
	
	# Update solution quality
	_update_solution_quality()
	
	# Update screen positions
	_update_screen_positions()
	
	# Record update time
	solution_update_time = Time.get_ticks_msec() / 1000.0
	
	queue_redraw()

## Update solution quality rating
func _update_solution_quality() -> void:
	"""Update solution quality based on hit probability."""
	var hit_prob: float = current_solution.hit_probability
	
	if hit_prob >= 0.9:
		solution_quality = SolutionQuality.EXCELLENT
	elif hit_prob >= 0.7:
		solution_quality = SolutionQuality.GOOD
	elif hit_prob >= 0.4:
		solution_quality = SolutionQuality.FAIR
	elif hit_prob >= 0.1:
		solution_quality = SolutionQuality.POOR
	else:
		solution_quality = SolutionQuality.IMPOSSIBLE

## Update screen positions for 3D points
func _update_screen_positions() -> void:
	"""Update 2D screen positions from 3D world coordinates."""
	if not camera:
		return
	
	# Convert intercept position to screen coordinates
	if current_solution.intercept_position != Vector3.ZERO:
		intercept_screen_position = camera.unproject_position(current_solution.intercept_position)
	
	# Calculate weapon convergence screen position
	if current_solution.convergence_distance > 0.0 and player_ship:
		var convergence_world_pos: Vector3 = player_ship.global_position + \
			(-player_ship.global_transform.basis.z * current_solution.convergence_distance)
		convergence_screen_position = camera.unproject_position(convergence_world_pos)

## Main drawing method
func _draw() -> void:
	"""Main drawing method for firing solution display."""
	if display_mode == DisplayMode.OFF or not current_solution.is_valid:
		return
	
	# Draw based on display mode
	match display_mode:
		DisplayMode.BASIC:
			_draw_basic_solution()
		DisplayMode.ADVANCED:
			_draw_advanced_solution()
		DisplayMode.TACTICAL:
			_draw_tactical_solution()

## Draw basic firing solution
func _draw_basic_solution() -> void:
	"""Draw basic firing solution information."""
	var solution_color: Color = _get_solution_color()
	
	# Draw intercept marker if valid
	if show_intercept_point and intercept_screen_position != Vector2.ZERO:
		_draw_intercept_marker(intercept_screen_position, solution_color)
	
	# Draw basic info panel
	if info_panel_position != Vector2.ZERO:
		_draw_basic_info_panel(info_panel_position, solution_color)

## Draw advanced firing solution
func _draw_advanced_solution() -> void:
	"""Draw advanced firing solution with ballistics."""
	var solution_color: Color = _get_solution_color()
	
	# Draw all basic elements
	_draw_basic_solution()
	
	# Draw weapon convergence if enabled
	if show_weapon_convergence and convergence_screen_position != Vector2.ZERO:
		_draw_convergence_marker(convergence_screen_position)
	
	# Draw firing solution line
	if show_intercept_point:
		_draw_solution_line(solution_color)
	
	# Draw advanced info panel
	_draw_advanced_info_panel(info_panel_position, solution_color)

## Draw tactical firing solution
func _draw_tactical_solution() -> void:
	"""Draw full tactical firing solution display."""
	# Draw all advanced elements
	_draw_advanced_solution()
	
	var solution_color: Color = _get_solution_color()
	
	# Draw optimal firing window indicator
	if show_optimal_firing_window and current_solution.optimal_firing_window:
		_draw_optimal_firing_indicator(solution_color)
	
	# Draw tactical info panel
	_draw_tactical_info_panel(info_panel_position, solution_color)

## Draw intercept marker
func _draw_intercept_marker(position: Vector2, color: Color) -> void:
	"""Draw intercept point marker."""
	var size: float = intercept_marker_size
	
	# Draw diamond marker
	var points: PackedVector2Array = PackedVector2Array([
		position + Vector2(0, -size),
		position + Vector2(size, 0),
		position + Vector2(0, size),
		position + Vector2(-size, 0)
	])
	
	# Flash if in optimal firing window
	if current_solution.optimal_firing_window and _flash_state:
		draw_colored_polygon(points, color)
	else:
		var closed_points = points.duplicate()
		closed_points.append(points[0])
		draw_polyline(closed_points, color, solution_line_width)
	
	# Draw center dot
	draw_circle(position, 2, color)

## Draw weapon convergence marker
func _draw_convergence_marker(position: Vector2) -> void:
	"""Draw weapon convergence point marker."""
	var size: float = convergence_marker_size
	var color: Color = color_convergence
	
	# Draw plus sign
	draw_line(position - Vector2(size, 0), position + Vector2(size, 0), color, 2.0)
	draw_line(position - Vector2(0, size), position + Vector2(0, size), color, 2.0)
	
	# Draw outer circle
	draw_arc(position, size + 3, 0, TAU, 16, color, 1.0)

## Draw firing solution line
func _draw_solution_line(color: Color) -> void:
	"""Draw line from ship to intercept point."""
	if not player_ship or not camera:
		return
	
	var ship_screen_pos: Vector2 = camera.unproject_position(player_ship.global_position)
	
	# Draw dashed line to intercept
	if intercept_screen_position != Vector2.ZERO:
		_draw_dashed_line(ship_screen_pos, intercept_screen_position, color, 8.0, 4.0)

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
		
		draw_line(start_pos, end_pos, color, solution_line_width)
		current_distance += segment_length

## Draw optimal firing window indicator
func _draw_optimal_firing_indicator(color: Color) -> void:
	"""Draw optimal firing window indicator."""
	if not intercept_screen_position:
		return
	
	var indicator_size: float = intercept_marker_size + 10
	
	# Draw pulsing ring
	var pulse_scale: float = 1.0 + 0.3 * sin(_flash_time * 6.0)
	var ring_radius: float = indicator_size * pulse_scale
	
	draw_arc(intercept_screen_position, ring_radius, 0, TAU, 32, color, 2.0)
	
	# Draw corners
	for i in range(4):
		var angle: float = i * PI/2 + PI/4
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var corner_start: Vector2 = intercept_screen_position + dir * (ring_radius + 5)
		var corner_end: Vector2 = corner_start + dir * 8
		draw_line(corner_start, corner_end, color, 3.0)

## Draw basic info panel
func _draw_basic_info_panel(position: Vector2, color: Color) -> void:
	"""Draw basic firing solution info panel."""
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	var panel_rect := Rect2(position, Vector2(150, 60))
	
	# Draw background
	draw_rect(panel_rect, color_background)
	draw_rect(panel_rect, color, false, 1.0)
	
	var text_pos: Vector2 = position + Vector2(5, font_size + 5)
	var line_height: float = font_size + 2
	
	# Hit probability
	if show_hit_probability:
		var hit_text: String = "HIT: %d%%" % int(current_solution.hit_probability * 100)
		draw_string(font, text_pos, hit_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		text_pos.y += line_height
	
	# Time to impact
	if show_time_to_impact and current_solution.time_to_impact > 0.0:
		var tti_text: String = "TTI: %.1fs" % current_solution.time_to_impact
		draw_string(font, text_pos, tti_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

## Draw advanced info panel
func _draw_advanced_info_panel(position: Vector2, color: Color) -> void:
	"""Draw advanced firing solution info panel."""
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	var panel_rect := Rect2(position, Vector2(180, 90))
	
	# Draw background
	draw_rect(panel_rect, color_background)
	draw_rect(panel_rect, color, false, 1.0)
	
	var text_pos: Vector2 = position + Vector2(5, font_size + 5)
	var line_height: float = font_size + 2
	
	# Draw all basic info
	_draw_basic_info_panel(position, color)
	
	# Add advanced info
	text_pos.y = position.y + 65
	
	# Target distance
	var distance_text: String = "RNG: %.0fm" % current_solution.target_distance
	draw_string(font, text_pos, distance_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	text_pos.y += line_height
	
	# Leading indicator
	if current_solution.leading_required:
		draw_string(font, text_pos, "LEAD REQ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)

## Draw tactical info panel
func _draw_tactical_info_panel(position: Vector2, color: Color) -> void:
	"""Draw full tactical firing solution info panel."""
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	var panel_rect := Rect2(position, Vector2(info_panel_width, info_panel_height))
	
	# Draw background
	draw_rect(panel_rect, color_background)
	draw_rect(panel_rect, color, false, 1.0)
	
	var text_pos: Vector2 = position + Vector2(5, font_size + 5)
	var line_height: float = font_size + 2
	
	# Solution quality header
	var quality_text: String = "SOLUTION: " + SolutionQuality.keys()[solution_quality]
	var quality_color: Color = _get_solution_color()
	draw_string(font, text_pos, quality_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, quality_color)
	text_pos.y += line_height + 3
	
	# Hit probability with bar
	var hit_prob: float = current_solution.hit_probability
	var hit_text: String = "HIT: %d%%" % int(hit_prob * 100)
	draw_string(font, text_pos, hit_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	
	# Hit probability bar
	var bar_pos: Vector2 = Vector2(text_pos.x + 80, text_pos.y - font_size + 2)
	var bar_size: Vector2 = Vector2(60, font_size - 4)
	draw_rect(Rect2(bar_pos, bar_size), Color.BLACK, true)
	draw_rect(Rect2(bar_pos, Vector2(bar_size.x * hit_prob, bar_size.y)), quality_color, true)
	draw_rect(Rect2(bar_pos, bar_size), Color.WHITE, false, 1.0)
	
	text_pos.y += line_height
	
	# Time to impact
	if current_solution.time_to_impact > 0.0:
		var tti_text: String = "TTI: %.1fs" % current_solution.time_to_impact
		draw_string(font, text_pos, tti_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		text_pos.y += line_height
	
	# Target distance and velocity
	var distance_text: String = "RNG: %.0fm" % current_solution.target_distance
	draw_string(font, text_pos, distance_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	text_pos.y += line_height
	
	var velocity_mag: float = current_solution.target_velocity.length()
	var velocity_text: String = "TGT SPD: %.0fm/s" % velocity_mag
	draw_string(font, text_pos, velocity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	text_pos.y += line_height
	
	# Weapon convergence
	if current_solution.convergence_distance > 0.0:
		var conv_text: String = "CONV: %.0fm" % current_solution.convergence_distance
		draw_string(font, text_pos, conv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color_convergence)
		text_pos.y += line_height
	
	# Optimal firing window
	if current_solution.optimal_firing_window:
		var fire_color: Color = Color.GREEN if _flash_state else Color.LIME_GREEN
		draw_string(font, text_pos, "FIRE WINDOW", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fire_color)

## Get solution quality color
func _get_solution_color() -> Color:
	"""Get color based on solution quality."""
	match solution_quality:
		SolutionQuality.EXCELLENT:
			return color_excellent
		SolutionQuality.GOOD:
			return color_good
		SolutionQuality.FAIR:
			return color_fair
		SolutionQuality.POOR:
			return color_poor
		SolutionQuality.IMPOSSIBLE:
			return color_impossible
		_:
			return Color.WHITE

## Process updates
func _process(delta: float) -> void:
	"""Process firing solution display updates."""
	# Update flash animation
	_flash_time += delta
	_flash_state = fmod(_flash_time, 1.0) < 0.5
	
	# Check if solution is stale
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - solution_update_time > 1.0:  # 1 second timeout
		current_solution.is_valid = false
	
	# Update screen positions if camera moved
	if current_solution.is_valid:
		_update_screen_positions()
	
	# Redraw if animating
	if current_solution.optimal_firing_window or solution_quality != SolutionQuality.IMPOSSIBLE:
		queue_redraw()

## Public interface

## Set display mode
func set_display_mode(mode: DisplayMode) -> void:
	"""Set firing solution display mode."""
	display_mode = mode
	queue_redraw()

## Set target reference
func set_target(target: Node3D) -> void:
	"""Set current target reference."""
	current_target = target

## Enable/disable display elements
func set_display_elements(
	intercept: bool = true,
	convergence: bool = true,
	hit_prob: bool = true,
	tti: bool = true,
	firing_window: bool = true
) -> void:
	"""Configure which display elements are shown."""
	show_intercept_point = intercept
	show_weapon_convergence = convergence
	show_hit_probability = hit_prob
	show_time_to_impact = tti
	show_optimal_firing_window = firing_window
	queue_redraw()

## Set info panel position
func set_info_panel_position(position: Vector2) -> void:
	"""Set position for info panel."""
	info_panel_position = position
	queue_redraw()

## Get current firing solution data
func get_firing_solution() -> Dictionary:
	"""Get current firing solution data."""
	return {
		"is_valid": current_solution.is_valid,
		"hit_probability": current_solution.hit_probability,
		"time_to_impact": current_solution.time_to_impact,
		"target_distance": current_solution.target_distance,
		"solution_quality": solution_quality,
		"optimal_firing_window": current_solution.optimal_firing_window,
		"leading_required": current_solution.leading_required
	}

## Check if solution is valid
func has_valid_solution() -> bool:
	"""Check if current firing solution is valid."""
	return current_solution.is_valid

## Check if in optimal firing window
func is_optimal_firing_window() -> bool:
	"""Check if currently in optimal firing window."""
	return current_solution.is_valid and current_solution.optimal_firing_window

## Get solution quality rating
func get_solution_quality() -> SolutionQuality:
	"""Get current solution quality rating."""
	return solution_quality
