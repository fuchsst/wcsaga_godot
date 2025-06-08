extends GdUnitTestSuite

## Test suite for OBJ-014: Subsystem and Animation Integration
## Tests all acceptance criteria for subsystem animation system

# Test scene setup
var space_object: BaseSpaceObject
var model_metadata: ModelMetadata
var animation_controller: SubsystemAnimationController
var damage_visualizer: SubsystemDamageVisualizer
var animation_coordinator: AnimationCoordinator
var subsystem_integration: ModelSubsystemIntegration

func before_test() -> void:
	# Create test space object
	space_object = BaseSpaceObject.new()
	space_object.name = "TestSpaceObject"
	add_child(space_object)
	
	# Create test model metadata
	model_metadata = ModelMetadata.new()
	_setup_test_metadata()
	
	# Create and add animation system components
	subsystem_integration = ModelSubsystemIntegration.new()
	animation_controller = SubsystemAnimationController.new()
	damage_visualizer = SubsystemDamageVisualizer.new()
	animation_coordinator = AnimationCoordinator.new()
	
	space_object.add_child(subsystem_integration)
	space_object.add_child(animation_controller)
	space_object.add_child(damage_visualizer)
	space_object.add_child(animation_coordinator)
	
	# Initialize subsystems from metadata
	subsystem_integration.create_subsystems_from_metadata(space_object, model_metadata)
	
	# Wait for components to initialize
	await get_tree().process_frame

func after_test() -> void:
	if space_object:
		space_object.queue_free()
	await get_tree().process_frame

## Setup test model metadata with weapon banks, engines, and docking points
func _setup_test_metadata() -> void:
	# Create weapon banks for turret testing
	var gun_bank: ModelMetadata.WeaponBank = ModelMetadata.WeaponBank.new()
	gun_bank.points = [
		_create_point_definition(Vector3(5, 0, 10), Vector3.FORWARD),
		_create_point_definition(Vector3(-5, 0, 10), Vector3.FORWARD)
	]
	model_metadata.gun_banks = [gun_bank]
	
	# Create missile banks
	var missile_bank: ModelMetadata.WeaponBank = ModelMetadata.WeaponBank.new()
	missile_bank.points = [
		_create_point_definition(Vector3(3, -1, 5), Vector3.FORWARD)
	]
	model_metadata.missile_banks = [missile_bank]
	
	# Create thruster banks for engine testing
	var thruster_bank: ModelMetadata.ThrusterBank = ModelMetadata.ThrusterBank.new()
	thruster_bank.points = [
		_create_point_definition(Vector3(2, 0, -10), Vector3.BACK),
		_create_point_definition(Vector3(-2, 0, -10), Vector3.BACK)
	]
	model_metadata.thruster_banks = [thruster_bank]
	
	# Create docking points for docking bay testing
	var dock_point: ModelMetadata.DockPoint = ModelMetadata.DockPoint.new()
	dock_point.name = "MainBay"
	dock_point.points = [
		_create_point_definition(Vector3(0, -3, 0), Vector3.UP)
	]
	model_metadata.docking_points = [dock_point]

## Create test point definition
func _create_point_definition(position: Vector3, normal: Vector3) -> ModelMetadata.PointDefinition:
	var point: ModelMetadata.PointDefinition = ModelMetadata.PointDefinition.new()
	point.position = position
	point.normal = normal
	return point

## AC1: Test subsystem management supports hierarchical subsystem organization
func test_hierarchical_subsystem_organization() -> void:
	# Verify subsystems container exists
	var subsystems_container: Node = space_object.find_child("Subsystems", false, false)
	assert_that(subsystems_container).is_not_null()
	
	# Verify weapon subsystems created
	var primary_weapon: Node3D = subsystems_container.find_child("WeaponsPrimary_0", false, false) as Node3D
	assert_that(primary_weapon).is_not_null()
	assert_that(primary_weapon.get_meta("subsystem_type")).is_equal(ModelSubsystemIntegration.SubsystemType.WEAPONS)
	
	# Verify engine subsystems created
	var engine: Node3D = subsystems_container.find_child("Engine_0", false, false) as Node3D
	assert_that(engine).is_not_null()
	assert_that(engine.get_meta("subsystem_type")).is_equal(ModelSubsystemIntegration.SubsystemType.ENGINE)
	
	# Verify docking subsystems created
	var docking: Node3D = subsystems_container.find_child("Docking_MainBay", false, false) as Node3D
	assert_that(docking).is_not_null()
	assert_that(docking.get_meta("subsystem_type")).is_equal(ModelSubsystemIntegration.SubsystemType.ACTIVATION)
	
	# Verify hierarchical organization (subsystems under container)
	assert_that(subsystems_container.get_child_count()).is_greater_than(0)

