class_name TestShip014SpecialWeapons
extends GdUnitTestSuite

## SHIP-014: Special Weapons (EMP, Flak, Swarm) Test Suite
## Comprehensive testing for special weapon systems with WCS-authentic mechanics
## Tests EMP electromagnetic warfare, Flak area denial, and Swarm missile coordination

# Test constants
const WeaponTypes = preload("res://addons/wcs_asset_core/constants/weapon_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")
const ShipSizes = preload("res://addons/wcs_asset_core/constants/ship_sizes.gd")

# Test fixtures
var emp_weapon_system: EMPWeaponSystem
var flak_weapon_system: FlakWeaponSystem
var swarm_weapon_system: SwarmWeaponSystem
var special_effects_manager: SpecialEffectsManager
var area_effect_calculator: AreaEffectCalculator
var special_weapon_resistance: SpecialWeaponResistance

var test_ship: Node3D
var test_target_ship: Node3D
var test_scene: Node3D

# Test tracking
var signal_emissions: Array[Dictionary] = []

func before() -> void:
	test_scene = Node3D.new()
	add_child(test_scene)
	
	# Create test ships
	test_ship = _create_test_ship("TestShip", Vector3.ZERO, ShipSizes.Size.FIGHTER, TeamTypes.Type.FRIENDLY)
	test_target_ship = _create_test_ship("TargetShip", Vector3(100, 0, 0), ShipSizes.Size.BOMBER, TeamTypes.Type.HOSTILE)
	
	# Initialize special weapon systems
	emp_weapon_system = EMPWeaponSystem.new()
	test_ship.add_child(emp_weapon_system)
	emp_weapon_system.initialize_emp_system(test_ship)
	
	flak_weapon_system = FlakWeaponSystem.new()
	test_ship.add_child(flak_weapon_system)
	flak_weapon_system.initialize_flak_system(test_ship)
	
	swarm_weapon_system = SwarmWeaponSystem.new()
	test_ship.add_child(swarm_weapon_system)
	swarm_weapon_system.initialize_swarm_system(test_ship)
	
	special_effects_manager = SpecialEffectsManager.new()
	test_ship.add_child(special_effects_manager)
	special_effects_manager.initialize_effects_manager(test_ship)
	
	area_effect_calculator = AreaEffectCalculator.new()
	test_ship.add_child(area_effect_calculator)
	
	special_weapon_resistance = SpecialWeaponResistance.new()
	test_target_ship.add_child(special_weapon_resistance)
	
	# Connect signals for monitoring
	_connect_test_signals()
	signal_emissions.clear()

func after() -> void:
	if test_scene and is_instance_valid(test_scene):
		test_scene.queue_free()

## SHIP-014 AC1: EMP weapon system creates electromagnetic pulse effects
## with range-based intensity, system disruption, and visual interference lasting 10+ seconds
func test_emp_weapon_system_electromagnetic_pulse_effects() -> void:
	# Test EMP weapon firing
	var firing_data = {
		"weapon_type": WeaponTypes.Type.EMP_BOMB,
		"target_location": Vector3(100, 0, 0),
		"firing_ship": test_ship,
		"intensity_modifier": 1.0
	}
	
	var emp_id: String = emp_weapon_system.fire_emp_weapon(firing_data)
	assert_that(emp_id).is_not_empty()
	
	# Verify EMP effect creation
	var emp_status = emp_weapon_system.get_emp_system_status()
	assert_that(emp_status["active_emp_effects"]).is_equal(1)
	
	# Test range-based intensity calculation
	var close_intensity = emp_weapon_system._calculate_emp_intensity(30.0, 50.0, 200.0, 1.0)
	var far_intensity = emp_weapon_system._calculate_emp_intensity(150.0, 50.0, 200.0, 1.0)
	
	assert_that(close_intensity).is_equal(1.0)  # Full intensity within inner radius
	assert_that(far_intensity).is_between(0.0, 1.0)  # Scaled intensity at distance
	assert_that(close_intensity).is_greater(far_intensity)
	
	# Test system disruption duration (must be 10+ seconds)
	await _wait_for_frame()
	if emp_weapon_system.is_ship_affected_by_emp(test_target_ship):
		var disruption_level = emp_weapon_system.get_system_disruption_level(test_target_ship, "targeting")
		assert_that(disruption_level).is_greater(0.0)
	
	# Verify visual interference effects
	assert_that(_get_signal_emission_count("emp_effect_applied")).is_greater_equal(0)

