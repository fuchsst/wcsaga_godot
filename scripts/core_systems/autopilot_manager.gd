# scripts/core_systems/autopilot_manager.gd
extends Node
class_name AutopilotManager

## Manages the Autopilot system state, NavPoints, engagement, and cinematics.
## Corresponds to logic in autopilot.cpp/.h.
## This should be configured as an Autoload Singleton named "AutopilotManager".

# --- Signals ---
signal autopilot_engaged
signal autopilot_disengaged
signal autopilot_message(message: String, sound_path: String)
signal autopilot_nav_selected(nav_point: NavPointData)
signal autopilot_nav_unselected

# --- Constants ---
const LINK_CHECK_INTERVAL: float = 0.5 # How often to check for ships needing linking (in seconds)
const AUTOPILOT_CHECK_INTERVAL: float = 0.25 # How often to check conditions while engaged

# --- Exports / Config ---
var config: AutopilotConfig = null # Loaded in _ready

# --- State Variables ---
var is_engaged: bool = false
var is_cinematic_active: bool = false # True when cinematic autopilot sequence is running
var current_nav_index: int = -1
var nav_points: Array[NavPointData] = []

# --- Node References (Set externally or in _ready) ---
var player_ship: ShipBase = null # Reference to the player's ship node
var player_controller: Node = null # Reference to the player's normal controller script/node
var player_autopilot_controller: Node = null # Reference to the AI controller used during autopilot
var cinematic_camera: Camera3D = null # Reference to the dedicated cinematic camera
var cinematic_camera_controller: Node = null # Reference to the cinematic camera's controller script

# --- Internal Timers ---
var _link_check_timer: float = 0.0
var _autopilot_check_timer: float = 0.0
var _lock_ap_conv_timer: float = 0.0 # Corresponds to LockAPConv timestamp

# --- Cinematic State ---
var _cinematic_start_time: float = 0.0
var _cinematic_end_time: float = 0.0 # Corresponds to EndAPCinematic timestamp
var _cinematic_move_camera_time: float = 0.0 # Corresponds to MoveCamera timestamp
var _cinematic_camera_moving: bool = false
var _cinematic_initial_cam_pos: Vector3 = Vector3.ZERO
var _cinematic_initial_cam_target: Vector3 = Vector3.ZERO
var _cinematic_start_dist: float = 0.0

# --- Dependencies (Set via signals, get_node, or injection) ---
var object_manager = null # Reference to ObjectManager Autoload/Node
var waypoint_manager = null # Reference to WaypointManager or similar
var ui_manager = null # Reference to a UI manager for messages/bars
var game_manager = null # Reference to GameManager for time compression lock
var ai_goal_manager = null # Reference to AIGoalManager

func _ready():
	# TODO: Load AutopilotConfig resource (e.g., from resources/autopilot/autopilot_config.tres)
	# config = load("res://resources/autopilot/autopilot_config.tres")
	if config == null:
		printerr("AutopilotManager: AutopilotConfig not loaded!")
		# Create a default one to prevent crashes, but log error
		config = AutopilotConfig.new()
		config.msg_fail_no_selection = "Autopilot Config Missing!"

	# TODO: Get references to player ship, controllers, cameras
	# Example: player_ship = get_tree().get_first_node_in_group("player_ship")
	# Example: player_controller = player_ship.get_node("PlayerShipController")
	# Example: player_autopilot_controller = player_ship.get_node("PlayerAutopilotController")
	# Example: cinematic_camera = get_tree().get_first_node_in_group("cinematic_camera")
	# Example: if cinematic_camera: cinematic_camera_controller = cinematic_camera.get_node("AutopilotCameraController")

	# Get references to managers (assuming Autoloads for now)
	if Autoloads.has("ObjectManager"): object_manager = Autoloads.ObjectManager
	else: printerr("AutopilotManager: ObjectManager Autoload not found!")
	# if Autoloads.has("WaypointManager"): waypoint_manager = Autoloads.WaypointManager # Assuming this exists
	# else: printerr("AutopilotManager: WaypointManager Autoload not found!")
	# if Autoloads.has("UIManager"): ui_manager = Autoloads.UIManager # Assuming this exists
	# else: printerr("AutopilotManager: UIManager Autoload not found!")
	if Autoloads.has("GameManager"): game_manager = Autoloads.GameManager
	else: printerr("AutopilotManager: GameManager Autoload not found!")
	if Autoloads.has("AIGoalManager"): ai_goal_manager = Autoloads.AIGoalManager
	else: printerr("AutopilotManager: AIGoalManager Autoload not found!")


