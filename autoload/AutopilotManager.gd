# AutopilotManager - Autopilot System Controller
# Manages navigation points, autopilot engagement, and time compression
# Integrates with AIController for ship navigation, IFFManager for hostiles

extends Node


## Signals
signal nav_selected(nav_index: int)
signal nav_deselected()
signal autopilot_started()
signal autopilot_stopped()
signal nav_visited(nav_index: int)

## Message types for autopilot feedback
enum MessageType {
	FAIL_NO_SELECTION,
	FAIL_GLIDING,
	FAIL_TOO_CLOSE,
	FAIL_HOSTILES,
	FAIL_HAZARD,
	MISC_LINKED,
}

# ==============================================================================
# CONSTANTS
# ==============================================================================

const NavPointRes = preload("res://scripts/resources/navigation/nav_point.gd")
const MAX_NAVPOINTS := 8
const TICK_RATE := 0.125
const MIN_NAV_DISTANCE := 1000.0
const HOSTILE_RANGE := 5000.0
const ASTEROID_RANGE := 1000.0
const VISITED_RANGE := 1000.0

# ==============================================================================
# STATE
# ==============================================================================

## Array of nav points (max MAX_NAVPOINTS)
var nav_points: Array = []

## Currently selected nav point index (-1 = none)
var current_nav: int = -1

## Autopilot engaged state
var is_autopilot_engaged: bool = false

## Time compression state
var _time_compression_locked: bool = false
var _target_time_scale: float = 1.0

## Internal timers
var _tick_timer: float = 0.0
var _use_cinematics: bool = false

## Speed cap for autopilot (slowest ship speed)
var _autopilot_speed_cap: float = 1000000.0

## Starting distance for ramping
var _start_distance: float = 0.0

var _messages: Dictionary = {
	MessageType.FAIL_NO_SELECTION: "No nav point selected",
	MessageType.FAIL_GLIDING: "Cannot autopilot while gliding",
	MessageType.FAIL_TOO_CLOSE: "Too close to destination",
	MessageType.FAIL_HOSTILES: "Hostiles detected nearby",
	MessageType.FAIL_HAZARD: "Hazards detected nearby",
	MessageType.MISC_LINKED: "Nav points linked",
}

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	nav_points.resize(MAX_NAVPOINTS)
	for i in range(MAX_NAVPOINTS):
		nav_points[i] = null


func _process(delta: float) -> void:
	_tick_timer += delta
	if _tick_timer >= TICK_RATE:
		_tick_timer -= TICK_RATE
		_nav_system_update()

	if is_autopilot_engaged:
		_update_autopilot(delta)


# ==============================================================================
# NAV POINT MANAGEMENT
# ==============================================================================


## Add a waypoint-based nav point
func add_nav_waypoint(
	p_nav_name: String,
	waypoint_path: String,
	waypoint_idx: int,
	flags: int = 0
) -> bool:
	var slot := _find_empty_slot()
	if slot < 0:
		push_warning("AutopilotManager: No empty nav slots")
		return false

	var nav: Resource = NavPointRes.new()
	nav.nav_name = p_nav_name
	nav.nav_type = NavPointRes.NavType.WAYPOINT
	nav.target_name = waypoint_path
	nav.waypoint_index = waypoint_idx
	nav.flags = flags

	nav_points[slot] = nav
	return true


## Add a ship-based nav point
func add_nav_ship(
	p_nav_name: String,
	ship_name: String,
	flags: int = 0
) -> bool:
	var slot := _find_empty_slot()
	if slot < 0:
		push_warning("AutopilotManager: No empty nav slots")
		return false

	var nav: Resource = NavPointRes.new()
	nav.nav_name = p_nav_name
	nav.nav_type = NavPointRes.NavType.SHIP
	nav.target_name = ship_name
	nav.flags = flags

	nav_points[slot] = nav
	return true


## Delete a nav point by name
func delete_nav(p_nav_name: String) -> bool:
	var idx := find_nav(p_nav_name)
	if idx < 0:
		return false

	if current_nav == idx:
		unselect_nav()

	nav_points[idx] = null
	return true