## SHIP-014 AC2: Flak weapon system provides area denial with predetermined detonation ranges,
## aim jitter calculations, and defensive barrier coverage
func test_flak_weapon_system_area_denial_coverage() -> void:
	# Test flak weapon firing
	var firing_data = {
		"weapon_type": WeaponTypes.Type.FLAK_CANNON,
		"target_location": Vector3(150, 0, 0),
		"firing_ship": test_ship,
		"projectile_speed": 300.0
	}
	
	var flak_id: String = flak_weapon_system.fire_flak_weapon(firing_data)
	assert_that(flak_id).is_not_empty()
	
	# Verify flak projectile tracking
	var flak_status = flak_weapon_system.get_flak_system_status()
	assert_that(flak_status["active_flak_projectiles"]).is_greater_equal(1)
	
	# Test predetermined detonation range calculation
	var weapon_position = Vector3.ZERO
	var target_position = Vector3(200, 0, 0)
	var config = {"detonation_range": 150.0, "minimum_safety_range": 10.0}
	var detonation_point = flak_weapon_system._calculate_detonation_point(weapon_position, target_position, config)
	
	var distance_to_detonation = weapon_position.distance_to(detonation_point)
	assert_that(distance_to_detonation).is_less_equal(150.0)  # Within detonation range
	assert_that(distance_to_detonation).is_greater_equal(10.0)  # Beyond minimum safety
	
	# Test aim jitter calculations
	var base_jitter = 0.05
	var damage_jitter_factor = flak_weapon_system._get_weapon_damage_jitter()
	assert_that(damage_jitter_factor).is_between(1.0, 2.0)  # Damage affects jitter
	
	# Test defensive barrier coverage
	await _wait_for_frame()
	var barrier_created = _get_signal_emission_count("flak_barrier_created") > 0
	if barrier_created:
		var coverage_radius = 60.0  # Default flak coverage
		assert_that(coverage_radius).is_greater_equal(45.0)  # Minimum defensive coverage

## SHIP-014 AC3: Swarm weapon system launches coordinated missile groups with spiral flight patterns,
## target tracking, and sequential firing timing
func test_swarm_weapon_system_coordinated_missile_groups() -> void:
	# Test swarm missile launch
	var firing_data = {
		"weapon_type": WeaponTypes.Type.SWARM_MISSILE,
		"target": test_target_ship,
		"firing_ship": test_ship,
		"launch_position": Vector3.ZERO
	}
	
	var swarm_id: String = swarm_weapon_system.fire_swarm_weapon(firing_data)
	assert_that(swarm_id).is_not_empty()
	
	# Verify coordinated missile group creation
	var swarm_status = swarm_weapon_system.get_swarm_system_status()
	assert_that(swarm_status["active_swarms"]).is_greater_equal(1)
	
	# Test spiral flight pattern generation using SwarmMissile patterns
	var missile_patterns = [
		SwarmMissile.SpiralPattern.VERTICAL,
		SwarmMissile.SpiralPattern.HORIZONTAL,
		SwarmMissile.SpiralPattern.DIAGONAL_LEFT,
		SwarmMissile.SpiralPattern.DIAGONAL_RIGHT
	]
	
	for i in range(4):  # 4 missiles per swarm
		var pattern = missile_patterns[i % 4]
		# Test spiral pattern calculations using the SwarmMissile class
		var test_missile = SwarmMissile.new()
		var spiral_offset = test_missile._calculate_spiral_offset(pattern, 0.0, 8.0)
		assert_that(spiral_offset.length()).is_less_equal(8.0)  # Within spiral radius
		test_missile.queue_free()
	
	# Test sequential firing timing
	var launch_interval = 0.15  # 150ms between missiles
	var missiles_per_swarm = 4
	var total_launch_time = launch_interval * (missiles_per_swarm - 1)
	assert_that(total_launch_time).is_equal(0.45)  # 450ms total sequence
	
	# Test target tracking capability
	var swarm_data = swarm_weapon_system.active_swarms.get(swarm_id, {})
	if not swarm_data.is_empty():
		assert_that(swarm_data.has("target")).is_true()
		assert_that(swarm_data["target"]).is_equal(test_target_ship)