func _process(delta: float):
	if is_engaged:
		_autopilot_check_timer += delta
		if _autopilot_check_timer >= AUTOPILOT_CHECK_INTERVAL:
			_autopilot_check_timer = 0.0
			_check_autopilot_conditions() # Check if we need to auto-disable

		if is_cinematic_active:
			_update_cinematic_autopilot(delta)
		else:
			_update_standard_autopilot(delta)

	# Check for linking ships periodically even when not engaged? (Original code implies this)
	_link_check_timer += delta
	if _link_check_timer >= LINK_CHECK_INTERVAL:
		_link_check_timer = 0.0
		_check_for_linking_ships()

	if _lock_ap_conv_timer > 0.0:
		_lock_ap_conv_timer -= delta


func load_mission_nav_points(mission_nav_points: Array[NavPointData]):
	nav_points = mission_nav_points
	current_nav_index = -1
	emit_signal("autopilot_nav_unselected")
	# TODO: Potentially validate nav points?


func select_next_nav() -> bool:
	if is_engaged:
		return false # Cannot change nav while engaged

	if nav_points.is_empty():
		current_nav_index = -1
		emit_signal("autopilot_nav_unselected")
		return false

	var start_index = current_nav_index
	if start_index == -1:
		start_index = nav_points.size() - 1 # Start search from the beginning

	for i in range(1, nav_points.size() + 1):
		var check_index = (start_index + i) % nav_points.size()
		if nav_points[check_index].can_select():
			current_nav_index = check_index
			emit_signal("autopilot_nav_selected", nav_points[current_nav_index])
			return true

	# No selectable nav point found (might happen if all are hidden/noaccess)
	# If we started with a valid selection, keep it. Otherwise, unselect.
	if current_nav_index != -1 and not nav_points[current_nav_index].can_select():
		current_nav_index = -1
		emit_signal("autopilot_nav_unselected")

	return current_nav_index != -1


func can_autopilot(send_msg: bool = false) -> bool:
	if player_ship == null:
		printerr("AutopilotManager: Player ship reference not set!")
		return false

	if current_nav_index == -1 or current_nav_index >= nav_points.size():
		if send_msg: _send_message(AutopilotConfig.MessageID.FAIL_NO_SELECTION)
		return false

	var current_nav: NavPointData = nav_points[current_nav_index]

	# Check gliding status
	if player_ship.physics_controller and player_ship.physics_controller.is_gliding():
		if send_msg: _send_message(AutopilotConfig.MessageID.FAIL_GLIDING)
		return false

	var target_pos: Vector3 = current_nav.get_target_position()
	if target_pos == Vector3.ZERO and current_nav.target_type == NavPointData.TargetType.WAYPOINT_PATH:
		printerr("AutopilotManager: Target position for waypoint nav point '", current_nav.nav_name, "' is ZERO. Waypoint system likely not implemented.")
		# Cannot calculate distance if target pos is unknown
		if send_msg: _send_message(AutopilotConfig.MessageID.FAIL_HAZARD) # Use a generic failure
		return false

	var dist_sq: float = player_ship.global_position.distance_squared_to(target_pos)

	# Check distance (Original uses 1000m)
	if dist_sq < 1000.0 * 1000.0:
		if send_msg: _send_message(AutopilotConfig.MessageID.FAIL_TOO_CLOSE)
		return false

	# Check for nearby hostiles (Requires ObjectManager and IFF logic)
	if object_manager and _check_nearby_objects(player_ship.global_position, 5000.0, GlobalConstants.ObjectType.SHIP, true):
		if send_msg: _send_message(AutopilotConfig.MessageID.FAIL_HOSTILES)
		return false

	# Check for nearby hazards (asteroids) (Requires ObjectManager)
	if object_manager and _check_nearby_objects(player_ship.global_position, 1000.0, GlobalConstants.ObjectType.ASTEROID, false):
		if send_msg: _send_message(AutopilotConfig.MessageID.FAIL_HAZARD)
		return false

	return true


