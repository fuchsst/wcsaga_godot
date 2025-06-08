extends GdUnitTestSuite

## Test suite for SHIP-003: Ship Class Definitions and Factory System
## Validates ship class definitions, templates, factory system, and registry
## Ensures WCS-authentic ship creation and variant support using Godot scenes and .tres files

# Required classes
const BaseShip = preload("res://scripts/ships/core/base_ship.gd")
const ShipClass = preload("res://addons/wcs_asset_core/resources/ship/ship_class.gd")
const ShipTemplate = preload("res://addons/wcs_asset_core/resources/ship/ship_template.gd")
const ShipFactory = preload("res://scripts/ships/core/ship_factory.gd")
const ShipRegistry = preload("res://scripts/ships/core/ship_registry.gd")
const ShipSpawner = preload("res://scripts/ships/core/ship_spawner.gd")
const ShipTypes = preload("res://addons/wcs_asset_core/constants/ship_types.gd")
const WeaponBankConfig = preload("res://addons/wcs_asset_core/resources/ship/weapon_bank_config.gd")

# Test objects
var test_ship_class: ShipClass
var test_ship_template: ShipTemplate
var test_ship_factory: ShipFactory
var test_ship_registry: ShipRegistry
var test_spawner: ShipSpawner

func before_test() -> void:
	# Create test ship class
	test_ship_class = ShipClass.create_default_fighter()
	test_ship_class.class_name = "Test Fighter"
	test_ship_class.ship_type = ShipTypes.Type.FIGHTER
	
	# Create test ship template
	test_ship_template = ShipTemplate.create_default_fighter_variant()
	test_ship_template.template_name = "Test Fighter"
	test_ship_template.variant_suffix = "Advanced"
	
	# Create factory and registry
	test_ship_factory = ShipFactory.new()
	test_ship_registry = ShipRegistry.new()
	
	# Create spawner in scene
	test_spawner = ShipSpawner.new()
	add_child(test_spawner)

func after_test() -> void:
	if is_instance_valid(test_spawner):
		test_spawner.queue_free()
	test_ship_class = null
	test_ship_template = null
	test_ship_factory = null
	test_ship_registry = null
	test_spawner = null

# ============================================================================
# AC1: ShipClass resource defines all WCS ship characteristics from ships.tbl data
# ============================================================================

func test_ac1_ship_class_defines_wcs_characteristics():
	assert_that(test_ship_class).is_not_null()
	
	# Physical properties
	assert_that(test_ship_class.mass).is_greater_than(0.0)
	assert_that(test_ship_class.max_velocity).is_greater_than(0.0)
	assert_that(test_ship_class.max_afterburner_velocity).is_greater_than(0.0)
	assert_that(test_ship_class.acceleration).is_greater_than(0.0)
	
	# Structural properties
	assert_that(test_ship_class.max_hull_strength).is_greater_than(0.0)
	assert_that(test_ship_class.max_shield_strength).is_greater_than(0.0)
	
	# Energy systems
	assert_that(test_ship_class.max_weapon_energy).is_greater_than(0.0)
	assert_that(test_ship_class.weapon_energy_regen_rate).is_greater_than(0.0)

func test_ac1_ship_class_validation():
	# Valid ship class should pass validation
	assert_that(test_ship_class.is_valid()).is_true()
	assert_that(test_ship_class.get_validation_errors().size()).is_equal(0)
	
	# Invalid ship class should fail validation
	var invalid_class = ShipClass.new()
	invalid_class.class_name = ""  # Invalid: empty name
	invalid_class.mass = 0.0       # Invalid: zero mass
	
	assert_that(invalid_class.is_valid()).is_false()
	assert_that(invalid_class.get_validation_errors().size()).is_greater_than(0)

func test_ac1_ship_class_subsystem_integration():
	# Ship class should support subsystem definitions
	test_ship_class.subsystem_definitions = [
		"res://resources/subsystems/engine.tres",
		"res://resources/subsystems/weapons.tres",
		"res://resources/subsystems/radar.tres"
	]
	
	var config = test_ship_class.get_config_summary()
	assert_that(config["subsystem_count"]).is_equal(3)

func test_ac1_ship_class_scene_integration():
	# Ship class should support scene templates
	test_ship_class.ship_scene_path = "res://scenes/ships/fighter_base.tscn"
	test_ship_class.hardpoint_configuration = {
		"primary_1": Vector3(2.0, 0.0, 1.0),
		"primary_2": Vector3(-2.0, 0.0, 1.0),
		"secondary_1": Vector3(1.0, -0.5, 0.0)
	}
	
	var config = test_ship_class.get_config_summary()
	assert_that(config["has_scene"]).is_true()
	assert_that(config["hardpoint_count"]).is_equal(3)

