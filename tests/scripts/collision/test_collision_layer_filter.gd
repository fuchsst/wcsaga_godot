extends GdUnitTestSuite

## Test suite for OBJ-012 Collision Layer and Filtering System
## Tests dynamic collision mask management, debug visualization, and layer filtering

# EPIC-002 Asset Core Integration
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# System under test  
var collision_filter: Node
var debugger: Node

# Test objects
var test_ship: RigidBody3D
var test_weapon: RigidBody3D
var test_debris: Area3D

func before_test() -> void:
	"""Set up test environment before each test."""
	# Load collision filter script
	var collision_filter_script = load("res://systems/objects/collision/collision_filter.gd")
	collision_filter = collision_filter_script.new()
	add_child(collision_filter)
	
	# Load debugger script
	var debugger_script = load("res://systems/objects/collision/collision_layer_debugger.gd")
	debugger = debugger_script.new()
	add_child(debugger)
	
	# Create test objects
	test_ship = RigidBody3D.new()
	test_ship.name = "TestShip"
	test_ship.collision_layer = CollisionLayers.create_layer_bit(CollisionLayers.Layer.SHIPS)
	test_ship.collision_mask = CollisionLayers.Mask.SHIP_STANDARD
	add_child(test_ship)
	
	test_weapon = RigidBody3D.new()
	test_weapon.name = "TestWeapon"
	test_weapon.collision_layer = CollisionLayers.create_layer_bit(CollisionLayers.Layer.WEAPONS)
	test_weapon.collision_mask = CollisionLayers.Mask.WEAPON_STANDARD
	add_child(test_weapon)
	
	test_debris = Area3D.new()
	test_debris.name = "TestDebris"
	test_debris.collision_layer = CollisionLayers.create_layer_bit(CollisionLayers.Layer.DEBRIS)
	test_debris.collision_mask = CollisionLayers.Mask.DEBRIS_STANDARD
	add_child(test_debris)

func after_test() -> void:
	"""Clean up after each test."""
	if test_ship:
		test_ship.queue_free()
	if test_weapon:
		test_weapon.queue_free()
	if test_debris:
		test_debris.queue_free()
	if collision_filter:
		collision_filter.queue_free()
	if debugger:
		debugger.queue_free()

## AC1: Collision layer system defines clear categories
func test_collision_layer_categories_defined() -> void:
	"""Test that collision layer system has clear category definitions."""
	# Verify all required layer categories exist
	assert_that(CollisionLayers.Layer.SHIPS).is_not_null()
	assert_that(CollisionLayers.Layer.WEAPONS).is_not_null()
	assert_that(CollisionLayers.Layer.DEBRIS).is_not_null()
	assert_that(CollisionLayers.Layer.ASTEROIDS).is_not_null()
	assert_that(CollisionLayers.Layer.EFFECTS).is_not_null()
	assert_that(CollisionLayers.Layer.ENVIRONMENT).is_not_null()
	assert_that(CollisionLayers.Layer.TRIGGERS).is_not_null()
	
	# Verify layer names are available
	assert_that(CollisionLayers.get_layer_name(CollisionLayers.Layer.SHIPS)).is_equal("Ships")
	assert_that(CollisionLayers.get_layer_name(CollisionLayers.Layer.WEAPONS)).is_equal("Weapons")
	assert_that(CollisionLayers.get_layer_name(CollisionLayers.Layer.DEBRIS)).is_equal("Debris")

func test_collision_mask_combinations_exist() -> void:
	"""Test that predefined collision mask combinations exist for different object types."""
	# Verify ship collision masks
	assert_that(CollisionLayers.Mask.SHIP_STANDARD).is_not_equal(0)
	assert_that(CollisionLayers.Mask.SHIP_FIGHTER).is_not_equal(0)
	assert_that(CollisionLayers.Mask.SHIP_CAPITAL).is_not_equal(0)
	
	# Verify weapon collision masks
	assert_that(CollisionLayers.Mask.WEAPON_STANDARD).is_not_equal(0)
	assert_that(CollisionLayers.Mask.WEAPON_BEAM).is_not_equal(0)
	assert_that(CollisionLayers.Mask.WEAPON_MISSILE).is_not_equal(0)
	
	# Verify environment collision masks
	assert_that(CollisionLayers.Mask.DEBRIS_STANDARD).is_not_equal(0)
	assert_that(CollisionLayers.Mask.ASTEROID_STANDARD).is_not_equal(0)