func start_autopilot():
	if is_engaged or not can_autopilot(true):
		gamesnd_play_iface(SND_GENERAL_FAIL) # Use appropriate sound ID
		return

	if player_ship == null or player_controller == null or player_autopilot_controller == null:
		printerr("AutopilotManager: Player ship or controllers not set!")
		return

	is_engaged = true
	Engine.time_scale = 1.0 # Reset time compression initially
	if game_manager: game_manager.lock_time_compression(true)
	else: printerr("AutopilotManager: GameManager not found to lock time compression!")

	# Set player AI controller active
	if player_controller and player_controller.has_method("set_active"):
		player_controller.set_active(false) # Disable normal input processing
	if player_autopilot_controller and player_autopilot_controller.has_method("set_active"):
		player_autopilot_controller.set_active(true) # Enable AI control
		player_autopilot_controller.set_target_nav_point(nav_points[current_nav_index])
		# TODO: Calculate and set speed cap based on fleet? (Original logic)
		# player_autopilot_controller.set_speed_cap(calculated_speed_cap)

	# Set AI goals for player and carried ships/wings
	_set_autopilot_ai_goals(true)

	# Handle cinematic autopilot setup
	# TODO: Check mission flag MISSION_FLAG_USE_AP_CINEMATICS
	var use_cinematics = false # Placeholder: Get from MissionManager
	if use_cinematics and config.use_cutscene_bars:
		if ui_manager and ui_manager.has_method("show_cutscene_bars"):
			ui_manager.show_cutscene_bars(true)
		else: printerr("AutopilotManager: UIManager not found or doesn't support cutscene bars!")

	if use_cinematics:
		is_cinematic_active = true
		_setup_cinematic_autopilot()
		# Set initial time compression based on speed diff (original logic)
		# float tc_factor = _calculate_cinematic_time_compression()
		# Engine.time_scale = tc_factor
		# _cinematic_end_time = Time.get_ticks_msec() + (10000 * tc_factor) + 125 # NPS_TICKRATE
		# _cinematic_move_camera_time = Time.get_ticks_msec() + (5500 * tc_factor) + 125
		# _cinematic_camera_moving = false
	else:
		is_cinematic_active = false
		_lock_ap_conv_timer = 3.0 # 3 seconds lock

	_cinematic_start_dist = player_ship.global_position.distance_to(nav_points[current_nav_index].get_target_position())

	emit_signal("autopilot_engaged")
	# TODO: Play engagement sound?


func end_autopilot():
	if not is_engaged:
		return

	is_engaged = false
	is_cinematic_active = false
	Engine.time_scale = 1.0
	if game_manager: game_manager.lock_time_compression(false)
	else: printerr("AutopilotManager: GameManager not found to unlock time compression!")

	# Restore player control
	if player_autopilot_controller and player_autopilot_controller.has_method("set_active"):
		player_autopilot_controller.set_active(false)
	if player_controller and player_controller.has_method("set_active"):
		player_controller.set_active(true)

	# Clear AI goals related to autopilot
	_set_autopilot_ai_goals(false)

	if is_cinematic_active and config.use_cutscene_bars:
		if ui_manager and ui_manager.has_method("show_cutscene_bars"):
			ui_manager.show_cutscene_bars(false)
		else: printerr("AutopilotManager: UIManager not found or doesn't support cutscene bars!")

	# Reset cinematic camera if it was used
	if is_cinematic_active and CameraManager:
		CameraManager.reset_to_default_camera()

	is_cinematic_active = false # Ensure this is reset here too
	emit_signal("autopilot_disengaged")
	# TODO: Play disengagement sound?