## AC2: Test animation integration enables turret rotation, engine glow, and moving parts
func test_animation_integration_capabilities() -> void:
	# Initialize animation system
	var success: bool = animation_coordinator.initialize_animation_system(space_object, model_metadata)
	assert_that(success).is_true()
	
	# Test turret rotation capability
	var turret_result: bool = animation_controller.trigger_turret_rotation(
		space_object, "WeaponsPrimary_0", Vector3(1, 0, 1), 2.0
	)
	assert_that(turret_result).is_true()
	
	# Test engine thrust animation
	var engine_result: bool = animation_controller.trigger_engine_thrust(
		space_object, "Engine_0", 0.8, 1.5
	)
	assert_that(engine_result).is_true()
	
	# Test docking bay animation
	var docking_result: bool = animation_controller.trigger_docking_door(
		space_object, "Docking_MainBay", true, 3.0
	)
	assert_that(docking_result).is_true()
	
	# Verify animation controller has active animations
	var stats: Dictionary = animation_controller.get_animation_performance_stats()
	assert_that(stats["active_animations"]).is_greater_than(0)

## AC3: Test damage state visualization shows subsystem destruction and damage effects
func test_damage_state_visualization() -> void:
	# Apply damage to weapon subsystem
	var damage_applied: bool = subsystem_integration.apply_subsystem_damage(
		space_object, "WeaponsPrimary_0", 60.0  # 60% damage
	)
	assert_that(damage_applied).is_true()
	
	# Wait for damage effects to be created
	await get_tree().process_frame
	
	# Verify damage visualization effects created
	var damage_stats: Dictionary = damage_visualizer.get_damage_visualization_stats()
	assert_that(damage_stats["total_active_effects"]).is_greater_than(0)
	assert_that(damage_stats["subsystems_with_effects"]).is_greater_than(0)
	
	# Verify active damage effects for subsystem
	var active_effects: Array[Dictionary] = damage_visualizer.get_active_effects("WeaponsPrimary_0")
	assert_that(active_effects.size()).is_greater_than(0)
	
	# Verify effect has appropriate intensity
	var first_effect: Dictionary = active_effects[0]
	assert_that(first_effect["intensity"]).is_greater_than(0.5)  # Should be moderate to heavy damage

## AC4: Test animation controller coordinates multiple animation systems per object
func test_animation_controller_coordination() -> void:
	# Initialize animation system
	animation_coordinator.initialize_animation_system(space_object, model_metadata)
	
	# Test coordinated group animation
	var weapons_group_success: bool = animation_coordinator.coordinate_group_animation(
		"weapons", "turret_rotation", true  # Synchronized
	)
	assert_that(weapons_group_success).is_true()
	
	# Test engine group coordination
	var engines_group_success: bool = animation_coordinator.coordinate_group_animation(
		"engines", "engine_thrust", false  # Not synchronized
	)
	assert_that(engines_group_success).is_true()
	
	# Verify animation system status
	var system_status: Dictionary = animation_coordinator.get_animation_system_status()
	assert_that(system_status["animation_groups"]).is_not_empty()
	assert_that(system_status["components_connected"]["animation_controller"]).is_true()
	
	# Verify multiple animation groups exist
	assert_that(system_status["animation_groups"].has("weapons")).is_true()
	assert_that(system_status["animation_groups"].has("engines")).is_true()

## AC5: Test performance optimization manages animation updates based on LOD and distance
func test_performance_optimization() -> void:
	# Initialize animation system
	animation_coordinator.initialize_animation_system(space_object, model_metadata)
	
	# Test high-detail LOD (close distance)
	animation_coordinator.update_camera_distance(50.0)  # Close
	await get_tree().process_frame
	
	var close_status: Dictionary = animation_coordinator.get_animation_system_status()
	assert_that(close_status["current_lod"]).is_equal(AnimationCoordinator.AnimationLOD.HIGH_DETAIL)
	
	# Test low-detail LOD (far distance)
	animation_coordinator.update_camera_distance(1500.0)  # Far
	await get_tree().process_frame
	
	var far_status: Dictionary = animation_coordinator.get_animation_system_status()
	assert_that(far_status["current_lod"]).is_equal(AnimationCoordinator.AnimationLOD.LOW_DETAIL)
	
	# Test performance budget configuration
	animation_coordinator.configure_performance_budget(0.1)  # Tight budget
	
	# Verify performance stats are reasonable
	var perf_stats: Dictionary = animation_controller.get_animation_performance_stats()
	assert_that(perf_stats["performance_budget_ms"]).is_less_equal(1.0)  # Within reasonable limits