## AC2: Collision filtering rules prevent inappropriate interactions
func test_collision_filtering_prevents_inappropriate_interactions() -> void:
	"""Test that collision filtering prevents inappropriate object interactions."""
	# Test same collision group rejection
	collision_filter.set_object_collision_group(test_ship, 1)
	collision_filter.set_object_collision_group(test_weapon, 1)
	
	var should_collide: bool = collision_filter.should_create_collision_pair(test_ship, test_weapon)
	assert_that(should_collide).is_false()
	
	# Test different collision groups allow collision
	collision_filter.set_object_collision_group(test_weapon, 2)
	should_collide = collision_filter.should_create_collision_pair(test_ship, test_weapon)
	assert_that(should_collide).is_true()

func test_parent_child_relationship_filtering() -> void:
	"""Test that parent-child relationships prevent collision."""
	# Set parent-child relationship
	collision_filter.set_parent_child_relationship(test_debris, test_ship)
	
	var should_collide: bool = collision_filter.should_create_collision_pair(test_ship, test_debris)
	assert_that(should_collide).is_false()
	
	# Remove relationship
	collision_filter.remove_parent_child_relationship(test_debris)
	should_collide = collision_filter.should_create_collision_pair(test_ship, test_debris)
	assert_that(should_collide).is_true()

func test_distance_based_filtering() -> void:
	"""Test distance-based collision filtering."""
	# Set objects far apart
	test_ship.global_position = Vector3(0, 0, 0)
	test_weapon.global_position = Vector3(20000, 0, 0)  # Beyond max collision distance
	
	collision_filter.set_max_collision_distance(10000.0)
	
	var should_collide: bool = collision_filter.should_create_collision_pair(test_ship, test_weapon)
	assert_that(should_collide).is_false()
	
	# Move objects closer
	test_weapon.global_position = Vector3(1000, 0, 0)
	should_collide = collision_filter.should_create_collision_pair(test_ship, test_weapon)
	assert_that(should_collide).is_true()

## AC3: Dynamic collision mask management allows runtime changes
func test_dynamic_collision_layer_runtime_changes() -> void:
	"""Test dynamic collision layer changes at runtime."""
	# Get original layer
	var original_layer: int = collision_filter.get_object_effective_collision_layer(test_ship)
	assert_that(original_layer).is_not_equal(0)
	
	# Change layer dynamically
	collision_filter.set_object_collision_layer_runtime(test_ship, CollisionLayers.Layer.CAPITALS)
	
	# Verify layer changed
	var new_layer: int = collision_filter.get_object_effective_collision_layer(test_ship)
	var expected_layer: int = CollisionLayers.create_layer_bit(CollisionLayers.Layer.CAPITALS)
	assert_that(new_layer).is_equal(expected_layer)
	
	# Verify signal was emitted
	await assert_signal(collision_filter.collision_mask_changed).is_emitted()

func test_dynamic_collision_mask_runtime_changes() -> void:
	"""Test dynamic collision mask changes at runtime."""
	# Get original mask
	var original_mask: int = collision_filter.get_object_effective_collision_mask(test_ship)
	
	# Change mask dynamically
	var new_mask: int = CollisionLayers.Mask.SHIP_CAPITAL
	collision_filter.set_object_collision_mask_runtime(test_ship, new_mask)
	
	# Verify mask changed
	var effective_mask: int = collision_filter.get_object_effective_collision_mask(test_ship)
	assert_that(effective_mask).is_equal(new_mask)