func toggle_autopilot():
	# TODO: Check Mission Flag MISSION_FLAG_DEACTIVATE_AP
	# if MissionManager.current_mission_has_flag("DEACTIVATE_AP"): return

	if is_engaged:
		# TODO: Check config.no_autopilot_interrupt (Cmdline_autopilot_interruptable in C++)
		# if config.no_autopilot_interrupt: return
		end_autopilot()
	else:
		start_autopilot()


# --- Internal Helper Methods ---

func _send_message(msg_id: AutopilotConfig.MessageID):
	if config:
		var msg = config.get_message(msg_id)
		var snd = config.get_sound(msg_id)
		emit_signal("autopilot_message", msg, snd)


func _check_autopilot_conditions():
	# Check if conditions for staying engaged are still met
	if not can_autopilot(false): # Don't send messages on auto-disable
		# TODO: Check config.no_autopilot_interrupt before ending?
		end_autopilot()


func _update_standard_autopilot(delta: float):
	# Implement time compression ramping based on distance
	if not is_instance_valid(player_ship) or current_nav_index < 0: return

	var dist_to_target = player_ship.global_position.distance_to(nav_points[current_nav_index].get_target_position())
	var dist_from_start = _cinematic_start_dist - dist_to_target

	# Simplified ramping logic based on C++ code structure
	# TODO: Refine this based on ramp_bias (calculated speed cap)
	var ramp_bias_placeholder = 50.0 # Placeholder, should be calculated based on fleet speed
	var target_timescale = 1.0

	if dist_from_start < (3500.0 * ramp_bias_placeholder):
		if dist_from_start >= (3000.0 * ramp_bias_placeholder) and dist_to_target > 30000.0:
			target_timescale = 64.0
		elif dist_from_start >= (2000.0 * ramp_bias_placeholder):
			target_timescale = 32.0
		elif dist_from_start >= (1600.0 * ramp_bias_placeholder):
			target_timescale = 16.0
		elif dist_from_start >= (1200.0 * ramp_bias_placeholder):
			target_timescale = 8.0
		elif dist_from_start >= (800.0 * ramp_bias_placeholder):
			target_timescale = 4.0
		elif dist_from_start >= (400.0 * ramp_bias_placeholder):
			target_timescale = 2.0

	if dist_to_target <= (7000.0 * ramp_bias_placeholder):
		if dist_to_target >= (5000.0 * ramp_bias_placeholder):
			target_timescale = 32.0
		elif dist_to_target >= (4000.0 * ramp_bias_placeholder):
			target_timescale = 16.0
		elif dist_to_target >= (3000.0 * ramp_bias_placeholder):
			target_timescale = 8.0
		elif dist_to_target >= (2000.0 * ramp_bias_placeholder):
			target_timescale = 4.0
		elif dist_to_target >= (1000.0 * ramp_bias_placeholder):
			target_timescale = 2.0

	if game_manager:
		game_manager.set_time_compression(target_timescale) # Assumes GameManager handles this


