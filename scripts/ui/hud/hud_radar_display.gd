# HUDRadarDisplay - Radar Gauge for Situational Awareness
# Shows contacts as blips with IFF coloring and range-based brightness
# Port of radar/radar.cpp

class_name HUDRadarDisplay
extends Control

# Blip types matching legacy
enum BlipType {
	NORMAL_SHIP,
	BOMB,
	NAVBUOY_CARGO,
	JUMP_NODE,
	WARPING_SHIP,
	TAGGED_SHIP
}

# === CONSTANTS ===
const MAX_BLIPS: int = 64
const RADAR_RANGE_SHORT: float = 2000.0
const RADAR_RANGE_LONG: float = 10000.0
const RADAR_RANGE_INFINITY: float = 100000.0

const BLIP_RADIUS_NORMAL: float = 3.0
const BLIP_RADIUS_TARGET: float = 5.0

# === CONFIGURATION ===
@export var radar_range: float = RADAR_RANGE_LONG
@export var radar_radius: float = 60.0 # Pixel radius of radar display

@export_group("Colors")
@export var friendly_color: Color = Color(0.0, 0.8, 0.0, 1.0)
@export var hostile_color: Color = Color(1.0, 0.0, 0.0, 1.0)
@export var neutral_color: Color = Color(1.0, 1.0, 0.0, 1.0)
@export var bomb_color: Color = Color(1.0, 0.5, 0.0, 1.0)
@export var navbuoy_color: Color = Color(0.5, 0.5, 1.0, 0.8)
@export var jump_node_color: Color = Color(0.0, 1.0, 1.0, 0.8)
@export var current_target_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var dim_alpha: float = 0.5

# === STATE ===
var _player: Node = null
var _target: Node = null
var _blips: Array[Dictionary] = []
var _bright_range: float = 1500.0 # Range within which blips are bright
var _range_index: int = 1 # 0=short, 1=long, 2=infinity


func _ready() -> void:
	custom_minimum_size = Vector2(radar_radius * 2 + 20, radar_radius * 2 + 20)


func _process(_delta: float) -> void:
	if not _player:
		return

	_update_blips()
	queue_redraw()


func _draw() -> void:
	var center = size / 2.0

	# Draw radar background circle
	draw_circle(center, radar_radius, Color(0.0, 0.1, 0.0, 0.5))
	draw_arc(center, radar_radius, 0, TAU, 64, Color(0.0, 0.5, 0.0, 0.8), 1.0, true)

	# Draw range indicator cross
	var cross_color = Color(0.0, 0.3, 0.0, 0.5)
	draw_line(center - Vector2(radar_radius, 0), center + Vector2(radar_radius, 0), cross_color, 1.0)
	draw_line(center - Vector2(0, radar_radius), center + Vector2(0, radar_radius), cross_color, 1.0)

	# Draw player position (center dot)
	draw_circle(center, 2.0, Color(0.0, 1.0, 0.0, 1.0))

	# Draw all blips
	for blip in _blips:
		_draw_blip(center, blip)

	# Draw range text
	_draw_range_text()


func _update_blips() -> void:
	"""Update all radar blips from world objects"""
	_blips.clear()

	if not _player:
		return

	var player_pos = _player.global_position
	var player_basis = _player.global_transform.basis

	# Get all ships in the scene
	var ships = get_tree().get_nodes_in_group("ships")
	var bombs = get_tree().get_nodes_in_group("bombs")
	var jump_nodes = get_tree().get_nodes_in_group("jump_nodes")

	# Process ships
	for ship in ships:
		if ship == _player:
			continue
		if not is_instance_valid(ship):
			continue

		_add_blip_for_object(ship, player_pos, player_basis, BlipType.NORMAL_SHIP)

	# Process bombs/missiles
	for bomb in bombs:
		if not is_instance_valid(bomb):
			continue
		_add_blip_for_object(bomb, player_pos, player_basis, BlipType.BOMB)

	# Process jump nodes
	for node in jump_nodes:
		if not is_instance_valid(node):
			continue
		_add_blip_for_object(node, player_pos, player_basis, BlipType.JUMP_NODE)


