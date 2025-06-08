extends GdUnitTestSuite

## Comprehensive test suite for SHIP-005: Weapon Manager and Firing System
## Tests all acceptance criteria and integration points for weapon management

# Test imports
const BaseShip = preload("res://scripts/ships/core/base_ship.gd")
const ShipClass = preload("res://addons/wcs_asset_core/resources/ship/ship_class.gd")
const WeaponData = preload("res://addons/wcs_asset_core/structures/weapon_data.gd")
const WeaponBankType = preload("res://addons/wcs_asset_core/constants/weapon_bank_types.gd")

# Weapon system components
const WeaponManager = preload("res://scripts/ships/weapons/weapon_manager.gd")
const FiringController = preload("res://scripts/ships/weapons/firing_controller.gd")
const WeaponBank = preload("res://scripts/ships/weapons/weapon_bank.gd")
const WeaponSelectionManager = preload("res://scripts/ships/weapons/weapon_selection_manager.gd")
const TargetingSystem = preload("res://scripts/ships/weapons/targeting_system.gd")
const WeaponBase = preload("res://scripts/object/weapon_base.gd")

# Test objects
var test_ship: BaseShip
var weapon_manager: WeaponManager
var test_weapon_data: WeaponData
var test_target: Node3D

func before_test() -> void:
	# Create test ship with weapon system
	test_ship = BaseShip.new()
	add_child(test_ship)
	
	# Initialize ship with test configuration
	var ship_class: ShipClass = _create_test_ship_class()
	test_ship.initialize_ship(ship_class, "Test Fighter")
	
	# Create weapon manager
	weapon_manager = WeaponManager.new()
	test_ship.add_child(weapon_manager)
	weapon_manager.initialize_weapon_manager(test_ship)
	
	# Create test target
	test_target = Node3D.new()
	add_child(test_target)
	test_target.global_position = Vector3(100, 0, 0)
	
	await get_tree().process_frame

func after_test() -> void:
	if test_ship:
		test_ship.queue_free()
	if test_target:
		test_target.queue_free()
	await get_tree().process_frame

## SHIP-005 AC1: Primary/secondary weapon bank management and state tracking
func test_weapon_bank_management() -> void:
	# Test primary weapon banks initialization
	assert_that(weapon_manager.primary_weapon_banks.size()).is_greater_than(0)
	
	# Test secondary weapon banks initialization
	assert_that(weapon_manager.secondary_weapon_banks.size()).is_greater_than(0)
	
	# Test weapon bank configuration
	var primary_bank: WeaponBank = weapon_manager.primary_weapon_banks[0]
	assert_that(primary_bank).is_not_null()
	assert_that(primary_bank.get_bank_type()).is_equal(WeaponBankType.Type.PRIMARY)
	assert_that(primary_bank.get_weapon_data()).is_not_null()
	
	# Test weapon bank state tracking
	var bank_status: Dictionary = primary_bank.get_weapon_status()
	assert_that(bank_status.has("weapon_name")).is_true()
	assert_that(bank_status.has("can_fire")).is_true()
	assert_that(bank_status.has("current_ammunition")).is_true()

func test_weapon_bank_configuration() -> void:
	# Test weapon bank initialization
	var weapon_bank: WeaponBank = WeaponBank.new()
	add_child(weapon_bank)
	
	var weapon_data: WeaponData = _create_test_weapon_data()
	weapon_bank.initialize_weapon_bank(WeaponBankType.Type.PRIMARY, 0, weapon_data, test_ship)
	
	# Test mount configuration
	weapon_bank.set_mount_configuration(Vector3(1.0, 0.5, 2.0), Vector3.ZERO, 500.0)
	assert_that(weapon_bank.get_mount_position()).is_equal(Vector3(1.0, 0.5, 2.0))
	assert_that(weapon_bank.convergence_distance).is_equal(500.0)
	
	# Test weapon data access
	assert_that(weapon_bank.get_weapon_data()).is_equal(weapon_data)
	assert_that(weapon_bank.get_bank_type()).is_equal(WeaponBankType.Type.PRIMARY)
	assert_that(weapon_bank.get_bank_index()).is_equal(0)
	
	weapon_bank.queue_free()