func _update_cinematic_autopilot(delta: float):
	# Implement cinematic camera movement logic
	var current_time = Time.get_ticks_msec() / 1000.0

	if not _cinematic_camera_moving and current_time >= _cinematic_move_camera_time:
		# TODO: Start moving camera to calculated target position/orientation
		# if cinematic_camera_controller:
		#	 cinematic_camera_controller.move_to_pose(calculated_target_pos, calculated_look_at, calculated_duration)
		_cinematic_camera_moving = true

	# TODO: Update camera look_at if not moving? (Original code has cam->set_rotation_facing(&Player_obj->pos))
	if not _cinematic_camera_moving and cinematic_camera_controller and is_instance_valid(player_ship):
		cinematic_camera_controller.look_at_target(player_ship.global_position)

	# Check for end condition
	if current_time >= _cinematic_end_time:
		_warp_ships() # Warp at the very end
		end_autopilot()
	pass


func _setup_cinematic_autopilot():
	# Calculate initial camera position and target based on player/fleet
	if not is_instance_valid(player_ship) or not cinematic_camera or not cinematic_camera_controller:
		printerr("AutopilotManager: Cannot setup cinematic autopilot - missing references.")
		is_cinematic_active = false # Abort cinematic mode
		return

	# TODO: Implement complex C++ logic for camera placement
	# - Get all ships marked SF2_NAVPOINT_CARRY or WF_NAV_CARRY
	# - Find max radius (fleet_radius) and center position (fleet_center, maybe player pos)
	# - Calculate speed cap based on slowest ship
	# - Calculate time compression factor (tc_factor)
	# - Calculate base camera position (pos) along path
	# - Calculate perpendicular offset (perp) based on fleet size and randomness
	# - Calculate final camera position (cameraPos = pos + perp)
	# - Calculate camera target (cameraTarget) based on fleet size/presence
	_cinematic_initial_cam_pos = player_ship.global_position + player_ship.global_transform.basis.z * -200.0 + player_ship.global_transform.basis.x * 50.0 # Placeholder
	_cinematic_initial_cam_target = player_ship.global_position # Placeholder

	# Perform initial warp
	_warp_ships(true)

	# Set camera pose and activate it
	cinematic_camera_controller.set_instant_pose(_cinematic_initial_cam_pos, _cinematic_initial_cam_target)
	if CameraManager: CameraManager.set_active_camera(cinematic_camera, true) # Hide HUD
	else: printerr("AutopilotManager: CameraManager not found!")

	_cinematic_start_time = Time.get_ticks_msec() / 1000.0
	# TODO: Calculate _cinematic_end_time and _cinematic_move_camera_time based on tc_factor


func _warp_ships(prewarp: bool = false):
	# Implement ship warping logic (nav_warp)
	if not is_instance_valid(player_ship) or current_nav_index < 0: return

	var final_dest_pos = nav_points[current_nav_index].get_target_position()
	var current_pos = player_ship.global_position
	var direction_to_dest = (final_dest_pos - current_pos).normalized()

	# Find position just outside engagement range (e.g., 1500m from dest)
	# Need to check CanAutopilotPos equivalent along the path
	var warp_target_pos = final_dest_pos - direction_to_dest * 1500.0 # Simplified target
	# TODO: Iterate backwards from dest using CanAutopilotPos check like C++

	var warp_delta = warp_target_pos - current_pos

	if prewarp:
		# Apply half delta to camera position (used in cinematic setup)
		_cinematic_initial_cam_pos += warp_delta * 0.5

	# Apply full delta to player and carried ships
	player_ship.global_position += warp_delta
	# TODO: Find all ships with SF2_NAVPOINT_CARRY or WF_NAV_CARRY
	# var carried_ships = object_manager.get_ships_with_flags(...) # Example
	# for ship_node in carried_ships:
	#	 ship_node.global_position += warp_delta

	# TODO: Call ObjectManager.retime_all_collisions() or equivalent physics update


