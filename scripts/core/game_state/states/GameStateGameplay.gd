class_name GameStateGameplay
extends LimboState

# Gameplay State - Core gameplay loop orchestrator
# Connects MissionManager, PlayerShipController, and HUDController
# Responsible for mission lifecycle during active gameplay

# === SIGNALS ===
signal player_spawned(player_ship: Node)
signal hud_ready(hud: CanvasLayer)

# === SCENE PATHS ===
const PLAYER_SHIP_SCENE := "res://scenes/entities/ship/player_ship.tscn"
const HUD_SCENE := "res://scenes/ui/hud/hud.tscn"
const GAMEPLAY_SCENE := "res://scenes/core/mission_gameplay.tscn"

# === STATE ===
var _gameplay_scene: Node = null
var _player_ship: Node = null
var _player_controller: Node = null
var _hud: CanvasLayer = null
var _camera: Camera3D = null
var _is_mission_active: bool = false


func _enter() -> void:
	print("Entering Gameplay State")

	# Get MissionManager
	var mm = _get_mission_manager()
	if not mm:
		push_error("GameStateGameplay: MissionManager not found!")
		_exit_to_menu()
		return

	# Check if mission is loaded
	if not mm.current_mission:
		push_error("GameStateGameplay: No mission loaded!")
		_exit_to_menu()
		return

	# Setup gameplay scene
	_setup_gameplay_scene()

	# Connect to MissionManager signals
	mm.entity_spawned.connect(_on_entity_spawned)
	mm.mission_ended.connect(_on_mission_ended)

	# Start the mission (spawns initial entities)
	mm.start_mission()

	# Find and setup player ship
	_setup_player_ship()

	# Setup HUD
	_setup_hud()

	# Setup camera
	_setup_camera()

	_is_mission_active = true
	print("GameStateGameplay: Mission started - " + mm.current_mission.mission_title)


func _exit() -> void:
	print("Exiting Gameplay State")

	_is_mission_active = false

	# Disconnect signals
	var mm = _get_mission_manager()
	if mm:
		if mm.entity_spawned.is_connected(_on_entity_spawned):
			mm.entity_spawned.disconnect(_on_entity_spawned)
		if mm.mission_ended.is_connected(_on_mission_ended):
			mm.mission_ended.disconnect(_on_mission_ended)

	# Cleanup
	_cleanup_gameplay()


func _update(_delta: float) -> void:
	if not _is_mission_active:
		return

	# Update mission time (handled by MissionManager in _process)
	# Update HUD if needed
	_update_hud_target()


# === SETUP METHODS ===

func _setup_gameplay_scene() -> void:
	"""Load and setup the gameplay scene container"""
	var root = get_tree().root

	# Try to load gameplay scene, or create minimal structure
	if ResourceLoader.exists(GAMEPLAY_SCENE):
		var scene = load(GAMEPLAY_SCENE)
		if scene:
			_gameplay_scene = scene.instantiate()
			root.add_child(_gameplay_scene)
			return

	# Create minimal gameplay container
	_gameplay_scene = Node.new()
	_gameplay_scene.name = "GameplayScene"
	root.add_child(_gameplay_scene)

	# Add entity container
	var entity_container = Node3D.new()
	entity_container.name = "Entities"
	_gameplay_scene.add_child(entity_container)


func _setup_player_ship() -> void:
	"""Find or spawn the player ship and attach controller"""
	var mm = _get_mission_manager()
	if not mm or not mm.current_mission:
		return

	# Find player start object in mission
	var player_object: Resource = null
	for obj in mm.current_mission.objects:
		if obj.player_start_index >= 0:
			player_object = obj
			break

	if not player_object:
		push_warning("GameStateGameplay: No player start in mission")
		return

	# Check if player already spawned by MissionManager
	_player_ship = mm.get_entity(player_object.object_name)

	if not _player_ship:
		# Spawn player manually
		_player_ship = mm.spawn_entity(player_object)

	if not _player_ship:
		push_error("GameStateGameplay: Failed to spawn player ship")
		return

	# Add player to "player" group
	_player_ship.add_to_group("player")

	# Attach PlayerShipController
	_attach_player_controller()

	player_spawned.emit(_player_ship)
	print("GameStateGameplay: Player ship ready - " + _player_ship.name)


func _attach_player_controller() -> void:
	"""Attach PlayerShipController to player ship"""
	if not _player_ship:
		return

	# Check if controller already exists
	for child in _player_ship.get_children():
		if child is PlayerShipController:
			_player_controller = child
			return

	# Create and attach controller
	_player_controller = PlayerShipController.new()
	_player_controller.name = "PlayerController"
	_player_controller.ship = _player_ship
	_player_ship.add_child(_player_controller)