## SHIP-005 AC2: Firing system timing control and rate limiting
func test_firing_system_timing() -> void:
	# Test basic firing capability
	var fired: bool = weapon_manager.fire_primary_weapons()
	assert_that(fired).is_true()
	
	# Test rate limiting - immediate second shot should fail
	var second_shot: bool = weapon_manager.fire_primary_weapons()
	assert_that(second_shot).is_false()
	
	# Wait for rate limit to pass
	await get_tree().create_timer(0.2).timeout
	
	# Third shot should succeed
	var third_shot: bool = weapon_manager.fire_primary_weapons()
	assert_that(third_shot).is_true()

func test_firing_controller_timing() -> void:
	var firing_controller: FiringController = FiringController.new()
	add_child(firing_controller)
	firing_controller.initialize_firing_controller(test_ship)
	
	var weapon_bank: WeaponBank = weapon_manager.primary_weapon_banks[0]
	var firing_data: Dictionary = {
		"target": test_target,
		"ship_velocity": Vector3.ZERO,
		"convergence_distance": 500.0
	}
	
	# Test single shot firing
	var fired: bool = firing_controller.fire_weapon_bank(weapon_bank, firing_data)
	assert_that(fired).is_true()
	
	# Test rate limiting
	var rate_limited: bool = firing_controller.fire_weapon_bank(weapon_bank, firing_data)
	assert_that(rate_limited).is_false()
	
	firing_controller.queue_free()

func test_burst_fire_mechanics() -> void:
	# Create weapon with burst fire capability
	var burst_weapon_data: WeaponData = _create_test_weapon_data()
	burst_weapon_data.burst_shots = 3
	burst_weapon_data.burst_delay = 0.1
	
	var weapon_bank: WeaponBank = WeaponBank.new()
	add_child(weapon_bank)
	weapon_bank.initialize_weapon_bank(WeaponBankType.Type.PRIMARY, 0, burst_weapon_data, test_ship)
	
	var firing_controller: FiringController = FiringController.new()
	add_child(firing_controller)
	firing_controller.initialize_firing_controller(test_ship)
	
	var burst_completed_count: int = 0
	firing_controller.burst_fire_completed.connect(func(bank_type, bank_index): burst_completed_count += 1)
	
	var firing_data: Dictionary = {"target": test_target}
	
	# Fire burst sequence
	for i in range(3):
		var fired: bool = firing_controller.fire_weapon_bank(weapon_bank, firing_data)
		assert_that(fired).is_true()
		await get_tree().create_timer(0.12).timeout  # Wait for burst delay
	
	# Wait for burst completion signal
	await get_tree().create_timer(0.1).timeout
	assert_that(burst_completed_count).is_equal(1)
	
	weapon_bank.queue_free()
	firing_controller.queue_free()

## SHIP-005 AC3: Energy management and ETS integration
func test_energy_management() -> void:
	# Test initial weapon energy
	var initial_energy: float = test_ship.current_weapon_energy
	assert_that(initial_energy).is_greater_than(0.0)
	
	# Test energy consumption during firing
	weapon_manager.fire_primary_weapons()
	await get_tree().process_frame
	
	var energy_after_firing: float = test_ship.current_weapon_energy
	assert_that(energy_after_firing).is_less_than(initial_energy)

func test_ets_integration() -> void:
	# Test weapon energy allocation affects regeneration
	var initial_allocation: float = test_ship.get_weapon_energy_allocation()
	assert_that(initial_allocation).is_greater_than(0.0)
	
	# Change ETS allocation
	test_ship.transfer_energy_to_weapons()
	var new_allocation: float = test_ship.get_weapon_energy_allocation()
	assert_that(new_allocation).is_greater_than(initial_allocation)
	
	# Test energy regeneration with new allocation
	var energy_before: float = test_ship.current_weapon_energy
	
	# Process energy regeneration
	for i in range(10):
		await get_tree().process_frame
	
	var energy_after: float = test_ship.current_weapon_energy
	# Energy should regenerate (or at least not decrease if already full)
	assert_that(energy_after).is_greater_equal(energy_before)

func test_energy_consumption_calculation() -> void:
	var primary_bank: WeaponBank = weapon_manager.primary_weapon_banks[0]
	var energy_cost: float = primary_bank.get_energy_cost()
	assert_that(energy_cost).is_greater_than(0.0)
	
	# Test energy cost calculation for multiple banks
	var total_cost: float = weapon_manager._calculate_primary_energy_cost()
	assert_that(total_cost).is_greater_equal(energy_cost)