## Find nav point index by name
func find_nav(p_nav_name: String) -> int:
	for i in range(MAX_NAVPOINTS):
		if nav_points[i] and nav_points[i].nav_name == p_nav_name:
			return i
	return -1


func _find_empty_slot() -> int:
	for i in range(MAX_NAVPOINTS):
		if nav_points[i] == null:
			return i
	return -1


# ==============================================================================
# NAV SELECTION
# ==============================================================================


## Select a nav point by index
func select_nav(nav_index: int) -> void:
	if nav_index < 0 or nav_index >= MAX_NAVPOINTS:
		return

	if nav_points[nav_index] == null:
		return

	if not nav_points[nav_index].is_selectable():
		return

	current_nav = nav_index
	nav_selected.emit(nav_index)


## Select a nav point by name
func select_nav_by_name(p_nav_name: String) -> void:
	var idx := find_nav(p_nav_name)
	if idx >= 0:
		select_nav(idx)


## Unselect current nav
func unselect_nav() -> void:
	if current_nav >= 0:
		current_nav = -1
		nav_deselected.emit()


## Cycle to next selectable nav point
func select_next_nav() -> bool:
	if is_autopilot_engaged:
		return false

	var start := current_nav + 1 if current_nav >= 0 else 0

	for i in range(MAX_NAVPOINTS):
		var idx := (start + i) % MAX_NAVPOINTS
		if nav_points[idx] and nav_points[idx].is_selectable():
			if idx != current_nav:
				select_nav(idx)
				return true

	return false


## Get currently selected nav point
func get_current_nav() -> Resource:
	if current_nav >= 0 and current_nav < MAX_NAVPOINTS:
		return nav_points[current_nav]
	return null


# ==============================================================================
# CAN AUTOPILOT CHECKS
# ==============================================================================


## Check if autopilot can be engaged
func can_autopilot(send_message: bool = false) -> bool:
	var failure := _get_autopilot_failure(send_message)
	return failure == MessageType.MISC_LINKED # MISC_LINKED means no failure


func _get_autopilot_failure(send_message: bool) -> MessageType:
	# Check 1: Nav point selected
	if current_nav < 0 or nav_points[current_nav] == null:
		if send_message:
			_send_message(MessageType.FAIL_NO_SELECTION)
		return MessageType.FAIL_NO_SELECTION

	var player := _get_player_ship()
	if not player:
		return MessageType.FAIL_NO_SELECTION

	# Check 2: Not gliding
	if _is_player_gliding(player):
		if send_message:
			_send_message(MessageType.FAIL_GLIDING)
		return MessageType.FAIL_GLIDING

	# Check 3: Distance > 1000m
	var nav_pos: Vector3 = nav_points[current_nav].get_position()
	var distance := player.global_position.distance_to(nav_pos)
	if distance < MIN_NAV_DISTANCE:
		if send_message:
			_send_message(MessageType.FAIL_TOO_CLOSE)
		return MessageType.FAIL_TOO_CLOSE

	# Check 4-5: Hostiles and asteroids
	var hazard := _check_nearby_hazards(player.global_position, send_message)
	if hazard != MessageType.MISC_LINKED:
		return hazard

	return MessageType.MISC_LINKED # No failure


func _check_nearby_hazards(position: Vector3, send_message: bool) -> MessageType:
	if _check_hostiles_nearby(position):
		if send_message:
			_send_message(MessageType.FAIL_HOSTILES)
		return MessageType.FAIL_HOSTILES

	if _check_asteroids_nearby(position):
		if send_message:
			_send_message(MessageType.FAIL_HAZARD)
		return MessageType.FAIL_HAZARD

	return MessageType.MISC_LINKED