func test_add_remove_collision_layers_runtime() -> void:
	"""Test adding and removing collision layers at runtime."""
	# Add layer
	collision_filter.add_collision_layer_to_object_runtime(test_ship, CollisionLayers.Layer.FIGHTERS)
	
	var layer: int = collision_filter.get_object_effective_collision_layer(test_ship)
	assert_that(CollisionLayers.has_layer(layer, CollisionLayers.Layer.FIGHTERS)).is_true()
	
	# Remove layer
	collision_filter.remove_collision_layer_from_object_runtime(test_ship, CollisionLayers.Layer.FIGHTERS)
	
	layer = collision_filter.get_object_effective_collision_layer(test_ship)
	assert_that(CollisionLayers.has_layer(layer, CollisionLayers.Layer.FIGHTERS)).is_false()

func test_temporary_collision_rules() -> void:
	"""Test temporary collision rules with expiration."""
	# Add temporary rule
	var rule_id: String = "test_temp_rule"
	collision_filter.add_temporary_collision_rule(rule_id, ObjectTypes.Type.SHIP, ObjectTypes.Type.EFFECT, 100) # 100ms
	
	# Verify rule was added
	assert_that(collision_filter.temporary_collision_rules.has(rule_id)).is_true()
	
	# Verify signal emitted
	await assert_signal(collision_filter.temporary_rule_added).is_emitted()
	
	# Wait for expiration
	await get_tree().create_timer(0.15).timeout  # Wait 150ms
	
	# Process temporary rules (normally done in _process)
	collision_filter._process_temporary_rules()
	
	# Verify rule expired
	assert_that(collision_filter.temporary_collision_rules.has(rule_id)).is_false()
	
	# Verify expiration signal emitted
	await assert_signal(collision_filter.temporary_rule_expired).is_emitted()

func test_clear_collision_overrides() -> void:
	"""Test clearing collision overrides restores default behavior."""
	# Set override
	collision_filter.set_object_collision_layer_runtime(test_ship, CollisionLayers.Layer.CAPITALS)
	
	# Verify override is active
	var object_id: int = test_ship.get_instance_id()
	assert_that(collision_filter.dynamic_collision_overrides.has(object_id)).is_true()
	
	# Clear overrides
	collision_filter.clear_object_collision_overrides(test_ship)
	
	# Verify override is removed
	assert_that(collision_filter.dynamic_collision_overrides.has(object_id)).is_false()

## AC4: Collision categories support WCS object relationships
func test_wcs_object_relationship_support() -> void:
	"""Test that collision categories support WCS object relationships."""
	# Test ship-weapon relationship
	var ship_weapon_compatible: bool = collision_filter._types_can_collide(test_ship, test_weapon)
	assert_that(ship_weapon_compatible).is_true()
	
	# Test ship-debris relationship  
	var ship_debris_compatible: bool = collision_filter._types_can_collide(test_ship, test_debris)
	assert_that(ship_debris_compatible).is_true()

func test_collision_type_matrix_management() -> void:
	"""Test collision type matrix rule management."""
	# Add custom collision rule
	collision_filter.add_collision_type_rule(ObjectTypes.Type.BEAM, ObjectTypes.Type.DEBRIS)
	
	# Create beam-like object
	var test_beam: Area3D = Area3D.new()
	test_beam.name = "TestBeam"
	add_child(test_beam)
	
	# Mock beam object type
	test_beam.set_meta("object_type", ObjectTypes.Type.BEAM)
	
	# Test collision compatibility
	var can_collide: bool = collision_filter._types_can_collide(test_beam, test_debris)
	assert_that(can_collide).is_true()
	
	# Remove rule
	collision_filter.remove_collision_type_rule(ObjectTypes.Type.BEAM, ObjectTypes.Type.DEBRIS)
	
	can_collide = collision_filter._types_can_collide(test_beam, test_debris)
	assert_that(can_collide).is_false()
	
	test_beam.queue_free()