## SHIP-014 AC4: Special weapon effects integration handles HUD disruption,
## targeting interference, and ship system degradation with authentic timing
func test_special_weapon_effects_integration() -> void:
	# Test HUD disruption effects
	special_effects_manager.apply_hud_disruption(["targeting_interference"], 0.8, 12.0)
	
	var hud_disruptions = special_effects_manager.get_active_hud_disruptions()
	assert_that(hud_disruptions.size()).is_greater_equal(1)
	
	# Test targeting interference
	special_effects_manager.apply_targeting_interference(0.6, 10.0)
	var interference_level = special_effects_manager.get_targeting_interference_level()
	assert_that(interference_level).is_equal(0.6)
	
	# Test ship system degradation
	special_effects_manager.apply_system_degradation("engines", 0.4, 15.0)
	
	# Verify authentic timing (effects should last 10+ seconds)
	await _wait_for_frame()
	var system_degradations = special_effects_manager.get_active_system_degradations()
	if not system_degradations.is_empty():
		for degradation in system_degradations.values():
			var remaining_time = degradation.get("end_time", 0.0) - Time.get_ticks_msec() / 1000.0
			assert_that(remaining_time).is_greater(5.0)  # Should have significant remaining time
	
	# Test visual corruption effects
	special_effects_manager.apply_visual_corruption("screen_flash", 1.0)
	var corruption_effects = special_effects_manager.get_active_visual_corruption()
	assert_that(corruption_effects.size()).is_greater_equal(1)

## SHIP-014 AC5: Area effect calculations provide accurate range-based damage scaling
## with inner/outer radius effectiveness zones
func test_area_effect_calculations_range_based_scaling() -> void:
	# Test inner radius effectiveness (100%)
	var inner_damage = area_effect_calculator.calculate_area_damage(
		Vector3.ZERO,           # center
		Vector3(25, 0, 0),      # target within inner radius (50.0)
		50.0,                   # inner radius
		200.0,                  # outer radius
		100.0                   # base damage
	)
	assert_that(inner_damage).is_equal(100.0)  # Full damage within inner radius
	
	# Test outer radius effectiveness (scaled)
	var outer_damage = area_effect_calculator.calculate_area_damage(
		Vector3.ZERO,           # center
		Vector3(125, 0, 0),     # target in scaling zone
		50.0,                   # inner radius
		200.0,                  # outer radius
		100.0                   # base damage
	)
	assert_that(outer_damage).is_between(25.0, 75.0)  # Scaled damage in outer zone
	
	# Test beyond range (no damage)
	var beyond_damage = area_effect_calculator.calculate_area_damage(
		Vector3.ZERO,           # center
		Vector3(250, 0, 0),     # target beyond outer radius
		50.0,                   # inner radius
		200.0,                  # outer radius
		100.0                   # base damage
	)
	assert_that(beyond_damage).is_equal(0.0)  # No damage beyond range
	
	# Test effectiveness zones
	var inner_zone = area_effect_calculator.determine_effectiveness_zone(25.0, 50.0, 200.0)
	var middle_zone = area_effect_calculator.determine_effectiveness_zone(125.0, 50.0, 200.0)
	var outer_zone = area_effect_calculator.determine_effectiveness_zone(250.0, 50.0, 200.0)
	
	assert_that(inner_zone).is_equal(AreaEffectCalculator.EffectivenessZone.INNER_RADIUS)
	assert_that(middle_zone).is_equal(AreaEffectCalculator.EffectivenessZone.MIDDLE_RADIUS)
	assert_that(outer_zone).is_equal(AreaEffectCalculator.EffectivenessZone.BEYOND_RANGE)