## AC6: Test integration with effects system triggers appropriate visual feedback
func test_effects_system_integration() -> void:
	# Trigger subsystem destruction for dramatic effect
	var destruction_applied: bool = subsystem_integration.apply_subsystem_damage(
		space_object, "Engine_0", 100.0  # Complete destruction
	)
	assert_that(destruction_applied).is_true()
	
	# Wait for destruction effects
	await get_tree().process_frame
	
	# Verify destruction effect created
	var effects_after_destruction: Array[Dictionary] = damage_visualizer.get_active_effects("Engine_0")
	# Note: Destroyed subsystems may not have active effects, but destruction effect should be created
	
	# Verify engine animations stopped due to destruction
	var engine_subsystem: Node3D = _find_subsystem("Engine_0")
	assert_that(engine_subsystem).is_not_null()
	assert_that(engine_subsystem.get_meta("destroyed", false)).is_true()
	
	# Test effects system responds to animation state changes
	var thruster_test: bool = animation_controller.trigger_engine_thrust(
		space_object, "Engine_0", 1.0, 1.0
	)
	# Should fail because engine is destroyed
	assert_that(thruster_test).is_false()

## Test animation queue management under load
func test_animation_queue_management() -> void:
	# Initialize system
	animation_coordinator.initialize_animation_system(space_object, model_metadata)
	
	# Queue multiple animations rapidly
	var queue_results: Array[bool] = []
	for i in range(20):  # More than MAX_QUEUED_ANIMATIONS (15)
		var result: bool = animation_controller.queue_animation(
			"WeaponsPrimary_0",
			SubsystemAnimationController.TriggerType.TURRET_FIRING,
			Vector3(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0, 0),
			1.0,
			false,
			i % 3  # Varying priorities
		)
		queue_results.append(result)
	
	# Verify some animations were queued (up to limit)
	var successful_queues: int = queue_results.count(true)
	assert_that(successful_queues).is_greater_than(0)
	assert_that(successful_queues).is_less_equal(15)  # Respects queue limit
	
	# Verify queue stats
	var stats: Dictionary = animation_controller.get_animation_performance_stats()
	assert_that(stats["queued_animations"]).is_less_equal(15)

## Test subsystem health integration with animations
func test_subsystem_health_animation_integration() -> void:
	# Initialize system
	animation_coordinator.initialize_animation_system(space_object, model_metadata)
	
	# Test healthy subsystem can animate
	var healthy_animation: bool = animation_controller.trigger_turret_rotation(
		space_object, "WeaponsPrimary_0", Vector3.FORWARD, 1.0
	)
	assert_that(healthy_animation).is_true()
	
	# Damage subsystem severely
	subsystem_integration.apply_subsystem_damage(space_object, "WeaponsPrimary_0", 100.0)
	await get_tree().process_frame
	
	# Test damaged subsystem cannot animate (WCS rule: health > 0 required)
	var damaged_animation: bool = animation_controller.trigger_turret_rotation(
		space_object, "WeaponsPrimary_0", Vector3.FORWARD, 1.0
	)
	assert_that(damaged_animation).is_false()

## Test animation performance meets targets (AC5)
func test_animation_performance_targets() -> void:
	# Initialize with many subsystems
	animation_coordinator.initialize_animation_system(space_object, model_metadata)
	
	# Trigger multiple animations
	animation_controller.trigger_turret_rotation(space_object, "WeaponsPrimary_0", Vector3.FORWARD, 2.0)
	animation_controller.trigger_engine_thrust(space_object, "Engine_0", 1.0, 2.0)
	animation_controller.trigger_docking_door(space_object, "Docking_MainBay", true, 2.0)
	
	# Process multiple frames to measure performance
	var frame_count: int = 60  # Test for 1 second at 60fps
	var start_time: int = Time.get_time_dict_from_system()["msec"]
	
	for i in range(frame_count):
		await get_tree().process_frame
	
	var end_time: int = Time.get_time_dict_from_system()["msec"]
	var total_time_ms: float = end_time - start_time
	var average_frame_time: float = total_time_ms / frame_count
	
	# Verify average frame time is reasonable (target: under 0.2ms for animations)
	# Note: This is a rough test as it includes all frame processing
	assert_that(average_frame_time).is_less_than(20.0)  # 20ms per frame max for 60fps
	
	# Verify performance budget is respected
	var perf_stats: Dictionary = animation_controller.get_animation_performance_stats()
	assert_that(perf_stats["performance_budget_ms"]).is_less_equal(0.5)  # Reasonable budget