func _setup_hud() -> void:
	"""Instantiate and configure HUD"""
	if not ResourceLoader.exists(HUD_SCENE):
		push_warning("GameStateGameplay: HUD scene not found at " + HUD_SCENE)
		return

	var hud_scene = load(HUD_SCENE)
	if not hud_scene:
		return

	_hud = hud_scene.instantiate()
	_hud.name = "HUD"

	# Add to scene tree
	if _gameplay_scene:
		_gameplay_scene.add_child(_hud)
	else:
		get_tree().root.add_child(_hud)

	# Connect HUD to player ship
	if _hud.has_method("set_player"):
		_hud.set_player(_player_ship)
	elif "player_ship" in _hud:
		_hud.player_ship = _player_ship.get_path() if _player_ship else NodePath("")

	# Get HUD controller script if exists
	var controller = _hud.get_node_or_null("HUDController")
	if not controller:
		controller = _hud

	if controller:
		if controller.has_method("set_player"):
			controller.set_player(_player_ship)
		if controller.has_method("show_hud"):
			controller.show_hud()

	hud_ready.emit(_hud)
	print("GameStateGameplay: HUD initialized")


func _setup_camera() -> void:
	"""Setup player camera"""
	if not _player_ship:
		return

	# Look for existing camera in player ship
	_camera = _player_ship.find_child("Camera3D", true, false)
	if _camera:
		_camera.make_current()
		return

	# Look for camera controller component
	var cam_controller = _player_ship.find_child("WCSCameraController", true, false)
	if cam_controller:
		_camera = cam_controller.find_child("Camera3D", true, false)
		if _camera:
			_camera.make_current()
			return

	# Create fallback camera
	_camera = Camera3D.new()
	_camera.name = "PlayerCamera"
	_camera.position = Vector3(0, 5, 15) # Behind and above
	_camera.look_at(Vector3.ZERO)
	_player_ship.add_child(_camera)
	_camera.make_current()


# === UPDATE METHODS ===

func _update_hud_target() -> void:
	"""Update HUD with current target information"""
	if not _hud or not _player_ship:
		return

	# Get target from player ship if available
	var target: Node = null
	if "current_target" in _player_ship:
		target = _player_ship.current_target
	elif _player_ship.has_method("get_target"):
		target = _player_ship.get_target()

	# Update HUD target display
	if _hud.has_method("set_target"):
		_hud.set_target(target)


# === EVENT HANDLERS ===

func _on_entity_spawned(entity: Node, _mission_object: Resource) -> void:
	"""Handle entity spawn from MissionManager"""
	# Add to ships group for radar
	if entity.has_method("is_ship") or "ShipEntity" in entity.get_class():
		entity.add_to_group("ships")


func _on_mission_ended(success: bool) -> void:
	"""Handle mission completion"""
	print("GameStateGameplay: Mission ended - " + ("SUCCESS" if success else "FAILED"))
	_is_mission_active = false

	# Cleanup and transition to debrief
	# For now, just go back to menu
	_exit_to_menu()


# === CLEANUP ===

func _cleanup_gameplay() -> void:
	"""Clean up gameplay scene and resources"""
	if _hud and is_instance_valid(_hud):
		_hud.queue_free()
		_hud = null

	if _player_controller and is_instance_valid(_player_controller):
		_player_controller.queue_free()
		_player_controller = null

	if _gameplay_scene and is_instance_valid(_gameplay_scene):
		_gameplay_scene.queue_free()
		_gameplay_scene = null

	_player_ship = null
	_camera = null

	# End mission in MissionManager
	var mm = _get_mission_manager()
	if mm and mm.mission_active:
		mm.end_mission(false)


func _exit_to_menu() -> void:
	"""Transition back to main menu"""
	var gsm = get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_main_menu")


# === HELPERS ===

func _get_mission_manager() -> Node:
	"""Get MissionManager autoload safely"""
	if Engine.has_singleton("MissionManager"):
		return Engine.get_singleton("MissionManager")
	return get_node_or_null("/root/MissionManager")


# === PUBLIC API ===

func get_player_ship() -> Node:
	"""Get the current player ship"""
	return _player_ship


func get_hud() -> CanvasLayer:
	"""Get the HUD instance"""
	return _hud


func is_gameplay_active() -> bool:
	"""Check if gameplay is active"""
	return _is_mission_active