func _check_for_linking_ships():
	if config == null or player_ship == null: return

	# Find nearby ships with SF2_NAVPOINT_NEEDSLINK flag
	if not object_manager or not is_instance_valid(player_ship): return

	var nearby_ships = object_manager.get_ships_in_radius(player_ship.global_position, config.link_distance + 500.0) # Add buffer
	for ship_node in nearby_ships:
		if ship_node == player_ship: continue # Skip self
		if ship_node.has_flag(GlobalConstants.ShipFlags2.SF2_NAVPOINT_NEEDSLINK):
			var dist_sq = player_ship.global_position.distance_squared_to(ship_node.global_position)
			var link_dist_sq = pow(config.link_distance + ship_node.radius, 2)
			if dist_sq < link_dist_sq:
				ship_node.clear_flag(GlobalConstants.ShipFlags2.SF2_NAVPOINT_NEEDSLINK)
				ship_node.set_flag(GlobalConstants.ShipFlags2.SF2_NAVPOINT_CARRY)
				_send_message(AutopilotConfig.MessageID.MISC_LINKED)


func _check_nearby_objects(pos: Vector3, radius: float, obj_type: GlobalConstants.ObjectType, check_hostile: bool) -> bool:
	# Helper to check for nearby objects (hostiles or hazards)
	if not object_manager: return false

	var radius_sq = radius * radius
	var nearby_objects = object_manager.get_objects_in_radius(pos, radius) # Assumes ObjectManager has this

	for obj_node in nearby_objects:
		if obj_node.get_object_type() == obj_type:
			if obj_node.global_position.distance_squared_to(pos) < radius_sq:
				if check_hostile:
					# TODO: Implement IFF check using IFFManager or similar
					# if IFFManager.is_hostile(player_ship.team, obj_node.get_team()):
					#	 # Optional: Ignore cargo ships like C++ code
					#	 if not obj_node.has_ship_flag(GlobalConstants.ShipInfoFlags.SIF_CARGO):
					#		 return true
					pass # Placeholder for IFF check
				else:
					# Hazard check (like asteroids), no hostility check needed
					return true
	return false


func _set_autopilot_ai_goals(engage: bool):
	# Helper to set or clear AI goals for autopilot
	if not ai_goal_manager or not is_instance_valid(player_ship) or current_nav_index < 0:
		printerr("AutopilotManager: Cannot set AI goals - missing references.")
		return

	var current_nav = nav_points[current_nav_index]
	var goal_mode = GlobalConstants.AIGoalMode.NONE
	var target_name = ""

	if engage:
		if current_nav.target_type == NavPointData.TargetType.WAYPOINT_PATH:
			goal_mode = GlobalConstants.AIGoalMode.WAYPOINTS_ONCE
			target_name = current_nav.target_identifier
		else: # SHIP
			goal_mode = GlobalConstants.AIGoalMode.FLY_TO_SHIP
			target_name = current_nav.target_identifier
	else:
		# Determine goal mode/name that *was* active to clear it
		# This might need storing the goal info when engaging
		# For now, assume we can deduce it or clear all autopilot goals
		pass # Placeholder for clear logic

	# TODO: Find all ships/wings with SF2_NAVPOINT_CARRY or WF_NAV_CARRY flags
	# var carried_entities = object_manager.get_autopilot_carriers() # Example

	# Apply/Clear goals
	if engage:
		# Set goal for player
		if player_autopilot_controller and player_autopilot_controller.has_method("set_ai_goal"):
			# player_autopilot_controller.set_ai_goal(goal_mode, target_name) # Example
			pass
		# Set goals for carried entities
		# for entity in carried_entities:
		#	 ai_goal_manager.add_goal(entity.ai_controller, goal_mode, target_name, priority=HIGH_PRIORITY, flags=AUTOPILOT_GOAL)
	else:
		# Clear goal for player
		if player_autopilot_controller and player_autopilot_controller.has_method("clear_ai_goal"):
			# player_autopilot_controller.clear_ai_goal() # Example
			pass
		# Clear goals for carried entities
		# for entity in carried_entities:
		#	 ai_goal_manager.remove_goal_by_flag(entity.ai_controller, AUTOPILOT_GOAL)
		pass

# TODO: Implement _calculate_cinematic_time_compression