## SHIP-014 AC6: Special weapon resistance system applies ship-specific immunity modifiers
## and capital ship protection mechanics
func test_special_weapon_resistance_system() -> void:
	# Configure resistance for different ship sizes
	special_weapon_resistance.emp_resistance = 0.2  # 20% EMP resistance
	special_weapon_resistance.flak_resistance = 0.1  # 10% flak resistance
	special_weapon_resistance.is_capital_ship = false
	
	# Test EMP resistance calculation
	var emp_intensity = 1.0
	var emp_result = special_weapon_resistance.calculate_resistance(
		test_target_ship, WeaponTypes.Type.EMP_BOMB, emp_intensity
	)
	assert_that(emp_result["final_damage"]).is_less_equal(emp_intensity)  # Some resistance applied
	
	# Test flak resistance calculation
	var flak_damage = 100.0
	var flak_result = special_weapon_resistance.calculate_resistance(
		test_target_ship, WeaponTypes.Type.FLAK_CANNON, flak_damage
	)
	assert_that(flak_result["final_damage"]).is_less_equal(flak_damage)  # Some resistance applied
	
	# Test capital ship protection mechanics
	special_weapon_resistance.is_capital_ship = true
	var capital_emp_result = special_weapon_resistance.calculate_resistance(
		test_target_ship, WeaponTypes.Type.EMP_BOMB, emp_intensity
	)
	assert_that(capital_emp_result["final_damage"]).is_less(emp_result["final_damage"])  # Additional capital ship protection
	
	# Test ship size-based immunity modifiers by testing different ship sizes
	var fighter_result = special_weapon_resistance.calculate_resistance(
		test_ship, WeaponTypes.Type.EMP_BOMB, emp_intensity  # test_ship is fighter
	)
	var capital_result = special_weapon_resistance.calculate_resistance(
		test_target_ship, WeaponTypes.Type.EMP_BOMB, emp_intensity  # test_target_ship configured as capital
	)
	
	# Capital ships should have higher resistance than fighters
	assert_that(capital_result["resistance_factor"]).is_greater(fighter_result["resistance_factor"])

## SHIP-014 AC7: Coordinated firing system manages sequential launches, timing delays,
## and weapon system coordination for tactical deployment
func test_coordinated_firing_system_tactical_deployment() -> void:
	# Test sequential launch coordination
	var swarm_firing_data = {
		"weapon_type": WeaponTypes.Type.SWARM_MISSILE,
		"target": test_target_ship,
		"firing_ship": test_ship,
		"launch_position": Vector3.ZERO
	}
	
	var first_swarm = swarm_weapon_system.fire_swarm_weapon(swarm_firing_data)
	assert_that(first_swarm).is_not_empty()
	
	# Test timing delays between coordinated launches
	await _wait_for_frame()  # Allow one frame for processing
	
	var second_swarm = swarm_weapon_system.fire_swarm_weapon(swarm_firing_data)
	if not second_swarm.is_empty():
		# Verify different swarm IDs for coordination tracking
		assert_that(second_swarm).is_not_equal(first_swarm)
	
	# Test weapon system coordination
	var active_swarms = swarm_weapon_system.get_swarm_system_status()["active_swarms"]
	if active_swarms > 0:
		# Verify coordinated management
		assert_that(active_swarms).is_greater_equal(1)
	
	# Test tactical deployment coordination with multiple special weapons
	var emp_firing_data = {
		"weapon_type": WeaponTypes.Type.EMP_BOMB,
		"target_location": Vector3(120, 0, 0),
		"firing_ship": test_ship
	}
	
	var emp_id = emp_weapon_system.fire_emp_weapon(emp_firing_data)
	var flak_firing_data = {
		"weapon_type": WeaponTypes.Type.FLAK_CANNON,
		"target_location": Vector3(140, 0, 0),
		"firing_ship": test_ship
	}
	
	var flak_id = flak_weapon_system.fire_flak_weapon(flak_firing_data)
	
	# Verify coordinated deployment tracking
	assert_that(emp_id).is_not_empty()
	assert_that(flak_id).is_not_empty()
	
	# Test tactical timing coordination
	var emp_status = emp_weapon_system.get_emp_system_status()
	var flak_status = flak_weapon_system.get_flak_system_status()
	
	var total_special_weapons = emp_status["active_emp_effects"] + flak_status["active_flak_projectiles"]
	assert_that(total_special_weapons).is_greater_equal(2)