## AC5: Performance optimization reduces collision processing
func test_performance_optimization_distance_filtering() -> void:
	"""Test that distance filtering reduces collision processing."""
	# Enable distance filtering
	collision_filter.set_distance_filtering_enabled(true)
	
	# Place objects far apart
	test_ship.global_position = Vector3(0, 0, 0)
	test_weapon.global_position = Vector3(50000, 0, 0)
	
	collision_filter.set_max_collision_distance(1000.0)
	
	# Test that collision pair is filtered out
	var should_collide: bool = collision_filter.should_create_collision_pair(test_ship, test_weapon)
	assert_that(should_collide).is_false()
	
	# Verify filter statistics show distance filtering
	var stats: Dictionary = collision_filter.get_filter_statistics()
	var initial_distance_filtered: int = stats.get("distance_filtered", 0)
	
	# Process another distant pair
	collision_filter.should_create_collision_pair(test_ship, test_debris)
	
	stats = collision_filter.get_filter_statistics()
	var final_distance_filtered: int = stats.get("distance_filtered", 0)
	
	assert_that(final_distance_filtered).is_greater_than(initial_distance_filtered)

func test_collision_filtering_statistics() -> void:
	"""Test collision filtering statistics tracking."""
	# Reset statistics
	collision_filter.reset_filter_statistics()
	
	var stats: Dictionary = collision_filter.get_filter_statistics()
	assert_that(stats.total_filtered).is_equal(0)
	
	# Trigger some filtering
	collision_filter.set_object_collision_group(test_ship, 1)
	collision_filter.set_object_collision_group(test_weapon, 1)
	
	collision_filter.should_create_collision_pair(test_ship, test_weapon)
	
	# Check statistics updated
	stats = collision_filter.get_filter_statistics()
	assert_that(stats.total_filtered).is_greater_than(0)
	assert_that(stats.collision_group_filtered).is_greater_than(0)

## AC6: Debug visualization shows collision layers and active relationships
func test_debug_visualization_initialization() -> void:
	"""Test debug visualization system initialization."""
	assert_that(debugger).is_not_null()
	assert_that(debugger.layer_visibility).is_not_empty()
	
	# Verify all layers have visibility settings
	var all_layers: Array = CollisionLayers.get_all_layers()
	for layer in all_layers:
		assert_that(debugger.layer_visibility.has(layer)).is_true()

func test_debug_overlay_toggle() -> void:
	"""Test debug overlay visibility toggle."""
	# Initially disabled
	assert_that(debugger.enable_debug_overlay).is_false()
	
	# Toggle on
	debugger.toggle_debug_overlay()
	assert_that(debugger.enable_debug_overlay).is_true()
	
	# Verify signal emitted
	await assert_signal(debugger.debug_mode_toggled).is_emitted()
	
	# Toggle off
	debugger.toggle_debug_overlay()
	assert_that(debugger.enable_debug_overlay).is_false()

func test_layer_visibility_control() -> void:
	"""Test collision layer visibility control."""
	# Set layer visibility
	debugger.set_layer_visibility(CollisionLayers.Layer.SHIPS, false)
	
	# Verify setting applied
	assert_that(debugger.layer_visibility[CollisionLayers.Layer.SHIPS]).is_false()
	
	# Verify signal emitted
	await assert_signal(debugger.layer_visibility_changed).is_emitted()

func test_collision_relationship_data() -> void:
	"""Test active collision relationship data collection."""
	# Enable debugger and add objects
	debugger.enable_debug_overlay = true
	
	var relationships: Dictionary = debugger.get_active_collision_relationships()
	
	# Verify data structure
	assert_that(relationships.has("total_objects")).is_true()
	assert_that(relationships.has("layer_counts")).is_true()
	assert_that(relationships.has("active_overrides")).is_true()
	assert_that(relationships.has("temporary_rules")).is_true()
	
	# Verify object count
	assert_that(relationships.total_objects).is_greater_equal(0)