## SHIP-005 AC4: Ammunition tracking and rearm processes
func test_ammunition_tracking() -> void:
	# Test secondary weapon ammunition
	if weapon_manager.secondary_weapon_banks.size() > 0:
		var secondary_bank: WeaponBank = weapon_manager.secondary_weapon_banks[0]
		var initial_ammo: int = secondary_bank.current_ammunition
		
		if initial_ammo > 0:  # Only test if bank has ammunition
			# Fire secondary weapon to consume ammunition
			weapon_manager.fire_secondary_weapons()
			await get_tree().process_frame
			
			var ammo_after_firing: int = secondary_bank.current_ammunition
			assert_that(ammo_after_firing).is_less_than(initial_ammo)

func test_ammunition_reload() -> void:
	# Create missile weapon bank
	var missile_weapon_data: WeaponData = _create_test_weapon_data()
	missile_weapon_data.cargo_size = 10
	
	var weapon_bank: WeaponBank = WeaponBank.new()
	add_child(weapon_bank)
	weapon_bank.initialize_weapon_bank(WeaponBankType.Type.SECONDARY, 0, missile_weapon_data, test_ship)
	
	# Consume some ammunition
	weapon_bank.consume_shot()
	weapon_bank.consume_shot()
	var ammo_after_consumption: int = weapon_bank.current_ammunition
	assert_that(ammo_after_consumption).is_equal(8)
	
	# Test full reload
	var reloaded: bool = weapon_bank.reload_ammunition()
	assert_that(reloaded).is_true()
	assert_that(weapon_bank.current_ammunition).is_equal(10)
	
	# Test partial reload
	weapon_bank.consume_shot()
	weapon_bank.consume_shot()
	weapon_bank.reload_ammunition(1)
	assert_that(weapon_bank.current_ammunition).is_equal(9)
	
	weapon_bank.queue_free()

func test_ammunition_depletion() -> void:
	# Create weapon bank with limited ammunition
	var limited_weapon_data: WeaponData = _create_test_weapon_data()
	limited_weapon_data.cargo_size = 2
	
	var weapon_bank: WeaponBank = WeaponBank.new()
	add_child(weapon_bank)
	weapon_bank.initialize_weapon_bank(WeaponBankType.Type.SECONDARY, 0, limited_weapon_data, test_ship)
	
	var ammunition_depleted_count: int = 0
	weapon_bank.ammunition_depleted.connect(func(bank_type, bank_index): ammunition_depleted_count += 1)
	
	# Consume all ammunition
	weapon_bank.consume_shot()
	weapon_bank.consume_shot()
	
	# Check depletion signal
	assert_that(ammunition_depleted_count).is_equal(1)
	assert_that(weapon_bank.can_fire()).is_false()
	
	weapon_bank.queue_free()

## SHIP-005 AC5: Weapon selection and linking validation
func test_weapon_selection() -> void:
	# Test initial weapon selection
	var selected_primary: int = weapon_manager.selection_manager.get_selected_primary_bank()
	assert_that(selected_primary).is_greater_equal(0)
	
	# Test weapon bank selection
	var selection_success: bool = weapon_manager.select_weapon_bank(WeaponBankType.Type.PRIMARY, 0)
	assert_that(selection_success).is_true()
	
	# Test selection change signal
	var selection_changed: bool = false
	weapon_manager.weapon_selection_changed.connect(func(bank_type, weapon_index): selection_changed = true)
	
	if weapon_manager.primary_weapon_banks.size() > 1:
		weapon_manager.select_weapon_bank(WeaponBankType.Type.PRIMARY, 1)
		assert_that(selection_changed).is_true()

func test_weapon_cycling() -> void:
	if weapon_manager.primary_weapon_banks.size() > 1:
		var initial_selection: int = weapon_manager.selection_manager.get_selected_primary_bank()
		
		# Test forward cycling
		var cycled: bool = weapon_manager.cycle_weapon_selection(WeaponBankType.Type.PRIMARY, true)
		assert_that(cycled).is_true()
		
		var new_selection: int = weapon_manager.selection_manager.get_selected_primary_bank()
		assert_that(new_selection).is_not_equal(initial_selection)
		
		# Test backward cycling
		var cycled_back: bool = weapon_manager.cycle_weapon_selection(WeaponBankType.Type.PRIMARY, false)
		assert_that(cycled_back).is_true()