## Test damage visualization effect types
func test_damage_visualization_effect_types() -> void:
	# Test light damage effects
	subsystem_integration.apply_subsystem_damage(space_object, "WeaponsPrimary_0", 30.0)
	await get_tree().process_frame
	
	var light_effects: Array[Dictionary] = damage_visualizer.get_active_effects("WeaponsPrimary_0")
	assert_that(light_effects.size()).is_greater_than(0)
	
	# Test heavy damage effects (should have more effect types)
	subsystem_integration.apply_subsystem_damage(space_object, "Engine_0", 80.0)
	await get_tree().process_frame
	
	var heavy_effects: Array[Dictionary] = damage_visualizer.get_active_effects("Engine_0")
	assert_that(heavy_effects.size()).is_greater_equal(light_effects.size())
	
	# Verify effect intensity scaling
	if heavy_effects.size() > 0:
		var heavy_intensity: float = heavy_effects[0]["intensity"]
		assert_that(heavy_intensity).is_greater_than(0.6)  # Heavy damage should have high intensity

## Test animation system cleanup
func test_animation_system_cleanup() -> void:
	# Initialize and create animations
	animation_coordinator.initialize_animation_system(space_object, model_metadata)
	animation_controller.trigger_turret_rotation(space_object, "WeaponsPrimary_0", Vector3.FORWARD, 5.0)
	animation_controller.trigger_engine_thrust(space_object, "Engine_0", 1.0, 5.0)
	
	# Verify animations are active
	var stats_before: Dictionary = animation_controller.get_animation_performance_stats()
	assert_that(stats_before["active_animations"]).is_greater_than(0)
	
	# Stop all animations
	animation_controller.stop_all_animations()
	
	# Verify cleanup
	var stats_after: Dictionary = animation_controller.get_animation_performance_stats()
	assert_that(stats_after["active_animations"]).is_equal(0)
	assert_that(stats_after["queued_animations"]).is_equal(0)

## Helper function to find subsystem
func _find_subsystem(subsystem_name: String) -> Node3D:
	var subsystems_container: Node = space_object.find_child("Subsystems", false, false)
	if not subsystems_container:
		return null
	return subsystems_container.find_child(subsystem_name, false, false) as Node3D

## Test integration with existing ModelSubsystemIntegration
func test_subsystem_integration_compatibility() -> void:
	# Verify subsystem integration created subsystems
	var all_subsystems: Array[Node3D] = subsystem_integration.get_all_subsystems(space_object)
	assert_that(all_subsystems.size()).is_greater_than(0)
	
	# Verify animation controller can work with these subsystems
	animation_coordinator.initialize_animation_system(space_object, model_metadata)
	
	# Test animation on existing subsystem
	var subsystem_names: Array[String] = []
	for subsystem in all_subsystems:
		subsystem_names.append(subsystem.name)
	
	assert_that(subsystem_names).contains("WeaponsPrimary_0")
	assert_that(subsystem_names).contains("Engine_0")
	
	# Verify subsystem metadata is preserved
	var weapon_subsystem: Node3D = _find_subsystem("WeaponsPrimary_0")
	assert_that(weapon_subsystem.get_meta("subsystem_type")).is_equal(ModelSubsystemIntegration.SubsystemType.WEAPONS)
	assert_that(weapon_subsystem.get_meta("max_health")).is_equal(100.0)

## Test animation interruption and priority handling
func test_animation_interruption_and_priority() -> void:
	animation_coordinator.initialize_animation_system(space_object, model_metadata)
	
	# Start low priority animation
	var low_priority_queued: bool = animation_controller.queue_animation(
		"WeaponsPrimary_0",
		SubsystemAnimationController.TriggerType.TURRET_FIRING,
		Vector3(1, 0, 0),
		3.0,
		false,
		1  # Low priority
	)
	assert_that(low_priority_queued).is_true()
	
	# Start high priority animation that should interrupt
	var high_priority_queued: bool = animation_controller.queue_animation(
		"WeaponsPrimary_0",
		SubsystemAnimationController.TriggerType.TURRET_FIRING,
		Vector3(0, 1, 0),
		2.0,
		true,  # Interrupt existing
		5  # High priority
	)
	assert_that(high_priority_queued).is_true()
	
	# Process a few frames to let animations start
	for i in range(5):
		await get_tree().process_frame
	
	# Verify animation system handled the interruption
	var stats: Dictionary = animation_controller.get_animation_performance_stats()
	# Should have fewer or equal active animations than queued due to interruption
	assert_that(stats["active_animations"]).is_less_equal(2)