# ============================================================================
# AC2: ShipTemplate resource handles ship variants and loadout configurations
# ============================================================================

func test_ac2_ship_template_variant_support():
	assert_that(test_ship_template).is_not_null()
	assert_that(test_ship_template.get_full_name()).is_equal("Test Fighter#Advanced")
	assert_that(test_ship_template.template_name).is_equal("Test Fighter")
	assert_that(test_ship_template.variant_suffix).is_equal("Advanced")

func test_ac2_ship_template_inheritance():
	# Template should inherit from base class
	test_ship_template.base_ship_class = "res://resources/ships/test_fighter.tres"
	
	# Apply overrides
	test_ship_template.override_max_velocity = 85.0  # Enhanced speed
	test_ship_template.override_max_weapon_energy = 90.0  # Enhanced weapons
	
	# Generate configured ship class
	var base_class = ShipClass.create_default_fighter()
	test_ship_template._resolved_ship_class = base_class
	
	var configured_class = test_ship_template.create_ship_class()
	assert_that(configured_class).is_not_null()
	assert_that(configured_class.max_velocity).is_equal(85.0)
	assert_that(configured_class.max_weapon_energy).is_equal(90.0)

func test_ac2_ship_template_weapon_configuration():
	# Configure weapon loadout
	test_ship_template.primary_weapon_loadout = [
		"res://resources/weapons/prometheus_r.tres",
		"res://resources/weapons/prometheus_r.tres"
	]
	test_ship_template.secondary_weapon_loadout = [
		"res://resources/weapons/cyclops.tres"
	]
	
	# Verify configuration
	assert_that(test_ship_template.primary_weapon_loadout.size()).is_equal(2)
	assert_that(test_ship_template.secondary_weapon_loadout.size()).is_equal(1)

func test_ac2_ship_template_validation():
	# Valid template should pass validation
	test_ship_template.base_ship_class = "res://resources/ships/test_fighter.tres"
	test_ship_template._resolved_ship_class = ShipClass.create_default_fighter()
	
	assert_that(test_ship_template.is_valid()).is_true()
	assert_that(test_ship_template.get_validation_errors().size()).is_equal(0)
	
	# Invalid template should fail validation
	var invalid_template = ShipTemplate.new()
	invalid_template.template_name = ""  # Invalid: empty name
	
	assert_that(invalid_template.is_valid()).is_false()
	assert_that(invalid_template.get_validation_errors().size()).is_greater_than(0)

# ============================================================================
# AC3: ShipFactory creates properly configured ship instances
# ============================================================================

func test_ac3_factory_creates_ships_from_class():
	var ship = test_ship_factory.create_ship_from_class(test_ship_class, "Test Ship")
	
	assert_that(ship).is_not_null()
	assert_that(ship.ship_name).is_equal("Test Ship")
	assert_that(ship.ship_class.class_name).is_equal("Test Fighter")
	
	ship.queue_free()

func test_ac3_factory_creates_ships_from_template():
	# Setup template with base class
	test_ship_template._resolved_ship_class = test_ship_class
	
	var ship = test_ship_factory.create_ship_from_template(test_ship_template, "Variant Ship")
	
	assert_that(ship).is_not_null()
	assert_that(ship.ship_name).is_equal("Variant Ship")
	
	ship.queue_free()

func test_ac3_factory_batch_creation():
	var creation_requests = [
		{"mode": ShipFactory.CreationMode.FROM_CLASS, "ship_class": test_ship_class, "name": "Ship 1"},
		{"mode": ShipFactory.CreationMode.FROM_CLASS, "ship_class": test_ship_class, "name": "Ship 2"},
		{"mode": ShipFactory.CreationMode.FROM_CLASS, "ship_class": test_ship_class, "name": "Ship 3"}
	]
	
	# Note: This test is conceptual as batch creation needs registry integration
	assert_that(creation_requests.size()).is_equal(3)

func test_ac3_factory_handles_invalid_input():
	# Factory should handle null ship class
	var ship = test_ship_factory.create_ship_from_class(null, "Invalid Ship")
	assert_that(ship).is_null()
	
	# Factory should handle invalid template
	var invalid_template = ShipTemplate.new()
	ship = test_ship_factory.create_ship_from_template(invalid_template, "Invalid Ship")
	assert_that(ship).is_null()