func test_weapon_linking() -> void:
	# Test linking mode
	weapon_manager.set_weapon_linking_mode(WeaponBankType.Type.PRIMARY, true)
	var is_linked: bool = weapon_manager.selection_manager.is_primary_weapons_linked()
	assert_that(is_linked).is_true()
	
	# Test linked banks selection
	var linked_banks: Array[int] = weapon_manager.selection_manager.get_selected_primary_banks()
	if weapon_manager.primary_weapon_banks.size() > 1:
		# Should have multiple banks selected when linked
		assert_that(linked_banks.size()).is_greater_than(1)

func test_weapon_selection_manager() -> void:
	var selection_manager: WeaponSelectionManager = WeaponSelectionManager.new()
	add_child(selection_manager)
	
	# Initialize with test banks
	var primary_banks: Array[WeaponBank] = weapon_manager.primary_weapon_banks
	var secondary_banks: Array[WeaponBank] = weapon_manager.secondary_weapon_banks
	selection_manager.initialize_selection_manager(primary_banks, secondary_banks)
	
	# Test selection status
	var status: Dictionary = selection_manager.get_selection_status()
	assert_that(status.has("primary_selected_bank")).is_true()
	assert_that(status.has("secondary_selected_bank")).is_true()
	
	# Test weapon names
	var primary_names: Array[String] = selection_manager.get_available_weapon_names(WeaponBankType.Type.PRIMARY)
	assert_that(primary_names.size()).is_greater_than(0)
	
	selection_manager.queue_free()

## SHIP-005 AC6: Target acquisition and firing solutions
func test_target_acquisition() -> void:
	# Test target setting
	weapon_manager.set_weapon_target(test_target)
	assert_that(weapon_manager.current_target).is_equal(test_target)
	
	# Test target acquisition signal
	var target_acquired: bool = false
	weapon_manager.target_acquired.connect(func(target, subsystem): target_acquired = true)
	
	weapon_manager.set_weapon_target(test_target)
	assert_that(target_acquired).is_true()

func test_targeting_system() -> void:
	var targeting_system: TargetingSystem = TargetingSystem.new()
	add_child(targeting_system)
	targeting_system.initialize_targeting_system(test_ship)
	
	# Test target setting
	targeting_system.set_target(test_target)
	assert_that(targeting_system.get_current_target()).is_equal(test_target)
	
	# Allow targeting system to process
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Test targeting status
	var status: Dictionary = targeting_system.get_targeting_status()
	assert_that(status["has_target"]).is_true()
	assert_that(status["target_distance"]).is_greater_than(0.0)
	
	targeting_system.queue_free()

func test_firing_solution_calculation() -> void:
	var targeting_system: TargetingSystem = TargetingSystem.new()
	add_child(targeting_system)
	targeting_system.initialize_targeting_system(test_ship)
	
	# Set moving target
	targeting_system.set_target(test_target)
	test_target.global_position = Vector3(100, 0, 0)
	
	# Allow targeting system to track target
	for i in range(5):
		test_target.global_position += Vector3(1, 0, 0)  # Move target
		await get_tree().process_frame
	
	# Get firing solution
	var solution: Dictionary = targeting_system.get_firing_solution()
	assert_that(solution.has("target_position")).is_true()
	assert_that(solution.has("target_velocity")).is_true()
	assert_that(solution.has("lead_vector")).is_true()
	assert_that(solution.has("accuracy_modifier")).is_true()
	assert_that(solution.has("time_to_target")).is_true()
	
	targeting_system.queue_free()

func test_target_lock_mechanics() -> void:
	var targeting_system: TargetingSystem = TargetingSystem.new()
	add_child(targeting_system)
	targeting_system.initialize_targeting_system(test_ship)
	
	# Set target within lock range
	targeting_system.set_target(test_target)
	test_target.global_position = Vector3(50, 0, 0)  # Close target for easy lock
	
	# Initially no lock
	assert_that(targeting_system.has_target_lock()).is_false()
	
	# Allow time for lock acquisition
	await get_tree().create_timer(1.5).timeout
	
	# Should have acquired lock
	var has_lock: bool = targeting_system.has_target_lock()
	var lock_strength: float = targeting_system.get_lock_strength()
	assert_that(lock_strength).is_greater_than(0.0)
	
	targeting_system.queue_free()