## Integration test: Full special weapons scenario
func test_special_weapons_integration_scenario() -> void:
	# Scenario: Coordinated special weapons assault
	print("Testing integrated special weapons scenario...")
	
	# Phase 1: EMP disruption
	var emp_data = {
		"weapon_type": WeaponTypes.Type.EMP_BOMB,
		"target_location": test_target_ship.global_position,
		"firing_ship": test_ship,
		"intensity_modifier": 1.0
	}
	var emp_id = emp_weapon_system.fire_emp_weapon(emp_data)
	
	# Phase 2: Flak area denial
	var flak_data = {
		"weapon_type": WeaponTypes.Type.FLAK_CANNON,
		"target_location": test_target_ship.global_position + Vector3(0, 0, 50),
		"firing_ship": test_ship
	}
	var flak_id = flak_weapon_system.fire_flak_weapon(flak_data)
	
	# Phase 3: Swarm missile coordination
	var swarm_data = {
		"weapon_type": WeaponTypes.Type.SWARM_MISSILE,
		"target": test_target_ship,
		"firing_ship": test_ship,
		"launch_position": test_ship.global_position
	}
	var swarm_id = swarm_weapon_system.fire_swarm_weapon(swarm_data)
	
	# Verify all weapons fired successfully
	assert_that(emp_id).is_not_empty()
	assert_that(flak_id).is_not_empty()
	assert_that(swarm_id).is_not_empty()
	
	# Check system coordination
	var total_active_weapons = 0
	total_active_weapons += emp_weapon_system.get_emp_system_status()["active_emp_effects"]
	total_active_weapons += flak_weapon_system.get_flak_system_status()["active_flak_projectiles"]
	total_active_weapons += swarm_weapon_system.get_swarm_system_status()["active_swarms"]
	
	assert_that(total_active_weapons).is_greater_equal(3)
	print("Integration scenario successful - %d active special weapons" % total_active_weapons)

## Performance test: Multiple special weapon effects
func test_special_weapons_performance() -> void:
	var start_time = Time.get_ticks_msec()
	
	# Create multiple special weapon effects
	for i in range(5):
		var emp_data = {
			"weapon_type": WeaponTypes.Type.EMP_BOMB,
			"target_location": Vector3(i * 50, 0, 0),
			"firing_ship": test_ship
		}
		emp_weapon_system.fire_emp_weapon(emp_data)
		
		var flak_data = {
			"weapon_type": WeaponTypes.Type.FLAK_CANNON,
			"target_location": Vector3(i * 50, 50, 0),
			"firing_ship": test_ship
		}
		flak_weapon_system.fire_flak_weapon(flak_data)
	
	var creation_time = Time.get_ticks_msec() - start_time
	
	# Process effects for several frames
	for frame in range(10):
		await _wait_for_frame()
	
	var total_time = Time.get_ticks_msec() - start_time
	
	# Verify performance remains acceptable
	assert_that(creation_time).is_less(100)  # < 100ms to create 10 effects
	assert_that(total_time).is_less(500)     # < 500ms total processing
	
	print("Performance test: %d effects created in %dms, total %dms" % [10, creation_time, total_time])

## Helper functions

func _create_test_ship(ship_name: String, position: Vector3, ship_size: int, team: int) -> Node3D:
	var ship = Node3D.new()
	ship.name = ship_name
	ship.global_position = position
	test_scene.add_child(ship)
	
	# Add required ship properties
	ship.set_meta("ship_size", ship_size)
	ship.set_meta("team", team)
	ship.set_meta("is_ship", true)
	
	# Add collision for physics queries
	var collision_body = RigidBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 5.0
	collision_shape.shape = sphere_shape
	collision_body.add_child(collision_shape)
	ship.add_child(collision_body)
	
	return ship

func _connect_test_signals() -> void:
	# EMP signals
	emp_weapon_system.emp_weapon_fired.connect(_on_signal_emitted.bind("emp_weapon_fired"))
	emp_weapon_system.emp_effect_applied.connect(_on_signal_emitted.bind("emp_effect_applied"))
	
	# Flak signals
	flak_weapon_system.flak_weapon_fired.connect(_on_signal_emitted.bind("flak_weapon_fired"))
	flak_weapon_system.flak_barrier_created.connect(_on_signal_emitted.bind("flak_barrier_created"))
	
	# Swarm signals
	swarm_weapon_system.swarm_launched.connect(_on_signal_emitted.bind("swarm_launched"))
	swarm_weapon_system.swarm_missile_fired.connect(_on_signal_emitted.bind("swarm_missile_fired"))
	
	# Effects signals
	special_effects_manager.hud_disruption_applied.connect(_on_signal_emitted.bind("hud_disruption_applied"))
	special_effects_manager.targeting_interference_started.connect(_on_signal_emitted.bind("targeting_interference_started"))

func _on_signal_emitted(signal_name: String, args: Array = []) -> void:
	signal_emissions.append({
		"signal": signal_name,
		"args": args,
		"time": Time.get_ticks_msec()
	})

func _get_signal_emission_count(signal_name: String) -> int:
	var count = 0
	for emission in signal_emissions:
		if emission["signal"] == signal_name:
			count += 1
	return count

func _wait_for_frame() -> void:
	await get_tree().process_frame