func _check_hostiles_nearby(position: Vector3) -> bool:
	var iff_manager: Node = get_node_or_null("/root/IFFManager")
	if not iff_manager:
		return false

	var ships := get_tree().get_nodes_in_group("ships")
	for ship in ships:
		if not is_instance_valid(ship):
			continue

		if iff_manager.has_method("is_hostile_to_player"):
			if iff_manager.is_hostile_to_player(ship):
				var dist: float = position.distance_to(ship.global_position)
				if dist < HOSTILE_RANGE:
					return true

	return false


func _check_asteroids_nearby(position: Vector3) -> bool:
	var asteroids := get_tree().get_nodes_in_group("asteroids")
	for asteroid in asteroids:
		if not is_instance_valid(asteroid):
			continue

		var dist: float = position.distance_to(asteroid.global_position)
		if dist < ASTEROID_RANGE:
			return true

	return false


# ==============================================================================
# AUTOPILOT CONTROL
# ==============================================================================


## Start autopilot
func start_autopilot() -> void:
	if not can_autopilot(true):
		return

	is_autopilot_engaged = true

	var player := _get_player_ship()
	if not player:
		return

	_autopilot_speed_cap = _calculate_speed_cap()

	var nav_pos: Vector3 = nav_points[current_nav].get_position()
	_start_distance = player.global_position.distance_to(nav_pos)

	_enable_player_ai(true)
	set_time_compression(1.0)
	lock_time_compression(true)
	_assign_autopilot_goals()

	var mission_manager: Node = get_node_or_null("/root/MissionManager")
	if mission_manager and "mission_flags" in mission_manager:
		_use_cinematics = (
			mission_manager.mission_flags & (1 << MissionEnums.MissionFlags.USE_AP_CINEMATICS)
		) != 0

	autopilot_started.emit()
	print("AutopilotManager: Autopilot engaged to %s" % nav_points[current_nav].nav_name)


## End autopilot
func end_autopilot() -> void:
	if not is_autopilot_engaged:
		return

	is_autopilot_engaged = false
	_enable_player_ai(false)
	lock_time_compression(false)
	set_time_compression(1.0)
	_clear_autopilot_goals()

	autopilot_stopped.emit()
	print("AutopilotManager: Autopilot disengaged")


func _update_autopilot(_delta: float) -> void:
	if not is_autopilot_engaged:
		return

	if _should_auto_disable():
		end_autopilot()
		return

	_update_time_compression()


func _should_auto_disable() -> bool:
	var player := _get_player_ship()
	if not player:
		return true

	var nav_pos: Vector3 = nav_points[current_nav].get_position()
	var distance: float = player.global_position.distance_to(nav_pos)
	if distance < MIN_NAV_DISTANCE:
		return true

	if _check_hostiles_nearby(player.global_position):
		return true

	return false


# ==============================================================================
# TIME COMPRESSION
# ==============================================================================


func set_time_compression(scale: float) -> void:
	if _time_compression_locked and scale < Engine.time_scale:
		return
	_target_time_scale = clampf(scale, 1.0, 32.0)
	Engine.time_scale = _target_time_scale


func lock_time_compression(locked: bool) -> void:
	_time_compression_locked = locked


func _update_time_compression() -> void:
	if not is_autopilot_engaged:
		return

	var player := _get_player_ship()
	if not player:
		return

	var nav_pos: Vector3 = nav_points[current_nav].get_position()
	var distance: float = player.global_position.distance_to(nav_pos)

	var progress := 1.0 - (distance / _start_distance) if _start_distance > 0 else 1.0
	progress = clampf(progress, 0.0, 1.0)

	var scale: float
	if progress < 0.1:
		scale = lerpf(1.0, 32.0, progress * 10.0)
	elif progress > 0.9:
		scale = lerpf(32.0, 1.0, (progress - 0.9) * 10.0)
	else:
		scale = 32.0

	set_time_compression(scale)


# ==============================================================================
# AI INTEGRATION
# ==============================================================================


func _calculate_speed_cap() -> float:
	var min_speed := 1000000.0

	var ships := get_tree().get_nodes_in_group("ships")
	for ship in ships:
		if not is_instance_valid(ship):
			continue

		if _has_nav_carry_status(ship):
			var max_speed := _get_ship_max_speed(ship)
			if max_speed < min_speed:
				min_speed = max_speed

	return min_speed * 0.9