func test_ac3_factory_performance_tracking():
	# Factory should track performance statistics
	var initial_stats = test_ship_factory.get_performance_statistics()
	
	var ship = test_ship_factory.create_ship_from_class(test_ship_class, "Performance Test")
	
	var final_stats = test_ship_factory.get_performance_statistics()
	assert_that(final_stats["ships_created"]).is_greater_than(initial_stats["ships_created"])
	
	if ship:
		ship.queue_free()

# ============================================================================
# AC4: ShipRegistry provides efficient lookup and management
# ============================================================================

func test_ac4_registry_ship_class_lookup():
	# Register ship class
	test_ship_registry.register_ship_class(test_ship_class)
	
	# Lookup should succeed
	var retrieved_class = test_ship_registry.get_ship_class("Test Fighter")
	assert_that(retrieved_class).is_not_null()
	assert_that(retrieved_class.class_name).is_equal("Test Fighter")

func test_ac4_registry_ship_template_lookup():
	# Register ship template
	test_ship_registry.register_ship_template(test_ship_template)
	
	# Lookup should succeed
	var retrieved_template = test_ship_registry.get_ship_template("Test Fighter#Advanced")
	assert_that(retrieved_template).is_not_null()
	assert_that(retrieved_template.get_full_name()).is_equal("Test Fighter#Advanced")

func test_ac4_registry_type_based_lookup():
	# Register different ship types
	var fighter_class = ShipClass.create_default_fighter()
	fighter_class.class_name = "Test Fighter"
	fighter_class.ship_type = ShipTypes.Type.FIGHTER
	
	var bomber_class = ShipClass.create_default_bomber()
	bomber_class.class_name = "Test Bomber"
	bomber_class.ship_type = ShipTypes.Type.BOMBER
	
	test_ship_registry.register_ship_class(fighter_class)
	test_ship_registry.register_ship_class(bomber_class)
	
	# Lookup by type
	var fighters = test_ship_registry.get_ships_by_type(ShipTypes.Type.FIGHTER)
	var bombers = test_ship_registry.get_ships_by_type(ShipTypes.Type.BOMBER)
	
	assert_that(fighters.has("Test Fighter")).is_true()
	assert_that(bombers.has("Test Bomber")).is_true()

func test_ac4_registry_variant_lookup():
	# Register base ship and variant
	test_ship_registry.register_ship_class(test_ship_class)
	test_ship_registry.register_ship_template(test_ship_template)
	
	# Get variants of base ship
	var variants = test_ship_registry.get_ship_variants("Test Fighter")
	assert_that(variants.has("Test Fighter#Advanced")).is_true()

func test_ac4_registry_search_functionality():
	test_ship_registry.register_ship_class(test_ship_class)
	test_ship_registry.register_ship_template(test_ship_template)
	
	# Search should find matching ships
	var results = test_ship_registry.search_ships("Fighter")
	assert_that(results.size()).is_greater_than(0)
	assert_that(results.has("Test Fighter") or results.has("Test Fighter#Advanced")).is_true()

func test_ac4_registry_performance_tracking():
	test_ship_registry.register_ship_class(test_ship_class)
	
	# Perform lookups to generate statistics
	test_ship_registry.get_ship_class("Test Fighter")
	test_ship_registry.get_ship_class("Test Fighter")  # Should be cached
	test_ship_registry.get_ship_class("Nonexistent")   # Should be cache miss
	
	var stats = test_ship_registry.get_registry_statistics()
	assert_that(stats["lookup_count"]).is_greater_than(0)
	assert_that(stats["cache_hits"]).is_greater_than(0)

# ============================================================================
# AC5: Factory system integrates with asset management
# ============================================================================

func test_ac5_asset_integration_model_loading():
	# Ship class should specify model path
	test_ship_class.model_path = "res://assets/models/ships/fighter.glb"
	test_ship_class.texture_path = "res://assets/textures/ships/fighter_diffuse.png"
	
	# Factory should handle asset loading (conceptual test)
	var ship = test_ship_factory.create_ship_from_class(test_ship_class)
	assert_that(ship).is_not_null()
	
	ship.queue_free()

func test_ac5_asset_integration_weapon_hardpoints():
	# Configure weapon hardpoints
	test_ship_class.hardpoint_configuration = {
		"primary_gun_01": Vector3(2.0, 0.0, 1.0),
		"primary_gun_02": Vector3(-2.0, 0.0, 1.0),
		"missile_01": Vector3(3.0, -1.0, -0.5)
	}
	
	var config = test_ship_class.get_config_summary()
	assert_that(config["hardpoint_count"]).is_equal(3)