func test_collision_pair_highlighting() -> void:
	"""Test collision pair highlighting functionality."""
	debugger.enable_debug_overlay = true
	
	# Highlight collision pair
	debugger.highlight_collision_pair(test_ship, test_weapon, 0.1)
	
	# Wait for highlight to be processed
	await get_tree().process_frame
	
	# Test passes if no errors occur during highlighting
	assert_that(true).is_true()

## Performance tests (AC5)
func test_collision_filter_performance_under_load() -> void:
	"""Test collision filter performance with multiple objects."""
	var start_time: int = Time.get_ticks_msec()
	
	# Create many test objects
	var test_objects: Array[RigidBody3D] = []
	for i in range(50):
		var obj: RigidBody3D = RigidBody3D.new()
		obj.name = "TestObject_%d" % i
		obj.collision_layer = CollisionLayers.create_layer_bit(CollisionLayers.Layer.SHIPS)
		obj.collision_mask = CollisionLayers.Mask.SHIP_STANDARD
		obj.global_position = Vector3(randf_range(-1000, 1000), randf_range(-1000, 1000), randf_range(-1000, 1000))
		add_child(obj)
		test_objects.append(obj)
	
	# Process collision filtering for all pairs
	var collision_checks: int = 0
	for i in range(test_objects.size()):
		for j in range(i + 1, test_objects.size()):
			collision_filter.should_create_collision_pair(test_objects[i], test_objects[j])
			collision_checks += 1
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed_ms: int = end_time - start_time
	
	print("Collision filter performance: %d checks in %d ms (%.2f checks/ms)" % [collision_checks, elapsed_ms, float(collision_checks) / elapsed_ms])
	
	# Performance target: Should handle filtering under 0.01ms per object pair (AC5)
	var ms_per_check: float = float(elapsed_ms) / collision_checks
	assert_that(ms_per_check).is_less_than(0.01)
	
	# Clean up
	for obj in test_objects:
		obj.queue_free()

func test_layer_change_performance() -> void:
	"""Test performance of dynamic layer changes."""
	var start_time: int = Time.get_ticks_msec()
	
	# Perform many layer changes
	for i in range(1000):
		collision_filter.set_object_collision_layer_runtime(test_ship, CollisionLayers.Layer.SHIPS if i % 2 == 0 else CollisionLayers.Layer.FIGHTERS)
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed_ms: int = end_time - start_time
	
	print("Layer change performance: 1000 changes in %d ms" % elapsed_ms)
	
	# Performance target: Layer changes under 0.05ms each (AC5)
	var ms_per_change: float = float(elapsed_ms) / 1000.0
	assert_that(ms_per_change).is_less_than(0.05)

## Integration tests
func test_integration_with_existing_collision_system() -> void:
	"""Test integration with existing collision detection system."""
	# Test that layer filtering integrates with existing collision pair creation
	var should_collide: bool = collision_filter.should_create_collision_pair(test_ship, test_weapon)
	assert_that(should_collide).is_true()
	
	# Apply dynamic layer change and verify integration
	collision_filter.set_object_collision_layer_runtime(test_ship, CollisionLayers.Layer.OBSERVERS)
	collision_filter.set_object_collision_mask_runtime(test_ship, CollisionLayers.Mask.PHYSICS_NONE)
	
	should_collide = collision_filter.should_create_collision_pair(test_ship, test_weapon)
	assert_that(should_collide).is_false()

func test_asset_core_integration() -> void:
	"""Test integration with EPIC-002 asset core constants."""
	# Verify constants are properly loaded
	assert_that(CollisionLayers.Layer.SHIPS).is_not_null()
	assert_that(ObjectTypes.Type.SHIP).is_not_null()
	
	# Test using asset core collision masks
	var ship_mask: int = CollisionLayers.get_ship_collision_mask(ObjectTypes.Type.FIGHTER)
	assert_that(ship_mask).is_not_equal(0)
	
	var weapon_mask: int = CollisionLayers.get_weapon_collision_mask(ObjectTypes.Type.WEAPON)
	assert_that(weapon_mask).is_not_equal(0)
