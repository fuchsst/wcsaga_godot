# HUDLeadIndicator - Lead Indicator Gauge for Weapon Aim Prediction
# Shows where to aim primary/secondary weapons to hit a moving target
# Port of hudtarget.cpp::hud_show_lead_indicator()

class_name HUDLeadIndicator
extends Control

# === CONSTANTS ===
const POLISH_ITERATIONS: int = 2 # Number of refinement iterations
const INDICATOR_SIZE: float = 20.0
const MIN_WEAPON_SPEED: float = 100.0

# === CONFIGURATION ===
@export var indicator_color: Color = Color(0.0, 1.0, 0.0, 0.8)
@export var in_range_color: Color = Color(0.2, 1.0, 0.2, 1.0)
@export var out_of_range_color: Color = Color(0.5, 0.5, 0.5, 0.6)

# === STATE ===
var _player: Node = null
var _target: Node = null
var _camera: Camera3D = null
var _lead_position: Vector3 = Vector3.ZERO
var _is_visible: bool = false
var _in_primary_range: bool = false
var _in_secondary_range: bool = false


func _ready() -> void:
	# Hide by default
	visible = false


func _process(_delta: float) -> void:
	if not _player or not _target or not is_instance_valid(_target):
		visible = false
		return

	_update_lead_indicator()


func _draw() -> void:
	if not _is_visible:
		return

	var center = size / 2.0
	var color = _get_indicator_color()

	# Draw lead indicator based on weapon range
	if _in_primary_range and _in_secondary_range:
		# Full indicator - in range of both
		_draw_full_indicator(center, color)
	elif _in_primary_range:
		# Outer ring only - primary range
		_draw_outer_ring(center, color)
	elif _in_secondary_range:
		# Center dot only - secondary range
		_draw_center_dot(center, color)
	else:
		# Out of range - dim indicator
		_draw_outer_ring(center, out_of_range_color)


func _draw_full_indicator(center: Vector2, color: Color) -> void:
	"""Draw full lead indicator with outer ring and center"""
	# Outer ring
	draw_arc(center, INDICATOR_SIZE, 0, TAU, 32, color, 2.0, true)
	# Center dot
	draw_circle(center, 3.0, color)
	# Cross lines
	draw_line(center - Vector2(8, 0), center + Vector2(8, 0), color, 1.5)
	draw_line(center - Vector2(0, 8), center + Vector2(0, 8), color, 1.5)


func _draw_outer_ring(center: Vector2, color: Color) -> void:
	"""Draw outer ring only"""
	draw_arc(center, INDICATOR_SIZE, 0, TAU, 32, color, 2.0, true)


func _draw_center_dot(center: Vector2, color: Color) -> void:
	"""Draw center dot only"""
	draw_circle(center, 4.0, color)


func _update_lead_indicator() -> void:
	"""Calculate and update lead indicator position"""
	_camera = get_viewport().get_camera_3d()
	if not _camera:
		visible = false
		return

	# Get weapon info from player
	var weapon_speed = _get_current_weapon_speed()
	var primary_range = _get_primary_weapon_range()
	var secondary_range = _get_secondary_weapon_range()

	if weapon_speed < MIN_WEAPON_SPEED:
		visible = false
		return

	# Calculate predicted target position
	var target_pos = _target.global_position
	var player_pos = _player.global_position
	var dist_to_target = player_pos.distance_to(target_pos)

	# Get target velocity
	var target_vel = _get_target_velocity()

	# Calculate initial time to target
	var time_to_target = dist_to_target / weapon_speed

	# Initial prediction
	var predicted_pos = target_pos + target_vel * time_to_target

	# Polish the prediction with iteration
	predicted_pos = _polish_predicted_position(
		target_pos, predicted_pos, player_pos, target_vel, weapon_speed
	)

	_lead_position = predicted_pos

	# Check if on screen
	if not _camera.is_position_behind(predicted_pos):
		var screen_pos = _camera.unproject_position(predicted_pos)
		var viewport_rect = get_viewport_rect()

		if viewport_rect.has_point(screen_pos):
			# Position the indicator
			position = screen_pos - size / 2.0
			visible = true
			_is_visible = true

			# Check weapon ranges
			_in_primary_range = dist_to_target < primary_range
			_in_secondary_range = dist_to_target < secondary_range

			queue_redraw()
			return

	visible = false
	_is_visible = false