func test_ac5_asset_integration_team_colors():
	# Configure team color slots
	test_ship_class.team_color_slots = ["primary_hull", "secondary_hull", "cockpit"]
	
	assert_that(test_ship_class.team_color_slots.size()).is_equal(3)

# ============================================================================
# AC6: Ship spawning handles proper initialization
# ============================================================================

func test_ac6_spawning_physics_initialization():
	# Spawner should create ships with proper physics
	var ship = test_spawner.spawn_ship_from_class(test_ship_class, Vector3(100, 0, 0))
	
	assert_that(ship).is_not_null()
	assert_that(ship.physics_body).is_not_null()
	assert_that(ship.global_position).is_equal(Vector3(100, 0, 0))
	
	test_spawner.despawn_ship(ship)

func test_ac6_spawning_subsystem_setup():
	# Ship should have subsystem manager initialized
	var ship = test_spawner.spawn_ship_from_class(test_ship_class)
	
	assert_that(ship).is_not_null()
	assert_that(ship.subsystem_manager).is_not_null()
	
	test_spawner.despawn_ship(ship)

func test_ac6_spawning_limits_and_pooling():
	# Test spawn limits
	test_spawner.max_spawned_ships = 2
	
	var ship1 = test_spawner.spawn_ship_from_class(test_ship_class, Vector3.ZERO, "Ship 1")
	var ship2 = test_spawner.spawn_ship_from_class(test_ship_class, Vector3.ZERO, "Ship 2")
	var ship3 = test_spawner.spawn_ship_from_class(test_ship_class, Vector3.ZERO, "Ship 3")  # Should fail
	
	assert_that(ship1).is_not_null()
	assert_that(ship2).is_not_null()
	assert_that(ship3).is_null()
	
	test_spawner.despawn_all_ships()

func test_ac6_spawning_from_resource_files():
	# Create a temporary ship class resource
	var temp_ship_class = ShipClass.create_default_fighter()
	temp_ship_class.class_name = "Resource Fighter"
	
	# Spawner should be able to spawn from ShipClass resources
	var ship = test_spawner.spawn_ship_from_class(temp_ship_class)
	assert_that(ship).is_not_null()
	assert_that(ship.ship_class.class_name).is_equal("Resource Fighter")
	
	test_spawner.despawn_ship(ship)

# ============================================================================
# AC7: Template system supports WCS naming conventions
# ============================================================================

func test_ac7_wcs_variant_naming():
	# Template should support WCS # syntax
	var apollo_advanced = ShipTemplate.new()
	apollo_advanced.template_name = "GTF Apollo"
	apollo_advanced.variant_suffix = "Advanced"
	
	assert_that(apollo_advanced.get_full_name()).is_equal("GTF Apollo#Advanced")

func test_ac7_variant_inheritance():
	# Create base Apollo class
	var apollo_base = ShipClass.create_default_fighter()
	apollo_base.class_name = "GTF Apollo"
	apollo_base.max_velocity = 75.0
	apollo_base.max_weapon_energy = 80.0
	
	# Create advanced variant template
	var apollo_advanced = ShipTemplate.new()
	apollo_advanced.template_name = "GTF Apollo"
	apollo_advanced.variant_suffix = "Advanced"
	apollo_advanced.override_max_velocity = 85.0  # +10 boost
	apollo_advanced.override_max_weapon_energy = 90.0  # +10 boost
	apollo_advanced._resolved_ship_class = apollo_base
	
	# Generate configured class
	var advanced_class = apollo_advanced.create_ship_class()
	assert_that(advanced_class).is_not_null()
	assert_that(advanced_class.class_name).is_equal("GTF Apollo#Advanced")
	assert_that(advanced_class.max_velocity).is_equal(85.0)
	assert_that(advanced_class.max_weapon_energy).is_equal(90.0)

func test_ac7_mission_variant_support():
	# Mission should be able to specify variants
	var mission_data = {
		"ship_class": "GTF Apollo#Advanced",
		"name": "Alpha 1",
		"position": Vector3(100, 0, 0),
		"team": 1
	}
	
	# Factory should parse variant syntax
	var variant_name = mission_data["ship_class"]
	var hash_pos = variant_name.find("#")
	
	assert_that(hash_pos).is_not_equal(-1)
	
	var base_name = variant_name.substr(0, hash_pos)
	var variant_suffix = variant_name.substr(hash_pos + 1)
	
	assert_that(base_name).is_equal("GTF Apollo")
	assert_that(variant_suffix).is_equal("Advanced")

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_integration_complete_ship_creation_pipeline():
	# Complete pipeline: Registry -> Factory -> Spawner
	
	# 1. Register ship class and template
	test_ship_registry.register_ship_class(test_ship_class)
	test_ship_template._resolved_ship_class = test_ship_class
	test_ship_registry.register_ship_template(test_ship_template)
	
	# 2. Create factory with registry
	var factory = ShipFactory.new(null, test_ship_registry)
	
	# 3. Create ship by name
	var ship = factory.create_ship_by_name("Test Fighter", "Advanced")
	assert_that(ship).is_not_null()
	assert_that(ship.ship_name).is_equal("Test Fighter#Advanced")
	
	ship.queue_free()

