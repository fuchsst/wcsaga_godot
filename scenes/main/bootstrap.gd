extends Node2D

## Bootstrap scene for WCS-Godot
## Initializes core managers and tests basic functionality

func _ready() -> void:
	print("Bootstrap: Starting WCS-Godot initialization...")
	
	# Wait a frame for autoloads to initialize
	await get_tree().process_frame
	
	# Test core managers
	_test_core_managers()
	
	# Wait for manager initialization
	await get_tree().create_timer(2.0).timeout
	
	# Start the game by transitioning to the intro scene
	if SceneManager:
		SceneManager.change_scene("intro",
			SceneManager.create_options(0.1, "fade"),  # fade out options
			SceneManager.create_options(1.0, "fade"),  # fade in options
			SceneManager.create_general_options(Color.BLACK))  # general options
	else:
		# Fallback if SceneManager is not available
		print("Bootstrap: SceneManager not available, staying in bootstrap")

func _test_core_managers() -> void:
	print("Bootstrap: Testing core managers...")
	
	# Test ObjectManager
	if ObjectManager:
		print("✓ ObjectManager found")
		# Test object creation
		var test_data: WCSObjectData = WCSObjectData.new()
		test_data.object_type = "test_ship"
		var test_object: WCSObject = ObjectManager.create_object("test_ship", test_data)
		if test_object:
			print("✓ ObjectManager: Test object created successfully")
			ObjectManager.destroy_object(test_object)
			print("✓ ObjectManager: Test object destroyed successfully")
		else:
			print("✗ ObjectManager: Failed to create test object")
	else:
		print("✗ ObjectManager not found")
	
	# Test GameStateManager
	if GameStateManager:
		print("✓ GameStateManager found")
		var current_state = GameStateManager.get_current_state()
		print("✓ GameStateManager: Current state is %s" % str(current_state))
	else:
		print("✗ GameStateManager not found")
	
	# Test PhysicsManager
	if PhysicsManager:
		print("✓ PhysicsManager found")
		var body_count: int = PhysicsManager.get_physics_body_count()
		print("✓ PhysicsManager: %d physics bodies registered" % body_count)
	else:
		print("✗ PhysicsManager not found")
	
	# Test InputManager
	if InputManager:
		print("✓ InputManager found")
		var scheme = InputManager.get_current_control_scheme()
		print("✓ InputManager: Current control scheme is %s" % str(scheme))
	else:
		print("✗ InputManager not found")
	
	print("Bootstrap: Core manager testing complete")

func _input(event: InputEvent) -> void:
	# Test input handling
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed:
			match key_event.keycode:
				KEY_F1:
					_debug_print_manager_status()
				KEY_F2:
					_test_object_creation()
				KEY_F3:
					# F3 is handled by debug overlay
					pass
				KEY_F4:
					_test_physics_system()

func _debug_print_manager_status() -> void:
	print("=== Bootstrap Debug Status ===")
	
	if ObjectManager:
		print("ObjectManager stats: %s" % ObjectManager.get_performance_stats())
	
	if GameStateManager:
		print("GameStateManager stats: %s" % GameStateManager.get_performance_stats())
	
	if PhysicsManager:
		print("PhysicsManager stats: %s" % PhysicsManager.get_performance_stats())
	
	if InputManager:
		print("InputManager stats: %s" % InputManager.get_performance_stats())
	
	print("==============================")

func _test_object_creation() -> void:
	print("Bootstrap: Testing object creation...")
	
	if not ObjectManager:
		print("ObjectManager not available")
		return
	
	# Create multiple test objects
	for i in range(5):
		var test_data: WCSObjectData = WCSObjectData.new()
		test_data.object_type = "test_ship_%d" % i
		test_data.position = Vector3(i * 100, 0, 0)
		
		var test_object: WCSObject = ObjectManager.create_object("test_ship", test_data)
		if test_object:
			print("Created test object %d at position %s" % [i, test_object.position])
		else:
			print("Failed to create test object %d" % i)
	
	print("Test objects created. Current object count: %d" % ObjectManager.get_active_object_count())

func _test_physics_system() -> void:
	print("Bootstrap: Testing physics system...")
	
	if not PhysicsManager:
		print("PhysicsManager not available")
		return
	
	# Create a test physics body
	var test_body: CustomPhysicsBody = CustomPhysicsBody.new()
	test_body.set_position(Vector3.ZERO)
	test_body.set_velocity(Vector3(10, 0, 0))
	test_body.set_mass(1.0)
	
	add_child(test_body)
	
	if PhysicsManager.register_physics_body(test_body):
		print("Test physics body registered successfully")
	else:
		print("Failed to register test physics body")
	
	# Schedule cleanup
	await get_tree().create_timer(5.0).timeout
	PhysicsManager.unregister_physics_body(test_body)
	test_body.queue_free()
	print("Test physics body cleaned up")