func _add_blip_for_object(
	obj: Node3D, player_pos: Vector3, player_basis: Basis, blip_type: BlipType
) -> void:
	"""Add a blip for a given object"""
	var world_pos = obj.global_position
	var dist = player_pos.distance_to(world_pos)

	# Range check
	if dist > radar_range:
		return

	# Transform to player-relative coordinates
	var relative_pos = world_pos - player_pos
	var local_pos = player_basis.inverse() * relative_pos

	# Project to 2D radar space (top-down view)
	var radar_x = local_pos.x
	var radar_z = local_pos.z # Forward/backward in player space

	# Scale to radar display
	var scale_factor = radar_radius / radar_range
	var blip_x = radar_x * scale_factor
	var blip_y = - radar_z * scale_factor # Negative because forward is up

	# Clamp to radar bounds
	var blip_dist = Vector2(blip_x, blip_y).length()
	if blip_dist > radar_radius:
		var direction = Vector2(blip_x, blip_y).normalized()
		blip_x = direction.x * radar_radius
		blip_y = direction.y * radar_radius

	# Determine blip properties
	var is_bright = dist <= _bright_range
	var is_target = obj == _target
	var blip_color = _get_blip_color(obj, blip_type, is_bright)

	if is_target:
		blip_color = current_target_color

	_blips.append({
		"x": blip_x,
		"y": blip_y,
		"type": blip_type,
		"bright": is_bright,
		"is_target": is_target,
		"color": blip_color,
		"dist": dist
	})


func _get_blip_color(obj: Node, blip_type: BlipType, is_bright: bool) -> Color:
	"""Get color for a blip based on IFF and type"""
	var color: Color

	match blip_type:
		BlipType.BOMB:
			color = bomb_color
		BlipType.NAVBUOY_CARGO:
			color = navbuoy_color
		BlipType.JUMP_NODE:
			color = jump_node_color
		_:
			# Ship - use IFF
			color = _get_iff_color(obj)

	# Dim if out of bright range
	if not is_bright:
		color.a *= dim_alpha

	return color


func _get_iff_color(obj: Node) -> Color:
	"""Get IFF-based color for a ship"""
	if not _player:
		return neutral_color

	var iff_manager = _get_iff_manager()
	if not iff_manager:
		return neutral_color

	var player_team = _get_property(obj, "team", 0)
	var obj_team = _get_property(obj, "team", 0)

	if iff_manager.has_method("get_radar_color"):
		return iff_manager.get_radar_color(player_team, obj_team)
	if iff_manager.has_method("is_hostile"):
		if iff_manager.is_hostile(player_team, obj_team):
			return hostile_color
		if player_team == obj_team:
			return friendly_color

	return neutral_color


func _draw_blip(center: Vector2, blip: Dictionary) -> void:
	"""Draw a single blip on the radar"""
	var pos = center + Vector2(blip.x, blip.y)
	var color = blip.color as Color
	var radius = BLIP_RADIUS_TARGET if blip.is_target else BLIP_RADIUS_NORMAL

	# Draw blip
	draw_circle(pos, radius, color)

	# Draw target indicator
	if blip.is_target:
		draw_arc(pos, radius + 3, 0, TAU, 16, current_target_color, 1.5, true)


func _draw_range_text() -> void:
	"""Draw current range setting text"""
	var range_text: String
	match _range_index:
		0:
			range_text = "2k"
		1:
			range_text = "10k"
		2:
			range_text = "∞"
		_:
			range_text = ""

	# Position at bottom right of radar
	var pos = Vector2(size.x - 25, size.y - 10)
	draw_string(
		ThemeDB.fallback_font,
		pos,
		range_text,
		HORIZONTAL_ALIGNMENT_RIGHT,
		-1,
		10,
		Color(0.0, 1.0, 0.0, 0.8)
	)


func _get_property(obj: Node, prop: String, default = null):
	"""Safely get a property from an object"""
	if obj.has_method(prop):
		return obj.call(prop)
	if prop in obj:
		return obj.get(prop)
	return default


func _get_iff_manager() -> Node:
	"""Get IFFManager autoload"""
	if Engine.has_singleton("IFFManager"):
		return Engine.get_singleton("IFFManager")
	return null


# === PUBLIC API ===

func set_player(player: Node) -> void:
	"""Set the player ship reference"""
	_player = player
	# Calculate bright range from player weapons
	_update_bright_range()


func set_target(target: Node) -> void:
	"""Set the current target"""
	_target = target


func cycle_range() -> void:
	"""Cycle through radar range settings"""
	_range_index = (_range_index + 1) % 3
	match _range_index:
		0:
			radar_range = RADAR_RANGE_SHORT
		1:
			radar_range = RADAR_RANGE_LONG
		2:
			radar_range = RADAR_RANGE_INFINITY


func get_current_range() -> float:
	"""Get current radar range"""
	return radar_range


func _update_bright_range() -> void:
	"""Update bright range based on player weapon range"""
	if not _player:
		_bright_range = 1500.0
		return

	# Try to get from weapon system
	if "weapon_system" in _player and _player.weapon_system:
		var ws = _player.weapon_system
		if ws.has_method("get_primary_range"):
			_bright_range = ws.get_primary_range()
			return

	_bright_range = 1500.0