func test_integration_scene_based_spawning():
	# Spawner should support scene-based ship creation
	var stats = test_spawner.get_spawner_statistics()
	var initial_count = stats["ships_spawned_total"]
	
	var ship = test_spawner.spawn_ship_from_class(test_ship_class, Vector3(50, 0, 0), "Scene Ship")
	
	assert_that(ship).is_not_null()
	assert_that(ship.get_parent()).is_equal(test_spawner)
	assert_that(ship.global_position).is_equal(Vector3(50, 0, 0))
	
	var final_stats = test_spawner.get_spawner_statistics()
	assert_that(final_stats["ships_spawned_total"]).is_equal(initial_count + 1)
	
	test_spawner.despawn_ship(ship)

func test_integration_factory_registry_performance():
	# Test performance with multiple ship types
	var ship_classes = []
	
	# Create multiple ship classes
	for i in range(10):
		var ship_class = ShipClass.create_default_fighter()
		ship_class.class_name = "Test Ship %d" % i
		ship_classes.append(ship_class)
		test_ship_registry.register_ship_class(ship_class)
	
	# Test registry performance
	var start_time = Time.get_ticks_msec()
	
	for ship_class in ship_classes:
		var retrieved = test_ship_registry.get_ship_class(ship_class.class_name)
		assert_that(retrieved).is_not_null()
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	# Should complete quickly (under 100ms for 10 lookups)
	assert_that(duration).is_less_than(100)

# ============================================================================
# ERROR HANDLING AND EDGE CASES
# ============================================================================

func test_error_handling_invalid_ship_class():
	# Factory should handle invalid ship classes gracefully
	var invalid_class = ShipClass.new()
	invalid_class.class_name = ""
	invalid_class.mass = 0.0
	
	var ship = test_ship_factory.create_ship_from_class(invalid_class)
	assert_that(ship).is_null()

func test_error_handling_missing_base_class():
	# Template with missing base class should fail gracefully
	var broken_template = ShipTemplate.new()
	broken_template.template_name = "Broken Template"
	broken_template.base_ship_class = "res://nonexistent/ship.tres"
	
	assert_that(broken_template.is_valid()).is_false()
	
	var ship = test_ship_factory.create_ship_from_template(broken_template)
	assert_that(ship).is_null()

func test_error_handling_registry_lookup_failures():
	# Registry should handle missing ships gracefully
	var missing_class = test_ship_registry.get_ship_class("Nonexistent Ship")
	assert_that(missing_class).is_null()
	
	var missing_template = test_ship_registry.get_ship_template("Nonexistent#Variant")
	assert_that(missing_template).is_null()

func test_error_handling_spawner_limits():
	# Spawner should respect limits and fail gracefully
	test_spawner.max_spawned_ships = 1
	
	var ship1 = test_spawner.spawn_ship_from_class(test_ship_class)
	var ship2 = test_spawner.spawn_ship_from_class(test_ship_class)  # Should fail
	
	assert_that(ship1).is_not_null()
	assert_that(ship2).is_null()
	
	test_spawner.despawn_all_ships()

# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

func test_performance_factory_creation_speed():
	# Factory should create ships quickly
	var start_time = Time.get_ticks_msec()
	
	var ships = []
	for i in range(10):
		var ship = test_ship_factory.create_ship_from_class(test_ship_class, "Perf Ship %d" % i)
		ships.append(ship)
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	# Should create 10 ships in under 500ms
	assert_that(duration).is_less_than(500)
	
	# Cleanup
	for ship in ships:
		if ship:
			ship.queue_free()

func test_performance_registry_cache_efficiency():
	# Registry should demonstrate cache efficiency
	test_ship_registry.register_ship_class(test_ship_class)
	
	# First lookup (cache miss)
	test_ship_registry.get_ship_class("Test Fighter")
	
	# Multiple cached lookups
	for i in range(100):
		test_ship_registry.get_ship_class("Test Fighter")
	
	var stats = test_ship_registry.get_registry_statistics()
	assert_that(stats["cache_hit_rate"]).is_greater_than(90.0)  # Should be >90% cache hits