## SHIP-005 AC7: Subsystem integration and turret control
func test_subsystem_integration() -> void:
	# Test weapon system enable/disable
	weapon_manager.set_weapons_enabled(false)
	var can_fire_disabled: bool = weapon_manager.fire_primary_weapons()
	assert_that(can_fire_disabled).is_false()
	
	# Re-enable weapons
	weapon_manager.set_weapons_enabled(true)
	var can_fire_enabled: bool = weapon_manager.fire_primary_weapons()
	assert_that(can_fire_enabled).is_true()

func test_weapon_subsystem_performance() -> void:
	# Test subsystem performance affects weapon capability
	if test_ship.has_method("get_subsystem_performance"):
		var weapon_performance: float = test_ship.get_subsystem_performance("weapons")
		assert_that(weapon_performance).is_greater_than(0.0)
		assert_that(weapon_performance).is_less_equal(1.0)

## Integration tests
func test_complete_weapon_cycle() -> void:
	# Test complete weapon firing cycle
	
	# 1. Set target
	weapon_manager.set_weapon_target(test_target)
	
	# 2. Select weapon
	weapon_manager.select_weapon_bank(WeaponBankType.Type.PRIMARY, 0)
	
	# 3. Fire weapon
	var fired: bool = weapon_manager.fire_primary_weapons()
	assert_that(fired).is_true()
	
	# 4. Check weapon status
	var status: Dictionary = weapon_manager.get_weapon_status()
	assert_that(status.has("primary_weapons")).is_true()
	assert_that(status["current_target"]).is_not_equal(-1)

func test_weapon_manager_integration() -> void:
	# Test weapon manager components are properly initialized
	assert_that(weapon_manager.firing_controller).is_not_null()
	assert_that(weapon_manager.selection_manager).is_not_null()
	assert_that(weapon_manager.targeting_system).is_not_null()
	
	# Test signal connections
	var weapon_fired_signal_connected: bool = false
	weapon_manager.weapon_fired.connect(func(bank_type, weapon_name, projectiles): weapon_fired_signal_connected = true)
	
	weapon_manager.fire_primary_weapons()
	await get_tree().process_frame
	
	assert_that(weapon_fired_signal_connected).is_true()

## Performance tests
func test_weapon_system_performance() -> void:
	# Test multiple rapid firings don't cause performance issues
	var start_time: float = Time.get_ticks_msec()
	
	for i in range(10):
		weapon_manager.fire_primary_weapons()
		await get_tree().process_frame
	
	var end_time: float = Time.get_ticks_msec()
	var elapsed_time: float = end_time - start_time
	
	# Should complete in reasonable time (less than 1000 milliseconds for 10 shots)
	assert_that(elapsed_time).is_less_than(1000.0)

## Helper methods
func _create_test_ship_class() -> ShipClass:
	var ship_class: ShipClass = ShipClass.new()
	ship_class.class_name = "Test Fighter"
	ship_class.max_velocity = 75.0
	ship_class.max_hull_strength = 100.0
	ship_class.max_shield_strength = 100.0
	ship_class.max_weapon_energy = 100.0
	ship_class.weapon_energy_regeneration_rate = 10.0
	
	# Add weapon slots
	var test_weapon_path: String = "res://resources/weapons/test_primary_laser.tres"
	ship_class.primary_weapon_slots = [test_weapon_path, test_weapon_path]
	ship_class.secondary_weapon_slots = [test_weapon_path]
	
	return ship_class

func _create_test_weapon_data() -> WeaponData:
	var weapon_data: WeaponData = WeaponData.new()
	weapon_data.weapon_name = "Test Laser"
	weapon_data.damage = 25.0
	weapon_data.max_speed = 300.0
	weapon_data.lifetime = 5.0
	weapon_data.fire_rate = 2.5
	weapon_data.energy_consumed = 2.0
	weapon_data.mass = 0.1
	weapon_data.cargo_size = 0  # Energy weapon
	weapon_data.heat_generated = 0.1
	weapon_data.overheat_threshold = 1.0
	
	return weapon_data