class_name ManagerCoordinator
extends Node

## Coordinates signal connections and communication between core managers
## Ensures proper initialization order and handles inter-manager dependencies

signal all_managers_initialized()
signal manager_coordination_complete()

var initialized_managers: Array[String] = []
var required_managers: Array[String] = [
	"ObjectManager",
	"GameStateManager", 
	"PhysicsManager",
	"InputManager"
]

var manager_ready_count: int = 0

func _ready() -> void:
	print("ManagerCoordinator: Starting manager coordination...")
	_setup_manager_connections()

func _setup_manager_connections() -> void:
	# Wait for all managers to be ready
	call_deferred("_connect_to_managers")

func _connect_to_managers() -> void:
	# Connect to manager initialization signals
	if ObjectManager:
		ObjectManager.manager_initialized.connect(_on_manager_initialized.bind("ObjectManager"))
		ObjectManager.critical_error.connect(_on_manager_critical_error.bind("ObjectManager"))
	
	if GameStateManager:
		GameStateManager.manager_initialized.connect(_on_manager_initialized.bind("GameStateManager"))
		GameStateManager.critical_error.connect(_on_manager_critical_error.bind("GameStateManager"))
		GameStateManager.state_changed.connect(_on_game_state_changed)
	
	if PhysicsManager:
		PhysicsManager.manager_initialized.connect(_on_manager_initialized.bind("PhysicsManager"))
		PhysicsManager.critical_error.connect(_on_manager_critical_error.bind("PhysicsManager"))
		PhysicsManager.collision_detected.connect(_on_physics_collision)
	
	if InputManager:
		InputManager.manager_initialized.connect(_on_manager_initialized.bind("InputManager"))
		InputManager.critical_error.connect(_on_manager_critical_error.bind("InputManager"))
		InputManager.input_action_triggered.connect(_on_input_action)
	
	# Set up inter-manager connections
	_setup_inter_manager_signals()

func _setup_inter_manager_signals() -> void:
	# ObjectManager <-> GameStateManager
	if ObjectManager and GameStateManager:
		GameStateManager.state_changed.connect(_on_state_change_cleanup)
	
	# ObjectManager <-> PhysicsManager  
	if ObjectManager and PhysicsManager:
		ObjectManager.object_created.connect(_on_object_created_for_physics)
		ObjectManager.object_destroyed.connect(_on_object_destroyed_for_physics)
	
	# GameStateManager <-> InputManager
	if GameStateManager and InputManager:
		GameStateManager.state_changed.connect(_on_state_change_input)
	
	print("ManagerCoordinator: Inter-manager signals connected")

func _on_manager_initialized(manager_name: String) -> void:
	if not initialized_managers.has(manager_name):
		initialized_managers.append(manager_name)
		manager_ready_count += 1
		
		print("ManagerCoordinator: %s initialized (%d/%d)" % [manager_name, manager_ready_count, required_managers.size()])
		
		if manager_ready_count >= required_managers.size():
			_complete_initialization()

func _complete_initialization() -> void:
	print("ManagerCoordinator: All core managers initialized successfully")
	all_managers_initialized.emit()
	manager_coordination_complete.emit()

func _on_manager_critical_error(manager_name: String, error_message: String) -> void:
	push_error("ManagerCoordinator: Critical error in %s: %s" % [manager_name, error_message])
	
	# Handle manager failure gracefully
	_handle_manager_failure(manager_name)

func _handle_manager_failure(manager_name: String) -> void:
	# Attempt to recover or gracefully degrade
	match manager_name:
		"ObjectManager":
			push_error("ManagerCoordinator: ObjectManager failure - system cannot continue")
		"GameStateManager":
			push_error("ManagerCoordinator: GameStateManager failure - attempting recovery")
		"PhysicsManager":
			print("ManagerCoordinator: PhysicsManager failure - disabling physics simulation")
		"InputManager":
			print("ManagerCoordinator: InputManager failure - input will be limited")

# Signal relay functions

func _on_state_change_cleanup(old_state: GameStateManager.GameState, new_state: GameStateManager.GameState) -> void:
	# Clear objects when transitioning between major states
	if old_state == GameStateManager.GameState.MISSION and new_state != GameStateManager.GameState.MISSION:
		if ObjectManager:
			ObjectManager.clear_all_objects()

func _on_object_created_for_physics(object: WCSObject) -> void:
	# Register physics bodies for objects that need physics
	if PhysicsManager and object.has_method("get_physics_body"):
		var physics_body: CustomPhysicsBody = object.get_physics_body()
		if physics_body:
			PhysicsManager.register_physics_body(physics_body)

func _on_object_destroyed_for_physics(object: WCSObject) -> void:
	# Unregister physics bodies when objects are destroyed
	if PhysicsManager and object.has_method("get_physics_body"):
		var physics_body: CustomPhysicsBody = object.get_physics_body()
		if physics_body:
			PhysicsManager.unregister_physics_body(physics_body)

func _on_state_change_input(old_state: GameStateManager.GameState, new_state: GameStateManager.GameState) -> void:
	# Enable/disable input based on game state
	if InputManager:
		var input_enabled: bool = true
		
		match new_state:
			GameStateManager.GameState.LOADING:
				input_enabled = false
			GameStateManager.GameState.SHUTDOWN:
				input_enabled = false
		
		InputManager.set_input_enabled(input_enabled)

func _on_physics_collision(body1: WCSObject, body2: WCSObject, collision_info: Dictionary) -> void:
	# Handle physics collisions at the game level
	# This could trigger sound effects, damage, etc.
	print("ManagerCoordinator: Collision detected between %s and %s" % [body1.debug_info(), body2.debug_info()])

func _on_input_action(action: String, strength: float) -> void:
	# Handle special input actions that affect game state
	match action:
		"pause":
			if strength > 0.5 and GameStateManager:
				if GameStateManager.get_current_state() == GameStateManager.GameState.MISSION:
					# Toggle pause (would need pause state implementation)
					pass
		
		"screenshot":
			if strength > 0.5:
				_take_screenshot()

func _on_game_state_changed(old_state: GameStateManager.GameState, new_state: GameStateManager.GameState) -> void:
	print("ManagerCoordinator: Game state changed: %s -> %s" % [GameStateManager.GameState.keys()[old_state], GameStateManager.GameState.keys()[new_state]])

func _take_screenshot() -> void:
	# Take a screenshot
	var image: Image = get_viewport().get_texture().get_image()
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var filename: String = "user://screenshot_%s.png" % timestamp
	
	image.save_png(filename)
	print("ManagerCoordinator: Screenshot saved: %s" % filename)

# Debug and diagnostics

func get_manager_status() -> Dictionary:
	var status: Dictionary = {}
	
	for manager_name in required_managers:
		var manager: Node = get_node_or_null("/root/" + manager_name)
		if manager:
			status[manager_name] = {
				"exists": true,
				"initialized": initialized_managers.has(manager_name),
				"has_performance_stats": manager.has_method("get_performance_stats")
			}
			
			if manager.has_method("get_performance_stats"):
				status[manager_name]["performance"] = manager.get_performance_stats()
		else:
			status[manager_name] = {
				"exists": false,
				"initialized": false
			}
	
	return status

func debug_print_manager_status() -> void:
	print("=== Manager Coordinator Status ===")
	print("Initialized managers: %d/%d" % [manager_ready_count, required_managers.size()])
	
	var status: Dictionary = get_manager_status()
	for manager_name in status.keys():
		var info: Dictionary = status[manager_name]
		print("%s: exists=%s, initialized=%s" % [manager_name, info.get("exists"), info.get("initialized")])
	
	print("===================================")