func _has_nav_carry_status(ship: Node) -> bool:
	if "ship_flags2" in ship:
		return (ship.ship_flags2 & (1 << MissionEnums.ShipFlags2.NAV_CARRY_STATUS)) != 0
	return false


func _get_ship_max_speed(ship: Node) -> float:
	if "max_speed" in ship:
		return ship.max_speed
	if "ship_data" in ship and ship.ship_data and "max_speed" in ship.ship_data:
		return ship.ship_data.max_speed
	return 100.0


func _assign_autopilot_goals() -> void:
	var nav: Resource = get_current_nav()
	if not nav:
		return

	var nav_pos: Vector3 = nav.get_position()

	var ships := get_tree().get_nodes_in_group("ships")
	for ship in ships:
		if not is_instance_valid(ship):
			continue

		if _has_nav_carry_status(ship):
			_assign_nav_goal_to_ship(ship, nav_pos)


func _assign_nav_goal_to_ship(ship: Node, nav_position: Vector3) -> void:
	if "ai_controller" in ship and ship.ai_controller:
		var ai: Node = ship.ai_controller
		if ai.has_method("set_autopilot_goal"):
			ai.set_autopilot_goal(nav_position, _autopilot_speed_cap)
			return

		if "blackboard" in ai:
			ai.blackboard.set_var("target_position", nav_position)
			ai.blackboard.set_var("autopilot_active", true)
			ai.blackboard.set_var("speed_cap", _autopilot_speed_cap)


func _clear_autopilot_goals() -> void:
	var ships := get_tree().get_nodes_in_group("ships")
	for ship in ships:
		if not is_instance_valid(ship):
			continue

		if _has_nav_carry_status(ship):
			if "ai_controller" in ship and ship.ai_controller:
				var ai: Node = ship.ai_controller
				if "blackboard" in ai:
					ai.blackboard.set_var("autopilot_active", false)


# ==============================================================================
# NAV SYSTEM UPDATE
# ==============================================================================


func _nav_system_update() -> void:
	var player := _get_player_ship()
	if not player:
		return

	for i in range(MAX_NAVPOINTS):
		var nav: Resource = nav_points[i]
		if nav == null:
			continue

		if nav.is_visited():
			continue

		var nav_pos: Vector3 = nav.get_position()
		var distance: float = player.global_position.distance_to(nav_pos)
		if distance < VISITED_RANGE:
			nav.set_visited(true)
			nav_visited.emit(i)


# ==============================================================================
# HELPERS
# ==============================================================================


func _get_player_ship() -> Node3D:
	var players := get_tree().get_nodes_in_group("player_ship")
	if players.size() > 0:
		return players[0] as Node3D
	return null


func _is_player_gliding(player: Node) -> bool:
	if "is_gliding" in player:
		return player.is_gliding
	return false


func _enable_player_ai(enabled: bool) -> void:
	var player := _get_player_ship()
	if not player:
		return

	if "use_ai_control" in player:
		player.use_ai_control = enabled


func _send_message(msg_type: MessageType) -> void:
	var text: String = _messages.get(msg_type, "Unknown error")
	print("AutopilotManager: %s" % text)

	var hud: Node = get_node_or_null("/root/HUDManager")
	if hud and hud.has_method("show_message"):
		hud.show_message(text)


# ==============================================================================
# DISTANCE HELPERS
# ==============================================================================


func get_distance_to(nav_index: int) -> float:
	if nav_index < 0 or nav_index >= MAX_NAVPOINTS:
		return -1.0

	if nav_points[nav_index] == null:
		return -1.0

	var player := _get_player_ship()
	if not player:
		return -1.0

	var nav_pos: Vector3 = nav_points[nav_index].get_position()
	return player.global_position.distance_to(nav_pos)


func get_distance_to_current() -> float:
	return get_distance_to(current_nav)