func _polish_predicted_position(
	target_pos: Vector3,
	predicted_pos: Vector3,
	player_pos: Vector3,
	target_vel: Vector3,
	weapon_speed: float
) -> Vector3:
	"""
	Refine predicted position with multiple iterations.
	Port of polish_predicted_target_pos() from hudtarget.cpp
	"""
	var result = predicted_pos

	# Account for player velocity if available
	var player_vel = _get_player_velocity()
	var relative_vel = target_vel - player_vel

	for _i in range(POLISH_ITERATIONS):
		var dist = player_pos.distance_to(result)
		var time = dist / weapon_speed
		result = target_pos + relative_vel * time

	return result


func _get_current_weapon_speed() -> float:
	"""Get projectile speed of currently selected weapon"""
	if not _player:
		return 0.0

	# Try weapon system
	if "weapon_system" in _player and _player.weapon_system:
		var ws = _player.weapon_system
		if ws.has_method("get_current_weapon_speed"):
			return ws.get_current_weapon_speed()
		# Try to get from primary banks
		if "primary_banks" in ws and "current_primary_bank" in ws:
			var banks = ws.primary_banks
			var current = ws.current_primary_bank
			if current < banks.size() and banks[current]:
				var weapon = banks[current]
				if "weapon_data" in weapon and weapon.weapon_data:
					if "velocity" in weapon.weapon_data:
						return weapon.weapon_data.velocity

	# Default fallback
	return 800.0


func _get_primary_weapon_range() -> float:
	"""Get range of primary weapon"""
	if not _player or not "weapon_system" in _player:
		return 2000.0

	var ws = _player.weapon_system
	if ws and ws.has_method("get_primary_range"):
		return ws.get_primary_range()

	if ws and "primary_banks" in ws:
		var banks = ws.primary_banks
		if banks.size() > 0:
			var current = ws.current_primary_bank if "current_primary_bank" in ws else 0
			if current < banks.size() and banks[current]:
				if "weapon_data" in banks[current] and banks[current].weapon_data:
					if "range" in banks[current].weapon_data:
						return banks[current].weapon_data.range

	return 2000.0


func _get_secondary_weapon_range() -> float:
	"""Get range of secondary weapon"""
	if not _player or not "weapon_system" in _player:
		return 5000.0

	var ws = _player.weapon_system
	if ws and ws.has_method("get_secondary_range"):
		return ws.get_secondary_range()

	return 5000.0


func _get_target_velocity() -> Vector3:
	"""Get target's current velocity"""
	if not _target or not is_instance_valid(_target):
		return Vector3.ZERO

	if _target.has_method("get_velocity"):
		return _target.get_velocity()
	if "linear_velocity" in _target:
		return _target.linear_velocity
	if "velocity" in _target:
		return _target.velocity

	return Vector3.ZERO


func _get_player_velocity() -> Vector3:
	"""Get player's current velocity"""
	if not _player:
		return Vector3.ZERO

	if _player.has_method("get_velocity"):
		return _player.get_velocity()
	if "linear_velocity" in _player:
		return _player.linear_velocity
	if "velocity" in _player:
		return _player.velocity

	return Vector3.ZERO


func _get_indicator_color() -> Color:
	"""Get color based on range status"""
	if _in_primary_range and _in_secondary_range:
		return in_range_color
	if _in_primary_range or _in_secondary_range:
		return indicator_color
	return out_of_range_color


# === PUBLIC API ===

func set_player(player: Node) -> void:
	"""Set the player ship reference"""
	_player = player


func set_target(target: Node) -> void:
	"""Set the current target"""
	_target = target


func get_lead_position() -> Vector3:
	"""Get the calculated lead position in world space"""
	return _lead_position
